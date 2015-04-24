defmodule Spell.PublisherTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Peer
  alias Spell.Role.Session
  alias Spell.Role.Publisher

  @topic "com.spell.test.topic"
  @realm "realm1"

  setup do
    {:ok, peer} = Peer.new(transport: Crossbar.config,
                                  features: %{publisher: %{}},
                                  roles: [{Session, [realm: @realm]},
                                          Publisher])
    receive do
      {Spell.Peer, ^peer, %{type: :welcome}} ->
        {:ok, [peer: peer]}
      after
        1000 -> {:error, :timeout}
    end
  end

  test "publish/{2,3}", %{peer: peer} do
    {:ok, publish_id} =
      Publisher.publish(peer, @topic, options: %{acknowledge: true})
    assert_receive {Spell.Peer, ^peer, %{type: :published,
                                         args: [^publish_id | _]}}

    {:ok, _} = Publisher.publish(peer, @topic)
    refute_receive {Spell.Peer, ^peer, %{type: :published}}
  end
end
