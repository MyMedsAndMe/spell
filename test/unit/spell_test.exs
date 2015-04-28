defmodule SpellTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Role.Publisher

  setup do: {:ok, Crossbar.config}

  test "connect/1", config do
    {:ok, peer} = Crossbar.get_uri(config)
      |> Spell.connect(realm: Crossbar.realm, roles: [Publisher])
    assert :ok == Spell.close(peer)
  end
end
