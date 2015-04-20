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

  @default_serializer Spell.Serializer.JSON

  defstruct [:transport,
             :serializer,
             :transport_state,
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
    role:       map}

  # Public Functions

  @doc """
  Start a new peer.

  ## Options

   * `:transport :: {module, Keyword.t}`
   * `:serializer :: module`
   * `:role :: [{module, Keyword.t}]`
  """
  @spec start_link([start_option]) :: {:ok, t} | {:error, any}
  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, {self(), options})
  end

  @doc """
  Send a message via the peer.
  """
  @spec send_message(pid, Message.t) :: :ok | {:error, any}
  def send_message(peer, %Message{} = message) do
    GenServer.cast(peer, {:send_message, message})
  end

  @doc """
  Send a message to the peer's owner.
  """
  @spec send_to_owner(pid, any) :: :ok | {:error, any}
  def send_to_owner(peer, term) do
    GenServer.cast(peer, {:send_to_owner, term})
  end

  # GenServer Callbacks

  def init({owner, options}) do
    {transport_module, transport_options} = Dict.get(options, :transport)
    serializer = Dict.get(options, :serializer, @default_serializer)
    send(self(), {:role_hook, :init})
    {:ok, %__MODULE__{transport: %{module: transport_module,
                                   options: transport_options,
                                   pid: nil},
                      serializer: %{module: serializer},
                      owner: owner,
                      role: %{options: Dict.get(options, :role, []),
                              state: nil}}}
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

  def handle_info({:role_hook, :init}, %{role: %{state: nil}} = state) do
    case Role.map_init(state.role.options) do
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
    # NB: role state's aren't reset. TBD if this is a good thing
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
        {:stop, {{:role_hook, :init}, reason}, state}
    end
  end

  def handle_info({module, pid, {:message, raw_message}},
                  %{transport: %{module: module, pid: pid}} = state) do
    case state.serializer.module.decode(raw_message) do
      {:ok, message} ->
        :ok = send_from(state.owner, message)
        {:noreply, state}
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

  # This would make a decent macro
  @spec send_from(pid, any) :: :ok
  def send_from(pid, message) do
    send(pid, {__MODULE__, self(), message})
    :ok
  end

end
