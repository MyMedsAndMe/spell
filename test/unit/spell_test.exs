defmodule SpellTest do
  use ExUnit.Case

  setup do: {:ok, Crossbar.config}

  @tag :integration
  test "connect/1", config do
    {:ok, peer} = Crossbar.uri(config)
      |> Spell.connect(realm: Crossbar.realm)
    assert :ok == Spell.close(peer)
  end
end
