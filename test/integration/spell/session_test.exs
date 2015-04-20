defmodule Spell.SessionTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Peer
  alias Spell.Role.Session
  alias Spell.Transport
  alias Spell.Serializer

  @realm "realm1"

  setup do: {:ok, [config: Crossbar.config]}

  test "peer with session", %{config: config} do
    {:ok, peer} = Peer.start_link(transport: {Transport.WebSocket, config},
                                  serializer: Serializer.JSON,
                                  role: [{Session, [realm: @realm]}])
    assert_receive {Peer, ^peer, %{type: :welcome}}
  end
end
