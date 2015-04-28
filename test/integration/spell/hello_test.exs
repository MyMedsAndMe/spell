defmodule Spell.HelloTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Peer
  alias Spell.Message

  setup do
    {:ok, peer} = Crossbar.get_uri(Crossbar.config)
      |> Spell.connect(realm: Crossbar.realm, features: %{publisher: %{}})
    on_exit fn -> Spell.close(peer) end
    {:ok, peer: peer}
  end

  test "new/1", %{peer: peer} do
    # Not a great test...
    assert is_pid(peer)
  end


  # Pending bcause this results in the lobbing of error messages. Need to
  # turn them off or capture stdin.
  @tag pending: true
  test "send_message/2", %{peer: peer} do
    args = [Crossbar.realm, %{roles: %{publisher: %{}, subscriber: %{}}}]
    # This should kill the role
    assert :ok == Peer.send_message(peer, Message.new!(type: :hello, args: args))
    assert_receive {Peer, ^peer, {:error, _}}
    refute_receive {Peer, ^peer, %Message{type: :welcome}}

    # TODO: make a pass-through role and check if messages are delivered
  end

end
