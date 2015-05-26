defmodule Spell.Transport.WebSocketTest do
  use ExUnit.Case

  alias Spell.Transport.WebSocket

  @serializer Application.get_env(:spell, :serializer)

  test "new/1 -- bad host" do
    assert {:error, :nxdomain} =
      WebSocket.connect(@serializer, host: "bad_host")
    assert {:error, :nxdomain} =
      WebSocket.connect(@serializer, host: "bad_host", port: 8080)
  end
end
