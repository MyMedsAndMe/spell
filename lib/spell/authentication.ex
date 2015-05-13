defmodule Spell.Authentication do
  @moduledoc """
  The `Spell.Authentication` module specifies the behaviour of WAMP
  authentication schemes.
  """
  use Behaviour

  # Callback Definitions

  @doc """
  Get the `name` of the authorization scheme as a string.
  """
  defcallback name() :: String.t

  @doc """
  Attempt to authenticate the given `options`.

  This is called in response to `CHALLENGE`.
  """
  defcallback response(details :: map, options :: Keyword.t) ::
    {:ok, signature :: String.t, extra :: map} | {:error, any}

  # Public Interface

  @doc """
  Helper for getting the WAMP HELLO auth details from Spell peer
  `authentication` options.
  """
  @spec get_details(Dict.t) :: Dict.t
  def get_details(authentication) do
    case {authentication[:id], authentication[:schemes]} do
      {id, schemes} when id == nil or schemes == nil ->
        %{}
      {id, schemes} ->
        names = for {scheme, _} <- schemes, do: scheme.name()
        %{authid: id, authmethods: names}
    end
  end

  @doc """
  Create a lookup from authentication scheme name to module.
  """
  @spec schemes_to_lookup(Keyword.t | nil) :: Dict.t
  def schemes_to_lookup(nil), do: HashDict.new()
  def schemes_to_lookup(schemes) do
    for {scheme, _} <- schemes, into: HashDict.new() do
      {scheme.name(), scheme}
    end
  end
end
