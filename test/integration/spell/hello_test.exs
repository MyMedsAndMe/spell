defmodule Spell.HelloTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Peer
  alias Spell.Message
  alias Spell.Transport
  alias Spell.Serializer

  @realm "arealm"

  setup do
    {:ok, peer} = Peer.start_link(transport: {Transport.WebSocket,
                                              Crossbar.config},
                                  serializer: Serializer.JSON)
    {:ok, [peer: peer]}
  end

  test "new/1", %{peer: peer} do
    # Not a great test...
    assert is_pid(peer)
  end

  test "send/2", %{peer: peer} do
    args = [@realm, %{roles: %{publisher: %{}, subscriber: %{}}}]
    assert :ok == Peer.send_message(peer, Message.new!(type: :hello, args: args))
    assert_receive {Peer, _pid, %Message{}}
  end

end
