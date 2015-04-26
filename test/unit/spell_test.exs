defmodule SpellTest do
  use ExUnit.Case

  alias TestHelper.Crossbar

  setup do: {:ok, Crossbar.config}

  test "connect/1", config do
    {:ok, peer} = Crossbar.get_uri(config) |> Spell.connect()
    assert :ok == Spell.close(peer)
    :timer.sleep(100)
  end
end
