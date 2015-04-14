defmodule Spell.MessageTest do
  use ExUnit.Case
  alias Spell.Message

  test "new/1" do
    assert {:error, {:code, :out_of_range}} == Message.new(code: 0)
    assert {:error, {:code, :out_of_range}} == Message.new(code: 1025)
    assert {:error, :type_code_mismatch} ==
      Message.new(type: :welcome, code: 1)
    assert {:error, {:args, :not_list}} == Message.new(code: 1, args: :bad)

  assert {:ok, %Message{code: 1, type: :hello, args: []}} ==
    Message.new(code: 1)
  end

  test "new!/1" do
    assert_raise ArgumentError, fn -> Message.new!(code: 0) end
    assert_raise ArgumentError, fn -> Message.new!(code: 1025) end
    assert_raise ArgumentError, fn -> Message.new!(type: :welcome, code: 1) end
    assert_raise ArgumentError, fn -> Message.new!(code: 1, args: :bad) end

    assert %Message{code: 1, type: :hello, args: []} == Message.new!(code: 1)
  end

  test "get_code_for_type/{1,2}" do
    assert Message.get_code_for_type(nil) == nil
    assert Message.get_code_for_type(:hello) == 1

    assert Message.get_code_for_type(nil, :default) == :default
    assert Message.get_code_for_type(:hello, :default) == 1
  end

  test "get_type_for_code/{1,2}" do
    # Poor spot tests
    assert Message.get_type_for_code(0) == nil
    assert Message.get_type_for_code(1) == :hello

    assert Message.get_type_for_code(0, :default) == :default
    assert Message.get_type_for_code(1, :default) == :hello
  end

end
