defmodule Spell.Peer do
  @moduledoc """
  The `Spell.Peer` module implements the general WAMP peer behaviour.

  From the docuemntation:

  > A WAMP Session connects two Peers, a Client and a Router. Each WAMP
  > Peer can implement one or more roles.

  """
  use GenServer

  alias Spell.Message

  @default_serializer Spell.Serializer.JSON

  defstruct [:transport,
             :serializer,
             :transport_state,
             :owner]

  # Type Specs

  @type start_option ::
     {:serializer, module}
   | {:transport, {module, Keyword.t}}

  @type t :: %__MODULE__{
    transport:  map,
    serializer: module,
    owner:      pid}

  # Public Functions

  @doc """
  Start a new peer.

  ## Options

   * `:transport :: {module, Keyword.t}`
   * `:serializer :: module`
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
    GenServer.call(peer, {:send, message})
  end

  # GenServer Callbacks

  def init({owner, options}) do
    {transport_module, options} = Dict.get(options, :transport)
    serializer = Dict.get(options, :serializer, @default_serializer)
    case transport_module.connect(serializer.name(), options) do
      {:ok, transport_pid} ->
        {:ok, %__MODULE__{transport: %{module: transport_module,
                                       options: options,
                                       pid: transport_pid},
                          serializer: %{module: serializer},
                          owner: owner}}
      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  def handle_call({:send, message}, _from, state) do
    case state.serializer.module.encode(message) do
      {:ok, raw_message} ->
        resp = state.transport.module.send_message(state.transport.pid,
                                                   raw_message)
        {:reply, resp, state}
      {:error, reason} ->
        {:reply, {:error, {:serializer, reason}}, state}
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
  def handle_info({module, pid, {:teminating, reason}},
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
