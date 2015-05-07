defmodule Spell.Serializer do
  @moduledoc """
  The `Spell.Serializer` behaviour specifies the contract for a WAMP
  serializer.

  See the [protocol
  documentation](https://github.com/tavendo/WAMP/blob/master/spec/basic.md#serializations).
  """
  use Behaviour

  alias Spell.Message

  @doc """
  Returns the name of the serializer. This is used to construct the
  sub-protocol name:

      $transport.2.$serializer

  """
  defcallback name :: String.t

  @doc """
  Set the pid which the transport should send received messages to.
  """
  defcallback decode(String.t) :: Message.t

  @doc """
  Send a message over the transport.
  """
  defcallback encode(Message.t) :: String.t

end
