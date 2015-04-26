defmodule Spell.Peer do
  @moduledoc """
  The `Spell.Peer` module implements the general WAMP peer behaviour.

  From the documentation:

  > A WAMP Session connects two Peers, a Client and a Router. Each WAMP
  > Peer can implement one or more roles.

  """
  use GenServer

  alias Spell.Message
  alias Spell.Role

  require Logger

  # Module Attributes

  @supervisor_name __MODULE__.Supervisor

  @default_serializer_module Spell.Serializer.JSON
  @default_transport_module  Spell.Transport.WebSocket

  @default_retries           5
  @default_retry_interval    1000

  defstruct [:transport,
             :serializer,
             :owner,
             :role,
             :realm,
             :retries,
             :retry_interval]

  # Type Specs

  @type start_option ::
     {:serializer, module}
   | {:transport, {module, Keyword.t}}

  @type t :: %__MODULE__{
    transport:      map,
    serializer:     map,
    owner:          pid,
    role:           map,
    retry_interval: integer,
    retries:        integer}

  # Public Functions

  @doc """
  Start `Spell.Peer.Supervisor`.
  """
  def start_link() do
    import Supervisor.Spec
    child = worker(__MODULE__, [], [function: :new, restart: :transient])
    options = [strategy: :simple_one_for_one, name: @supervisor_name]
    Supervisor.start_link([child], options)
  end

  @doc """
  Start a new peer with `options`. This function can be used to start a child
  outside of the supervision tree.

  ## Options

   * `:transport :: {module, Keyword.t} | Keyword.t` required
   * `:realm :: Message.wamp_uri` required
   * `:serializer :: module` defaults to #{}
   * `:roles :: [{module, Keyword.t}]`
   * `:owner :: pid`
   * `:retries :: integer`
   * `:features :: map`
  """
  @spec new([start_option]) :: {:ok, t} | {:error, any}
  def new(options) when is_list(options) do
    GenServer.start_link(__MODULE__, {self(), options})
  end

  @doc """
  Stop the `peer` process.
  """
  def stop(peer) do
    GenServer.cast(peer, :stop)
  end

  @doc """
  Add a new child as part of the supervision tree.

  ## Options

  See `new/1`.
  """
  def add(options) do
    Supervisor.start_child(@supervisor_name,
                           [[{:owner, self()} | options]])
  end

  @doc """
  Block until the process receives a message from `peer` of `type` or timeout.
  """
  @spec await(pid, atom, integer) :: {:ok, t} | {:error, timeout}
  def await(peer, type, timeout \\ 1000)
      when is_pid(peer) and is_atom(type) do
    receive do
      {__MODULE__, ^peer, %Message{type: ^type} = message} ->
        {:ok, message}
    after
      timeout ->
        {:error, :timeout}
    end
  end

  # Public Role Interface

  @doc """
  Cast a message to a specific role.
  """
  @spec cast_role(pid, module, any) :: :ok
  def cast_role(peer, role, message) do
    GenServer.cast(peer, {:cast_role, {role, message}})
  end

  @doc """
  Send a WAMP message from the peer.

  If a pid is provided as the peer, the message will be cast to and
  sent from the peer process. If it is the peer state, the message
  is sent directly.
  """
  @spec send_message(pid | t, Message.t) :: :ok | {:error, any}
  def send_message(peer, %Message{} = message) when is_pid(peer) do
    GenServer.cast(peer, {:send_message, message})
  end
  def send_message(%__MODULE__{transport: transport, serializer: serializer},
                   %Message{} = message) do
    case serializer.module.encode(message) do
      {:ok, raw_message} ->
        transport.module.send_message(transport.pid,
                                      raw_message)

      {:error, reason} ->
        {:error, {serializer.module, reason}}
    end
  end

  @doc """
  Send an Erlang message to the peer's owner.
  """
  @spec send_to_owner(pid, any) :: :ok
  def send_to_owner(peer, term) do
    send(peer.owner, {__MODULE__, self(), term})
    :ok
  end

  # GenServer Callbacks

  def init({owner, options}) do
    # TODO: collection options + handle errors cleanly.
    # normalize_options should return the state(?)
    case normalize_options(options) do
      {:ok, %{transport: {transport_module, transport_options},
              serializer: {serializer_module, _serializer_options},
              owner: options_owner,
              realm: realm,
              role: %{options: role_options, features: role_features},
              retries: retries,
              retry_interval: retry_interval}} ->
        send(self(), {:role_hook, :init})
        {:ok, %__MODULE__{transport: %{module: transport_module,
                                       options: transport_options,
                                       pid: nil},
                          serializer: %{module: serializer_module},
                          owner: options_owner || owner,
                          realm: realm,
                          role: %{options: role_options,
                                  state: nil,
                                  features: role_features},
                          retries: retries,
                          retry_interval: retry_interval}}
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_cast({:send_message, %Message{} = message}, state) do
    case send_message(state, message) do
      :ok              -> {:noreply, state}
      {:error, reason} -> {:stop, {:send_message, reason}, state}
    end
  end

  def handle_cast({:cast_role, {role, message}}, state) do
    case Role.cast(state.role.state, role, state, message) do
      {:ok, role_state} ->
        {:noreply, put_in(state.role[:state], role_state)}
      {:error, reason} ->
        {:stop, {:cast_role, reason}, state}
    end
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
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
  def handle_info({:transport, :reconnect},
                  %{transport: %{pid: nil} = transport,
                    serializer: serializer} = state) do
    # WARNING: role states aren't reset. TBD if this is a good thing
    case transport.module.connect(serializer.module.name(),
                                  transport.options) do
      {:ok, pid} ->
        Logger.debug(fn -> "Connected using #{inspect(state)}" end)
        send(self(), {:role_hook, :on_open})
        {:noreply, put_in(state.transport[:pid], pid)}
      {:error, reason} ->
        {:stop, {:transport, reason}, state}
    end
  end

  def handle_info({:role_hook, :on_open}, state) do
    case Role.map_on_open(state.role.state, state) do
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
        case Role.map_handle_message(state.role.state, message, state) do
          {:ok, role_state} ->
            {:noreply, put_in(state.role[:state], role_state)}
          {:close, _reasons, role_state} ->
            # NOTE: if close == normal, are reasons necessary?
            {:stop, :normal, put_in(state.role[:state], role_state)}
          {:error, reason} ->
            {:stop, {{:role_hook, :handle_message}, reason}, state}
        end
      {:error, reason} ->
        {:stop, {:serializer, reason}, state}
    end
  end

  def handle_info({module, pid, {:terminating, reason}},
                  %{transport: %{module: module, pid: pid}} = state) do
    # NOTE: the transport closed
    {:stop, {:transport, reason}, state}
  end

  def terminate(reason, _state) do
    Logger.debug(fn -> "Peer terminating due to: #{inspect(reason)}" end)
  end

  # Private Functions

  @spec normalize_options(Keyword.t) :: tuple
  defp normalize_options(options) when is_list(options) do
    # TODO: This function is a mess. Eagerly awaiting extract :)
    case Dict.get(options, :roles, []) |> Role.normalize_role_options() do
      {:ok, role_options} ->
        %{transport: Dict.get(options, :transport),
          serializer: Dict.get(options, :serializer,
                               @default_serializer_module),
          owner: Dict.get(options, :owner),
          role: %{options: role_options,
                  features: Dict.get(options, :features,
                                     Role.collect_features(role_options))},
          realm: Dict.get(options, :realm),
          retries: Dict.get(options, :retries, @default_retries),
          retry_interval: Dict.get(options, :retry_interval,
                                   @default_retry_interval)}
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
