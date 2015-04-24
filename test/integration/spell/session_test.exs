defmodule Spell.SessionTest do
  use ExUnit.Case

  alias TestHelper.Crossbar
  alias Spell.Peer
  alias Spell.Role.Session

  @realm "realm1"

  setup do: {:ok, [config: Crossbar.config]}

  test "peer with session", %{config: config} do
    {:ok, peer} = Peer.new(transport: config,
                           features: %{publisher: %{}},
                           roles: [{Session, [realm: @realm]}])
    assert_receive {Peer, ^peer, %{type: :welcome}}
  end
end
