defmodule Spell.SessionTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Role.Session
  alias Spell.Message

  @realm "realm1"

  setup do
    {:ok, peer} = Crossbar.get_uri(Crossbar.config)
      |> Spell.connect(realm: @realm, features: %{publisher: %{}})
    on_exit fn -> Spell.close(peer) end
    {:ok, peer: peer}
  end

  test "call_goodbye/1", %{peer: peer} do
    assert {:ok, %Message{type: :goodbye}} = Session.call_goodbye(peer)
  end
end
