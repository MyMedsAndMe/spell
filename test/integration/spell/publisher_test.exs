defmodule Spell.PublisherTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Peer
  alias Spell.Role.Publisher

  @topic "com.spell.test.topic"
  @realm "realm1"

  setup do
    {:ok, peer} = Crossbar.get_uri(Crossbar.config)
      |> Spell.connect(roles: [Publisher], realm: @realm)
    on_exit fn -> Spell.close(peer) end
    {:ok, peer: peer}
  end

  test "publish/{2,3}", %{peer: peer} do
    {:ok, publish_id} =
      Publisher.publish(peer, @topic, options: %{acknowledge: true})
    assert_receive {Peer, ^peer, %{type: :published,
                                   args: [^publish_id | _]}}
    {:ok, _} = Publisher.publish(peer, @topic)
    refute_receive {Peer, ^peer, %{type: :published}}
  end
end
