defmodule Spell.CalleeTest do
  use ExUnit.Case

  alias Spell.Role.Callee

  @procedure "com.spell.test.callee.procedure"

  setup do
    {:ok, peer} = Crossbar.uri(Crossbar.config)
      |> Spell.connect(roles: [Callee], realm: Crossbar.realm)
    on_exit fn -> Spell.close(peer) end
    {:ok, peer: peer}
  end

  test "cast_register/{2,3} receive_registered/2", %{peer: peer} do
    {:ok, register_id} = Spell.cast_register(peer, @procedure)
    {:ok, registration} = Spell.receive_registered(peer, register_id)
    assert is_integer(registration)
  end

  test "call_register", %{peer: peer} do
    {:ok, registration} = Spell.call_register(peer, @procedure)
    assert is_integer(registration)
  end

end
