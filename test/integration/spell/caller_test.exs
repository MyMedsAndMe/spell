defmodule Spell.CallerTest do
  use ExUnit.Case

  alias Spell.Role.Caller
  alias Spell.Peer

  @procedure "com.spell.test.callee.procedure"

  setup do
    {:ok, peer} = Crossbar.uri(Crossbar.get_config())
      |> Spell.connect(roles: [Caller], realm: Crossbar.get_realm())
    on_exit fn -> if Process.alive?(peer), do: Spell.close(peer) end
    {:ok, peer: peer}
  end

  test "stop/1 with open CALL", %{peer: peer} do
    {:ok, _registration} = Caller.cast_call(peer, @procedure)
    :ok = Peer.stop(peer)
    assert_receive({Peer, ^peer, {:closed, :call}})
  end

end
