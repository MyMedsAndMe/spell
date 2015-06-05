defmodule Spell.Transport.WebSocketTest do
  use ExUnit.Case

  alias Spell.Transport.WebSocket

  @serializer Application.get_env(:spell, :serializer)

  setup do: {:ok, Crossbar.get_config()}

  test "new/1 -- bad host" do
    assert {:error, :nxdomain} =
      WebSocket.connect(@serializer, host: "bad_host")
    assert {:error, :nxdomain} =
      WebSocket.connect(@serializer, host: "bad_host", port: 8080)
  end

  test "connecting with a bad path", %{host: host, port: port} do
    assert {:error, {404, _}} =
      WebSocket.connect(@serializer, host: host, port: port, path: "/bad_path")
  end

end
