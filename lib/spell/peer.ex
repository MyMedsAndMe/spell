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
             :transport_state]

  # Type Specs

  @type new_option ::
     {:serializer, module}
   | {:transport, module}

  @type t :: %__MODULE__{
    transport:       module,
    serializer:      module,
    transport_state: any}

  # Public Functions

  @doc """
  Create a new peer.
  """
  @spec new([new_option]) :: {:ok, t} | {:error, any}
  def new(options) do
    {transport, options} = Dict.get(options, :transport)
    serializer = Dict.get(options, :serializer, @default_serializer)
    case transport.connect(serializer, options) do
      {:ok, transport_state} ->
        {:ok, %__MODULE__{transport: transport,
                          serializer: serializer,
                          transport_state: transport_state}}
      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  @doc """
  Send a message via the peer.
  """
  @spec send(t, Message.t) :: :ok | {:error, any}
  def send(%__MODULE__{} = peer, %Message{} = message) do
    case peer.serializer.encode(message) do
      {:ok, encoded_message} ->
        peer.transport.send_message(peer.transport_state, encoded_message)
      {:error, reason} ->
        {:error, {:serializer, reason}}
    end
  end

end
