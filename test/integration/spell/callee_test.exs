defmodule Spell.CalleeTest do
  use ExUnit.Case

  alias Spell.Role.Callee
  alias Spell.Peer

  setup do
    {:ok, peer} = Crossbar.uri(Crossbar.get_config())
      |> Spell.connect(roles: [Callee], realm: Crossbar.get_realm())
    on_exit fn -> if Process.alive?(peer), do: Spell.close(peer) end
    {:ok, peer: peer}
  end

  test "cast_register/{2,3} receive_registered/2", %{peer: peer} do
    {:ok, register_id} = Spell.cast_register(peer, create_uri())
    {:ok, registration} = Spell.receive_registered(peer, register_id)
    assert is_integer(registration)
  end

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

  test "call_register", %{peer: peer} do
    {:ok, registration} = Spell.call_register(peer, create_uri())
    assert is_integer(registration)
  end

  test "stop/1", %{peer: peer} do
    :ok = Peer.stop(peer)
    refute_receive(_)
  end

  test "stop/1 with open REGISTER", %{peer: peer} do
    {:ok, _registration} = Spell.cast_register(peer, create_uri())
    :ok = Peer.stop(peer)
    assert_receive({Peer, ^peer, {:closed, :register}})
  end

  test "stop/1 with open UNREGISTER", %{peer: peer} do
    {:ok, registration} = Spell.call_register(peer, create_uri())
    {:ok, _unregister} = Spell.cast_unregister(peer, registration)
    :ok = Peer.stop(peer)
    assert_receive({Peer, ^peer, {:closed, {:unregister, ^registration}}})
  end

  # Private Functions

  defp create_uri, do: Crossbar.create_uri("com.spell.test.callee")

end
