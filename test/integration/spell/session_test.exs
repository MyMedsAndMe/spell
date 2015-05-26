defmodule Spell.SessionTest do
  use ExUnit.Case

  alias Spell.Role.Session
  alias Spell.Message

  setup do
    {:ok, peer} = Crossbar.uri(Crossbar.get_config())
    |> Spell.connect(realm: Crossbar.get_realm(),
                     features: %{publisher: %{}})
    {:ok, peer: peer}
  end

  test "call_goodbye/1", %{peer: peer} do
    assert {:ok, %Message{type: :goodbye}} = Session.call_goodbye(peer)
  end
end
