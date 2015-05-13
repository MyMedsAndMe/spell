defmodule Spell.AuthenticationTest do
  use ExUnit.Case

  alias Spell.Authentication.CRA

  @auth_id "alice"
  @secret  "alice-secret"
  @authentication [id: @auth_id, schemes: [{CRA, [secret: @secret]}]]

  @tag :integration
  test "wampcra" do
    {:ok, peer} = Spell.connect(Crossbar.uri_auth(),
                                realm: Crossbar.get_realm(),
                                authentication: @authentication)
    assert :ok == Spell.close(peer)
  end

end
