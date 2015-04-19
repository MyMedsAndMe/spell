defprotocol Spell.Transport do
  @moduledoc """
  A transport is a process.
  """
  use Behaviour
  alias Spell.Message

  @typep state :: any

  @doc """
  Set the pid which the transport should send received messages to.

  Once connected, The transport must send all messages it receives to
  the owner process. See `Spell.Transport.send/2`.

  NB: This function is called by the owner process.
  """
  defcallback connect(serializer :: module, options :: Keyword.t) ::
    {:ok, state} | {:error, any}

  @doc """
  Send a raw message over the transport.
  """
  defcallback send_message(state :: state, raw_message :: String.t) ::
    {:ok, state} | {:error, any}

end
