defmodule Spell.RPCTest do
  use ExUnit.Case

  alias Spell.Role.Caller
  alias Spell.Role.Callee
  alias Spell.Message

  @procedure "com.spell.test.rpc.topic"

  setup do
    {:ok, caller} = Crossbar.get_uri(Crossbar.config)
      |> Spell.connect(realm: Crossbar.realm, roles: [Caller])
    {:ok, callee} = Crossbar.get_uri(Crossbar.config)
      |> Spell.connect(realm: Crossbar.realm, roles: [Callee])
    on_exit fn ->
      for peer <- [caller, callee], do: Spell.close(peer)
    end
    {:ok, caller: caller, callee: callee}
  end

  @tag :integration
  test "rpc end to end", %{caller: caller, callee: callee} do
    {:ok, registration} = Spell.call_register(callee, @procedure)
    {:ok, call_id} = Spell.cast_call(caller, @procedure)
    assert_receive {Spell.Peer, ^callee,
                    %Message{type: :invocation,
                             args: [invocation, ^registration, %{}]}}

    :ok = Spell.cast_yield(callee, invocation)
    assert_receive {Spell.Peer, ^caller,
                    %Message{type: :result, args: [^call_id, %{}]}}
  end

end
