defmodule Spell.Peer do
  @moduledoc """
  The `Spell.Peer` module implements the general WAMP peer behaviour.

  From the docuemntation:

  > A WAMP Session connects two Peers, a Client and a Router. Each WAMP
  > Peer can implement one or more roles.

  """
  use GenServer
end
