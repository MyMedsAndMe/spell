defmodule Spell.Peer do
  @moduledoc """
  The `Spell.Peer` module implements the general WAMP peer behaviour.

  From the docuemntation:

  > A WAMP Session connects two Peers, a Client and a Router. Each WAMP
  > Peer can implement one or more roles.

  """
  use GenServer

  defstruct [:transport, :serializer]

  # Type Specs

  @type transport  :: map
  @type serializer :: atom
  @type t :: %__MODULE__{
    transport: map,
    serializer: atom}

  # Public Functions

  @doc """
  Create a new peer using `transport` and `serializer`.
  """
  @spec new(transport, serializer) :: {:ok, t} | {:error, term}
  def new(transport, serializer) do
    {:ok, %__MODULE__{transport: transport, serializer: serializer}}
  end

end
