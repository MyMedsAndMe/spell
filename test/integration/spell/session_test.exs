defmodule Spell.SessionTest do
  use ExUnit.Case

  alias Spell.Role.Session
  alias Spell.Message
  alias Spell.Peer

  setup do
    {:ok, peer} = Crossbar.uri(Crossbar.get_config())
    |> Spell.connect(realm: Crossbar.get_realm(),
                     features: %{publisher: %{}})
    {:ok, peer: peer}
  end

  test "call_goodbye/1", %{peer: peer} do
    assert {:ok, %Message{type: :goodbye}} = Session.call_goodbye(peer)
  end

  test "stop/1 with open GOODBYE", %{peer: peer} do
    :ok = Session.cast_goodbye(peer)
    :ok = Peer.stop(peer)
    assert_receive({Peer, ^peer, {:closed, :goodbye}})
  end
end
