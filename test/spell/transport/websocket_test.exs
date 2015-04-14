defmodule Spell.Transport.WebSocketTest do
  use ExUnit.Case

  alias Spell.Transport.WebSocket
  alias TestHelper.Crossbar

  setup do: {:ok, Crossbar.config}

  test "new/1", %{host: host, port: port} do
    assert {:error, {:missing, keys}} = WebSocket.new([])
    assert :host in keys

    {:ok, transport} = WebSocket.new(host: host, port: port, path: "/ws")
    assert transport
  end

  test "new/1 -- bad host" do
    assert {:error, :nxdomain} = WebSocket.new(host: "bad_host")
    assert {:error, :nxdomain} = WebSocket.new(host: "bad_host", port: 8080)
  end

  test "new/1 -- bad other", %{host: host, port: port} do
    assert {:error, {404, _}} = WebSocket.new(host: host, port: port)
  end
end
