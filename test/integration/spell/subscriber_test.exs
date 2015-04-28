defmodule Spell.SubscriberTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Role.Subscriber
  alias Spell.Message

  @topic "com.spell.test.topic"
  @realm "realm1"

  setup do
    {:ok, peer} = Crossbar.get_uri(Crossbar.config)
      |> Spell.connect(roles: [Subscriber], realm: @realm)
    on_exit fn -> Spell.close(peer) end
    {:ok, peer: peer}
  end

  test "cast_subscribe/2", %{peer: peer} do
    {:ok, subscriber_id} = Subscriber.cast_subscribe(peer, @topic)
    assert is_integer(subscriber_id)
    assert_receive {Spell.Peer, ^peer, %Message{type: :subscribed}}
  end

  test "call_subscribe/2", %{peer: peer} do
    {:ok, subscription} = Subscriber.call_subscribe(peer, @topic)
    assert is_integer(subscription)
  end

end
