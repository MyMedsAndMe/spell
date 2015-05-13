defprotocol Spell.Transport do
  @moduledoc """
  A transport is the foundation for establishing bi-directional communication
  between two peers.

  See the [protocol
  documentation](https://github.com/tavendo/WAMP/blob/master/spec/basic.md#transports).
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
