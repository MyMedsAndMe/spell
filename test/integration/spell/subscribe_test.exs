defmodule Spell.SubscribeTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Peer
  alias Spell.Role.Session
  alias Spell.Role.Subscriber

  @topic "com.spell.test.topic"
  @realm "realm1"

  setup do
    {:ok, peer} = Peer.start_link(transport: Crossbar.config,
                                  features: %{publisher: %{}},
                                  roles: [{Session, [realm: @realm]},
                                          Subscriber])
    receive do
      {Spell.Peer, ^peer, %{type: :welcome}} ->
        {:ok, [peer: peer]}
      after
        1000 -> {:error, :timeout}
    end
  end

  test "subscribe/2", %{peer: peer} do
    {:ok, subscriber_id} = Subscriber.subscribe(peer, @topic)
  end

end
