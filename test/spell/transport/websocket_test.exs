defmodule Spell.Transport.WebSocketTest do
  use ExUnit.Case, async: false

  alias Spell.Transport.WebSocket
  alias TestHelper.Crossbar

  setup do: {:ok, Crossbar.config}

  test "new/1", %{host: host, port: port} do
    assert {:error, {:missing, keys}} = WebSocket.new([])
    for key <- [:host, :port], do: assert key in keys

    {:ok, transport} = WebSocket.new(host: host, port: port, gun_opts: [:trace])
    assert transport
  end

end
