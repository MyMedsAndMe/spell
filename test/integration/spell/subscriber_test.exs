defmodule Spell.SubscriberTest do
  use ExUnit.Case

  alias Spell.Role.Subscriber
  alias Spell.Message

  @topic "com.spell.test.topic"

  setup do
    {:ok, peer} = Crossbar.uri(Crossbar.get_config())
      |> Spell.connect(roles: [Subscriber], realm: Crossbar.get_realm())
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
