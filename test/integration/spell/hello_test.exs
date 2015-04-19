defmodule Spell.HelloTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Peer
  alias Spell.Message
  alias Spell.Transport
  alias Spell.Serializer

  setup do
    {:ok, peer} = Peer.new(transport: {Transport.WebSocket, Crossbar.config},
                           serializer: Serializer.JSON)
    {:ok, [peer: peer]}
  end

  test "new/1", %{peer: peer} do
    assert peer.transport == Transport.WebSocket
    assert peer.serializer == Serializer.JSON
  end

  test "send/2", %{peer: peer} do
    args = ["my.realm",
            %{roles: %{publisher: %{}, subscriber: %{}}}]
    assert :ok == Peer.send(peer, Message.new!(type: :hello, args: args))
    assert_receive {Spell, _pid, %Message{}}
  end

end
