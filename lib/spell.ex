defmodule Spell do
  @moduledoc """
  The `Spell` application is a basic WAMP client.

  Spell is

   * Easily extensible
   * Happy to manage many peers

  ## WAMP Support

  Spell supports the
  [basic WAMP profile, RC4](https://github.com/tavendo/WAMP/blob/master/spec/basic.md).

  TODO -- explain what this entails

  Client Roles:

   - Publisher
   - Subscriber
   - Caller
   - Callee

  ## Examples

  TODO

  """
  use Application

  alias Spell.Peer
  alias Spell.Transport
  alias Spell.Serializer
  alias Spell.Role

  # Module Attributes

  @supervisor_name __MODULE__.Supervisor

  # Public API

  @doc """
  Connect to `uri`.
  """
  @spec new_peer(String.t) :: {:ok, pid}
  def new_peer(uri, options \\ [])
      when is_binary(uri) and is_list(options) do
    case parse_uri(uri) do
      {:ok, %{protocol: :ws, host: host, port: port, path: path}} ->
        Peer.add(transport: {Transport.WebSocket,
                             host: host, port: port, path: path},
                 serializer: Serializer.JSON,
                 roles: [{Role.Session, [realm: "realm1"]},
                         Role.Publisher,
                         Role.Subscriber])
    end
    end


  # Application Callbacks

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [supervisor(Spell.Peer, [])]
    options  = [strategy: :one_for_one, name: @supervisor_name]
    Supervisor.start_link(children, options)
  end

  # Private Functions

  @spec parse_uri(String.t | char_list) :: {:ok, Map.t} | {:error, any}
  defp parse_uri(string) when is_binary(string) do
    string |> to_char_list() |> parse_uri()
  end
  defp parse_uri(chars) when is_list(chars) do
    case :http_uri.parse(chars, [scheme_defaults: [ws: 80, wss: 443]]) do
      {:ok, {protocol, [], host, port, path, []}} ->
        {:ok, %{protocol: protocol,
                host: to_string(host),
                port: port,
                path: to_string(path)}}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
