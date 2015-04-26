defmodule Spell.SubscribeTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Peer
  alias Spell.Role.Session
  alias Spell.Role.Subscriber

  @topic "com.spell.test.topic"
  @realm "realm1"

  setup do
    {:ok, peer} = Peer.new(transport: Crossbar.config,
                           realm: @realm,
                           roles: [Session, Subscriber])
    on_exit fn ->
      Peer.stop(peer)
    end
    receive do
      {Spell.Peer, ^peer, %{type: :welcome}} ->
        {:ok, [peer: peer]}
      after
        1000 -> {:error, :timeout}
    end
  end

  test "subscribe/2", %{peer: peer} do
    {:ok, subscriber_id} = Subscriber.subscribe(peer, @topic)
    assert is_integer(subscriber_id)
  end

end
