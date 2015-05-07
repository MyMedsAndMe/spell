defmodule Spell.PublisherTest do
  use ExUnit.Case

  alias Spell.Peer
  alias Spell.Role.Publisher

  @topic "com.spell.test.topic"

  setup do
    {:ok, peer} = Crossbar.uri(Crossbar.config)
      |> Spell.connect(roles: [Publisher], realm: Crossbar.realm)
    on_exit fn -> Spell.close(peer) end
    {:ok, peer: peer}
  end

  test "cast_publish/{2,3}", %{peer: peer} do
    {:ok, publish_id} =
      Spell.cast_publish(peer, @topic, options: %{acknowledge: true})
    assert_receive {Peer, ^peer, %{type: :published,
                                   args: [^publish_id | _]}}
    {:ok, _} = Publisher.cast_publish(peer, @topic)
    refute_receive {Peer, ^peer, %{type: :published}}
  end

  @tag :integration
  test "call_publish/{2,3}", %{peer: peer} do
    {:ok, publication} = Spell.call_publish(peer, @topic)
    assert is_integer(publication)
  end
end
