defprotocol Spell.Transport do
  @moduledoc """
  A transport is a process.
  """
  use Behaviour

  @typep state :: any

  @doc """
  Connect the transport according to `serializer` and `options`.

  The `serializer` identifier must be passed in sibecause it is required to
  establish the transport.
  """
  defcallback connect(serializer :: module, options :: Keyword.t) ::
    {:ok, state} | {:error, any}

  @doc """
  Send a raw message over the transport.
  """
  defcallback send_message(state :: state, raw_message :: String.t) ::
    {:ok, state} | {:error, any}

end
