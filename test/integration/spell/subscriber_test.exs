defmodule Spell.SubscriberTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Role.Subscriber

  @topic "com.spell.test.topic"
  @realm "realm1"

  setup do
    {:ok, peer} = Crossbar.get_uri(Crossbar.config)
      |> Spell.connect(roles: [Subscriber], realm: @realm)
    on_exit fn -> Spell.close(peer) end
    {:ok, peer: peer}
  end

  test "subscribe/2", %{peer: peer} do
    {:ok, subscriber_id} = Subscriber.subscribe(peer, @topic)
    assert is_integer(subscriber_id)
  end

end
