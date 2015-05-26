defmodule SpellTest do
  use ExUnit.Case

  setup do: {:ok, Crossbar.get_config()}

  test "connect/1", config do
    {:ok, peer} = Crossbar.uri(config)
      |> Spell.connect(realm: Crossbar.get_realm())
    assert :ok == Spell.close(peer)
  end
end
