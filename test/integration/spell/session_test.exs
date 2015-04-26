defmodule Spell.SessionTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Peer
  alias Spell.Role.Session
  alias Spell.Message

  @realm "realm1"

  setup do: {:ok, [config: Crossbar.config]}

  test "peer with session", %{config: config} do
    # `features` are forced to fake our way through HELLO
    {:ok, peer} = Peer.new(transport: config,
                           features: %{publisher: %{}},
                           realm: @realm,
                           roles: [Session])
    assert_receive {Peer, ^peer, %{type: :welcome}}

    assert {:ok, %Message{type: :goodbye}} = Session.call_goodbye(peer)
  end
end
