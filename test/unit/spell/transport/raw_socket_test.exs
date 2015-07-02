defmodule Spell.Transport.RawSocketTest do
  use ExUnit.Case

  alias Spell.Transport.RawSocket

  @serializer Spell.Config.serializer

  test "new/1 -- bad host" do
    assert {:error, :nxdomain} =
      RawSocket.connect(@serializer, host: "bad_host")
    assert {:error, :nxdomain} =
      RawSocket.connect(@serializer, host: "bad_host", port: 9000)
  end
end
