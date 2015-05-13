defmodule Spell.Authentication.CRA do
  @moduledoc """
  The `Spell.Authentication.CRA` module implements WAMP challenge reponse
  authentication. The interface conforms to `Spell.Authentication`.

  ## Options

  See `Spell.connect` for how to set the options.

   * `:secret :: String.t` requred. The secret key shared between client and
     server, It is used to encode the challenge.

  """
  @behaviour Spell.Authentication

  # Authentication Callbacks

  def name, do: "wampcra"

  def response(details, options) do
    signature = hash_challenge(Dict.fetch!(options, :secret),
                               Dict.fetch!(details, "challenge"))
    {:ok, signature, %{}}
  end

  # Private Functions

  @spec hash_challenge(String.t, String.t) :: String.t
  defp hash_challenge(key, challenge) do
    :crypto.hmac(:sha256, key, challenge)
      |> :base64.encode()
  end

end
