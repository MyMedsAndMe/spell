defmodule SpellTest do
  use ExUnit.Case

  alias TestHelper.Crossbar

  setup do: {:ok, Crossbar.config}

  test "nothing" do
    assert 1 + 1 == 2
  end
end
