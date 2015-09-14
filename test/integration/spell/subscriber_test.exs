defmodule Spell.SubscriberTest do
  use ExUnit.Case

  alias Spell.Role.Subscriber
  alias Spell.Message
  alias Spell.Peer

  @topic "com.spell.test.topic"

  setup do
    {:ok, peer} = Crossbar.uri(Crossbar.get_config())
      |> Spell.connect(roles: [Subscriber], realm: Crossbar.get_realm())
    on_exit fn -> if Process.alive?(peer), do: Spell.close(peer) end
    {:ok, peer: peer}
  end

  test "cast_subscribe/2", %{peer: peer} do
    {:ok, subscriber_id} = Subscriber.cast_subscribe(peer, @topic)
    assert is_integer(subscriber_id)
    assert_receive {Peer, ^peer, %Message{type: :subscribed}}
  end

  test "multiple processes", %{peer: peer} do
    tasks = for topic <- [@topic, @topic, @topic] do
      Task.async(fn ->
        {:ok, subscription} = Subscriber.call_subscribe(peer, topic)
        subscription
      end)
    end

    subscriptions = for task <- tasks, do: Task.await(task)

    for subscription <- subscriptions do
      assert {:error, :not_owner} =
        Subscriber.call_unsubscribe(peer, subscription)
    end
  end

  test "call_subscribe/2", %{peer: peer} do
    {:ok, subscription} = Subscriber.call_subscribe(peer, @topic)
    assert is_integer(subscription)
  end

  test "stop/1", %{peer: peer} do
    :ok = Peer.stop(peer)
    refute_receive(_)
  end

  test "stop/1 open SUBSCRIBE", %{peer: peer} do
    {:ok, _} = Subscriber.cast_subscribe(peer, @topic)
    :ok = Peer.stop(peer)
    assert_receive({Peer, ^peer, {:closed, :subscribe}})
  end

  test "stop/1 open UNSUBSCRIBE", %{peer: peer} do
    {:ok, subscription} = Subscriber.call_subscribe(peer, @topic)
    {:ok, _} = Subscriber.cast_unsubscribe(peer, subscription)
    :ok = Peer.stop(peer)
    assert_receive({Peer, ^peer, {:closed, {:unsubscribe, ^subscription}}})
  end

end
