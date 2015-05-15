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
    signature = get_response(Dict.fetch!(options, :secret), details)
    {:ok, signature, %{}}
  end

  # Private Functions

  @spec get_response(String.t, Dict.t) :: String.t
  defp get_response(secret, %{"challenge"  => challenge,
                              "salt"       => salt,
                              "iterations" => iterations,
                              "keylen"     => key_length}) do
    pbkdf2(secret, salt, iterations, key_length) |> hash_challenge(challenge)
  end

  defp get_response(secret, %{"challenge" => challenge}) do
    hash_challenge(secret, challenge)
  end

  @spec hash_challenge(String.t, String.t) :: String.t
  defp hash_challenge(secret, challenge) do
    :crypto.hmac(:sha256, secret, challenge)
      |> :base64.encode()
  end

  @spec pbkdf2(String.t, String.t, non_neg_integer, non_neg_integer) ::
    String.t
  defp pbkdf2(secret, salt, iterations, key_length) do
    {:ok, derived} = :pbkdf2.pbkdf2(:sha256, secret, salt,
                                    iterations, key_length)
    :base64.encode(derived)
  end

end
