defmodule Spell.Peer do
  @moduledoc """
  The `Spell.Peer` module implements the general WAMP peer behaviour.

  From the WAMP protocol:

  > A WAMP Session connects two Peers, a Client and a Router. Each WAMP
  > Peer can implement one or more roles.

  See `new` for documentation on starting new peers.
  """
  use GenServer

  alias Spell.Message
  alias Spell.Role

  require Logger

  # Module Attributes

  @supervisor_name __MODULE__.Supervisor

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

   * `:transport :: %{module: module, options: Keyword.t}` required
   * `:serializer :: %{module: module, options: Keyword.t}` required
   * `:realm :: Message.wamp_uri` required
   * `:roles :: [{module, Keyword.t}]` required
   * `:features :: map` defaults to result of role's `get_features/1` callback
   * `:owner :: pid` defaults to self()
  """
  @spec new(map | Keyword.t) :: {:ok, pid} | {:error, any}
  def new(options) when is_map(options) do
    GenServer.start_link(__MODULE__, options)
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
  @spec add(map | Keyword.t) :: {:ok, pid} | {:error, any}
  def add(options) do
    options = Dict.update(options, :owner, self(), fn
      nil       -> self()
      otherwise -> otherwise
    end)
    Supervisor.start_child(@supervisor_name, [options])
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
  Synchronously send a message to the role.
  """
  @spec call(pid, module, any) :: :ok
  def call(peer, role, message) do
    GenServer.call(peer, {:call_role, {role, message}})
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
        transport.module.send_message(transport.pid, raw_message)
      {:error, reason} ->
        {:error, {serializer.module, reason}}
    end
  end

  @doc """
  Send an Erlang message to the peer's owner.

  TODO: Rename to `notify`
  """
  @spec send_to_owner(pid, any) :: :ok
  def send_to_owner(peer, term) do
    send(peer.owner, {__MODULE__, self(), term})
    :ok
  end

  @spec notify(pid, any) :: :ok
  def notify(pid, term) do
    send(pid, {__MODULE__, self(), term})
    :ok
  end

  # GenServer Callbacks

  def init(options) do
    case Enum.into(options, %{}) do
      %{transport: %{module: transport_module,
                     options: transport_options},
        serializer: %{module: serializer_module,
                      options: _serializer_options},
        owner: owner,
        realm: realm,
        role: %{options: role_options, features: role_features},
        retries: retries,
         retry_interval: retry_interval} ->
        send(self(), {:role_hook, :init})
        {:ok, %__MODULE__{transport: %{module: transport_module,
                                       options: transport_options,
                                       pid: nil},
                          serializer: %{module: serializer_module},
                          owner: owner,
                          realm: realm,
                          role: %{options: role_options,
                                  state: nil,
                                  features: role_features},
                          retries: retries,
                          retry_interval: retry_interval}}
      _ -> {:error, :badargs}
    end
  end

  def handle_call({:call_role, {role, message}}, from, state) do
    case Role.call(state.role.state, role, message, from, state) do
      {:ok, reply, role_state} ->
        {:reply, reply, put_in(state.role[:state], role_state)}
      {:error, reason} ->
        {:stop, {:cast_role, reason}, state}
    end
  end

  def handle_cast({:send_message, %Message{} = message}, state) do
    case send_message(state, message) do
      :ok              -> {:noreply, state}
      {:error, reason} -> {:stop, {:send_message, reason}, state}
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
        Logger.debug(fn -> "Peer error on reconnect: #{inspect(reason)}" end)
        case state.retries - 1 do
          # TODO: store the retry timer to properly cancel it on
          # the peer being shutdown, or a different reconnect message coming in
          retries when retries > 0 ->
            :erlang.send_after(state.retry_interval, self,
                               {:transport, :reconnect})
            {:noreply, %{state | retries: retries}}
          retries when retries <= 0 ->
            # The stop is `normal` in the sense that it wasn't caused by
            # an internal error and the process shouldn't be restarted
            send_to_owner(state, {:error, {:transport, reason}})
            {:stop, :normal, state}
        end
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
        Logger.debug(fn ->
          "Peer #{inspect(pid)} received #{inspect(message)}" end)
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

  def handle_info({module, pid, {:terminating, {:error, :badframe, reason}}},
                  %{transport: %{module: module, pid: pid}} = state) do
    # NOTE: the transport closed
    send_to_owner(state, {:error, {:transport, reason}})
    {:stop, {:transport, reason}, state}
  end

  def terminate(reason, _state) do
    Logger.debug(fn -> "Peer terminating due to: #{inspect(reason)}" end)
  end

end
