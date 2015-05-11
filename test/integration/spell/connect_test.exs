defmodule Spell.ConnectTest do
  use ExUnit.Case

  alias Spell.Transport.WebSocket

  @serializer "json"
  @bad_host   "192.168.100.100"
  @bad_uri    "ws://" <> @bad_host

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

  test "connecting the websocket to a bad host" do
    assert {:error, reason} =
      WebSocket.connect(@serializer, host: @bad_host, port: 80)
    assert reason in [:timeout, :enetunreach],
      "the reason is timeout if the network is available, enetunreach if not"
  end

  test "connecting the peer to a bad host" do
    {:error, reason} = Spell.connect(@bad_uri,
                                     realm: Crossbar.realm,
                                     retries: 1)
    assert reason in [:timeout, :enetunreach],
      "the reason is timeout if the network is available, enetunreach if not"
  end


end
