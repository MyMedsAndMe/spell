defmodule Spell.PubSubTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Role.Publisher
  alias Spell.Role.Subscriber
  alias Spell.Message

  @topic "com.spell.test.pubsub.topic"

  setup do
    {:ok, publisher} = Crossbar.get_uri(Crossbar.config)
      |> Spell.connect(realm: Crossbar.realm, roles: [Publisher])
    {:ok, subscriber} = Crossbar.get_uri(Crossbar.config)
      |> Spell.connect(realm: Crossbar.realm, roles: [Subscriber])
    on_exit fn ->
      for peer <- [publisher, subscriber], do: Spell.close(peer)
    end
    {:ok, publisher: publisher, subscriber: subscriber}
  end

  test "pubsub end to end", %{publisher: publisher, subscriber: subscriber} do
    {:ok, subscription} = Spell.call_subscribe(subscriber, @topic)

    for {arguments, arguments_kw} <- [{[%{}],    %{"a" => 1}},
                                      {[1, "a"], %{"a" => 1, "b" => 2}}] do
      {:ok, publication} = Spell.call_publish(publisher, @topic,
                                              arguments: arguments,
                                              arguments_kw: arguments_kw)
      assert_receive {Spell.Peer, ^subscriber,
                      %Message{type: :event,
                               args: [^subscription, ^publication, %{},
                                      ^arguments, ^arguments_kw]}}
    end
  end

end
