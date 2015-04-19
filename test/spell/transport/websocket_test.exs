defmodule Spell.Transport.WebSocketTest do
  use ExUnit.Case

  alias Spell.Transport.WebSocket
  alias TestHelper.Crossbar

  setup do: {:ok, Crossbar.config}

  @serializer Spell.Serializer.JSON

  test "new/1", %{host: host, port: port} do
    assert {:error, {:missing, keys}} =
      WebSocket.connect(@serializer, [])
    assert :host in keys

    {:ok, transport} =
      WebSocket.connect(@serializer, host: host, port: port, path: "/ws")
    assert transport
  end

  test "new/1 -- bad host" do
    assert {:error, :nxdomain} =
      WebSocket.connect(@serializer, host: "bad_host")
    assert {:error, :nxdomain} =
      WebSocket.connect(@serializer, host: "bad_host", port: 8080)
  end

  test "new/1 -- bad other", %{host: host, port: port} do
    assert {:error, {404, _}} =
      WebSocket.connect(@serializer, host: host, port: port)
  end
end
