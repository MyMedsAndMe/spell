defmodule Spell.Peer do
  @moduledoc """
  The `Spell.Peer` module implements the general WAMP peer behaviour.

  From the docuemntation:

  > A WAMP Session connects two Peers, a Client and a Router. Each WAMP
  > Peer can implement one or more roles.

  """
  use GenServer

  alias Spell.Message
  alias Spell.Role

  require Logger

  @default_serializer_module Spell.Serializer.JSON
  @default_transport_module  Spell.Transport.WebSocket

  defstruct [:transport,
             :serializer,
             :owner,
             :role]

  # Type Specs

  @type start_option ::
     {:serializer, module}
   | {:transport, {module, Keyword.t}}

  @type t :: %__MODULE__{
    transport:  map,
    serializer: module,
    owner:      pid,
    role:      map}

  # Public Functions

  @doc """
  Start a new peer.

  ## Options

   * `:transport :: {module, Keyword.t}`
   * `:serializer :: module`
   * `:roles :: [{module, Keyword.t}]`
  """
  @spec start_link([start_option]) :: {:ok, t} | {:error, any}
  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, {self(), options})
  end

  @doc """
  Send a message via the peer.
  """
  @spec send_message(pid, Message.t) :: :ok
  def send_message(peer, %Message{} = message) do
    GenServer.cast(peer, {:send_message, message})
  end

  @doc """
  Send a message to the peer's owner.

  TODO: This is inefficient -- roles should send using the peer state.
  """
  @spec send_to_owner(pid, any) :: :ok
  def send_to_owner(peer, term) do
    GenServer.cast(peer, {:send_to_owner, term})
  end

  @doc """
  Cast a message to a specific role
  """
  @spec cast_role(pid, module, any) :: :ok
  def cast_role(peer, role, message) do
    GenServer.cast(peer, {:cast_role, {role, message}})
  end

  # GenServer Callbacks

  def init({owner, options}) do
    # TODO: collection options + handle errors cleanly. extract?
    case normalize_options(options) do
      {:ok, %{transport: {transport_module, transport_options},
              serializer: {serializer_module, _serializer_options},
              role: %{options: role_options, features: role_features}}} ->
        send(self(), {:role_hook, :init})
        {:ok, %__MODULE__{transport: %{module: transport_module,
                                       options: transport_options,
                                       pid: nil},
                          serializer: %{module: serializer_module},
                          owner: owner,
                          role: %{options: role_options,
                                  state: nil,
                                  features: role_features}}}
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_cast({:send_message, %Message{} = message}, state) do
    case state.serializer.module.encode(message) do
      {:ok, raw_message} ->
        :ok = state.transport.module.send_message(state.transport.pid,
                                                  raw_message)
        {:noreply, state}
      # {:error, reason} -> {:noreply, state}
    end
  end

  def handle_cast({:send_to_owner, term}, state) do
    :ok = send_from(state.owner, term)
    {:noreply, state}
  end

  def handle_cast({:cast_role, {role, message}},  state) do
    case Role.cast(state.role.state, role, message) do
      {:ok, role_state} ->
        {:noreply, put_in(state.role[:state], role_state)}
      {:error, reason} ->
        {:stop, {:cast_role, reason}, state}
    end
  end

  def handle_info({:role_hook, :init},
                  %{role: %{state: nil}} = state) do
    case Role.map_init(state.role.options, state) do
      {:ok, role_state} ->
        send(self(), {:transport, :reconnect})
        {:noreply, put_in(state.role[:state], role_state)}
      {:error, reason} ->
        {:stop, {{:role_hook, :init}, reason}, state}
    end
  end

  # Cheers to Fred Hebert's "Stuff Goes Bad"
  # TODO: Retries
  def handle_info({:transport, :reconnect},
                  %{transport: %{pid: nil} = transport,
                    serializer: serializer} = state) do
    # WARNING: role state's aren't reset. TBD if this is a good thing
    case transport.module.connect(serializer.module.name(),
                                  transport.options) do
      {:ok, pid} ->
        Logger.debug(fn -> "Connected using #{inspect(state)}" end)
        send(self(), {:role_hook, :on_open})
        {:noreply, put_in(state.transport[:pid], pid)}
      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  def handle_info({:role_hook, :on_open}, state) do
    case Role.map_on_open(state.role.state, self()) do
      {:ok, role_state} ->
        {:noreply, put_in(state.role[:state], role_state)}
      {:error, reason} ->
        {:stop, {{:role_hook, :on_open}, reason}, state}
    end
  end

  def handle_info({module, pid, {:message, raw_message}},
                  %{transport: %{module: module, pid: pid}} = state) do
    case state.serializer.module.decode(raw_message) do
      {:ok, message} ->
        case Role.map_handle_message(state.role.state, message, self()) do
          {:ok, role_state} ->
            #:ok = send_from(state.owner, message)
            {:noreply, put_in(state.role[:state], role_state)}
          {:error, reason} ->
            {:stop, {{:role_hook, :handle_message}, reason}, state}
        end
      {:error, reason} ->
        {:stop, {:serializer, reason}, state}
    end
  end

  # NOTE: transport errors
  def handle_info({module, pid, {:terminating, reason}},
                  %{transport: %{module: module, pid: pid}} = state) do
    {:stop, reason, state}
  end

  # Private Functions

  @spec send_from(pid, any) :: :ok
  defp send_from(pid, message) do
    send(pid, {__MODULE__, self(), message})
    :ok
  end

  @spec normalize_options(Keyword.t) :: tuple
  defp normalize_options(options) when is_list(options) do
    case Dict.get(options, :roles, []) |> Role.normalize_role_options() do
      {:ok, role_options} ->
        %{transport: Dict.get(options, :transport),
          serializer: Dict.get(options, :serializer,
                               @default_serializer_module),
          role: %{options: role_options,
                  features: Dict.get(options, :features,
                                     Role.collect_features(role_options))}}
          |> normalize_options()
      {:error, reason} -> {:error, {:role, reason}}
    end
  end

  defp normalize_options(%{transport: nil}) do
    {:error, :transport_required}
  end

  defp normalize_options(%{transport: transport_options} = options)
      when is_list(transport_options) do
    %{options | transport: {@default_transport_module, transport_options}}
      |> normalize_options()
  end

  defp normalize_options(%{transport: transport_module} = options)
      when is_atom(transport_module) do
    %{options | transport: {transport_module, []}}
      |> normalize_options()
  end

 defp normalize_options(%{serializer: serializer_module} = options)
      when is_atom(serializer_module) do
    %{options | serializer: {serializer_module, []}}
      |> normalize_options()
  end

      defp normalize_options(%{transport: {transport_module,
                                           transport_options},
                           serializer: {serializer_module,
                                        serializer_options},
                           role: %{options: role_options}} = options)
      when is_atom(transport_module) and is_list(transport_options)
       and is_atom(serializer_module) and is_list(serializer_options)
       and is_list(role_options) do
    {:ok, options}
  end

  defp normalize_options(_options) do
    {:error, :bad_options}
  end

end
