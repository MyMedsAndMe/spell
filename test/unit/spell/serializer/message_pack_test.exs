defmodule Spell.Serializer.MessagePackTest do
  use ExUnit.Case

  alias Spell.Serializer
  alias Spell.Message

  @test_realm "the.test.realm"

  test "decode/1" do
    assert {:ok, %{type: :hello, code: 1, args: []}} =
      Serializer.MessagePack.decode([<<145>>, [<<1>>]])
    assert {:ok, %{type: :hello, code: 1, args: [@test_realm]}} =
      Serializer.MessagePack.decode([<<146>>, [<<1>>, [<<174>>, "#{@test_realm}"]]])
  end

  test "encode/1" do
    assert {:ok, <<145, 1>>} == Message.new!(type: :hello)
      |> Serializer.MessagePack.encode()
    assert {:ok, <<146, 1, 174, "#{@test_realm}">>} ==
      Message.new!(code: 1, args: [@test_realm])
      |> Serializer.MessagePack.encode()
  end
end
