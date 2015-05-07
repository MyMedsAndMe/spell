defmodule Spell.SessionTest do
  use ExUnit.Case

  alias Spell.Role.Session
  alias Spell.Message

  setup do
    {:ok, peer} = Crossbar.get_uri(Crossbar.config)
      |> Spell.connect(realm: Crossbar.realm, features: %{publisher: %{}})
    {:ok, peer: peer}
  end

  @tag :integration
  test "call_goodbye/1", %{peer: peer} do
    assert {:ok, %Message{type: :goodbye}} = Session.call_goodbye(peer)
  end
end
