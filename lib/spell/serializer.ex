defmodule Spell.Serializer do
  @moduledoc """
  The `Spell.Serializer` behaviour specifies the contract for a WAMP
  serializer.
  """
  use Behaviour

  alias Spell.Message

  @doc """
  Returns the transport specific data of the serializer. This is used among
  other things to construct the sub-protocol name:

      $transport.2.$serializer

  """
  defcallback transport_info(module :: atom) :: map

  @doc """
  Decodes a binary string encoded message
  """
  defcallback decode(String.t) :: Message.t

  @doc """
  Encodes a message into a binary string
  """
  defcallback encode(Message.t) :: String.t

end
