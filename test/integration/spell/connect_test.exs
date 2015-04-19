defmodule Spell.ConnectTest do
  use ExUnit.Case

  alias Spell.Transport.WebSocket
  alias TestHelper.Crossbar

  @serializer "json"

  setup do: {:ok, Crossbar.config}

  test "connecting the websocket", %{host: host, port: port} do
    assert {:error, {:missing, keys}} =
      WebSocket.connect(@serializer, [])
    assert :host in keys

    {:ok, transport} =
      WebSocket.connect(@serializer, host: host, port: port, path: "/ws")
    assert transport
  end

  test "connecting with a bad path", %{host: host, port: port} do
    assert {:error, {404, _}} =
      WebSocket.connect(@serializer, host: host, port: port)
  end
end
