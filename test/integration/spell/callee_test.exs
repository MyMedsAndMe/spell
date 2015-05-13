defmodule Spell.CalleeTest do
  use ExUnit.Case

  alias Spell.Role.Callee

  @procedure "com.spell.test.callee.procedure"

  setup do
    {:ok, peer} = Crossbar.uri(Crossbar.get_config())
      |> Spell.connect(roles: [Callee], realm: Crossbar.get_realm())
    on_exit fn -> Spell.close(peer) end
    {:ok, peer: peer}
  end

  @tag :integration
  test "cast_register/{2,3} receive_registered/2", %{peer: peer} do
    {:ok, register_id} = Spell.cast_register(peer, @procedure)
    {:ok, registration} = Spell.receive_registered(peer, register_id)
    assert is_integer(registration)
  end

  @tag :integration
  test "multiple processes", %{peer: peer} do
    tasks = for procedure <- ["proc.1", "proc.2", "proc.3"] do
      Task.async(fn ->
        {:ok, registration} = Callee.call_register(peer, procedure)
        registration
      end)
    end

    registrations = for task <- tasks, do: Task.await(task)

    for registration <- registrations do
      assert {:error, :not_owner} =
        Callee.call_unregister(peer, registration)
    end
  end

  @tag :integration
  test "call_register", %{peer: peer} do
    {:ok, registration} = Spell.call_register(peer, @procedure)
    assert is_integer(registration)
  end

end
