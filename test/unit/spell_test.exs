defmodule SpellTest do
  use ExUnit.Case

  alias TestHelper.Crossbar

  setup do: {:ok, Crossbar.config}

  test "connect/1", config do
    {:ok, pid} = Crossbar.get_uri(config) |> Spell.new_peer()
  end
end
