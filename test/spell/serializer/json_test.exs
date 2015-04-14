defmodule Spell.Serializer.JSONTest do
  use ExUnit.Case

  alias Spell.Serializer
  alias Spell.Message

  @test_realm "the.test.realm"

  test "decode/1" do
    assert {:ok, %{type: :hello, code: 1, args: []}} =
      Serializer.JSON.decode("[1]")
    assert {:ok, %{type: :hello, code: 1, args: [@test_realm]}} =
      Serializer.JSON.decode(~s([1,"#{@test_realm}"]))
  end

  test "encode/1" do
    assert {:ok, "[1]"} == Message.new!(type: :hello)
      |> Serializer.JSON.encode()
    assert {:ok, ~s([1,"#{@test_realm}"])} ==
      Message.new!(code: 1, args: [@test_realm])
      |> Serializer.JSON.encode()
  end
end
