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
  alias Spell.Message
  alias Spell.Transport
  alias Spell.Serializer
  alias Spell.Role

  # Delegate commonly used role functions into Spell.
  defdelegate [cast_goodbye(peer),
               cast_goodbye(peer, options),
               call_goodbye(peer),
               call_goodbye(peer, options)], to: Role.Session
  defdelegate [cast_publish(peer, topic),
               cast_publish(peer, topic, options),
               call_publish(peer, topic),
               call_publish(peer, topic, options)], to: Role.Publisher
  defdelegate [cast_subscribe(peer, topic),
               cast_subscribe(peer, topic, options),
               call_subscribe(peer, topic),
               call_subscribe(peer, topic, options)], to: Role.Subscriber

  # Module Attributes

  @supervisor_name __MODULE__.Supervisor

  @default_serializer_module Serializer.JSON
  @default_transport_module  Transport.WebSocket

  @default_retries           5
  @default_retry_interval    1000

  # Public API

  @doc """
  Create a new peer and connect it to `uri`.
  """
  @spec connect(String.t) :: {:ok, pid}
  def connect(uri, options \\ [])
      when is_binary(uri) and is_list(options) do
    case parse_uri(uri) do
      {:ok, %{protocol: :ws, host: host, port: port, path: path}} ->
        transport = %{module: @default_transport_module,
                      options: [host: host, port: port, path: path]}
        case Keyword.put(options, :transport, transport) |> normalize_options() do
          {:ok, options} ->
            {:ok, peer} = Peer.add(options)
            case Role.Session.await_welcome(peer) do
              {:ok, _welcome}  -> {:ok, peer}
              {:error, reason} -> {:error, reason}
            end
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Close the peer by sending a GOODBYE message.
  """
  @spec close(pid) :: Message.t | {:error, any}
  def close(peer, options \\ []) do
    case call_goodbye(peer, options) do
      {:ok, _goodbye}   -> :ok
      {:error, reason} -> {:error, reason}
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

  # TODO: This function is a bit of a mess. Validation utils would be nice
  @spec normalize_options(Keyword.t) :: tuple
  defp normalize_options(options) when is_list(options) do
    case Dict.get(options, :roles, []) |> Role.normalize_role_options() do
      {:ok, role_options} ->
        %{transport: Keyword.get(options, :transport),
          serializer: Keyword.get(options, :serializer,
                                  @default_serializer_module),
          owner: Keyword.get(options, :owner),
          role: %{options: Keyword.put_new(role_options, Role.Session, []),
                  features: Keyword.get(options, :features,
                                        Role.collect_features(role_options))},
          realm: Keyword.get(options, :realm),
          retries: Keyword.get(options, :retries, @default_retries),
          retry_interval: Keyword.get(options, :retry_interval,
                                   @default_retry_interval)}
          |> normalize_options()
      {:error, reason} -> {:error, {:role, reason}}
    end
  end

  defp normalize_options(%{transport: nil}) do
    {:error, :transport_required}
  end

  defp normalize_options(%{transport: transport_options} = options)
      when is_list(transport_options) do
    %{options | transport: %{module: @default_transport_module,
                             options: transport_options}}
      |> normalize_options()
  end

  defp normalize_options(%{transport: transport_module} = options)
      when is_atom(transport_module) do
    %{options | transport: %{module: transport_module, options: options}}
      |> normalize_options()
  end

 defp normalize_options(%{serializer: serializer_module} = options)
      when is_atom(serializer_module) do
    %{options | serializer: %{module: serializer_module, options: []}}
      |> normalize_options()
  end

  defp normalize_options(%{realm: nil}) do
    {:error, :realm_required}
  end

  defp normalize_options(%{transport: %{module: transport_module,
                                        options: transport_options},
                           serializer: %{module: serializer_module,
                                         options: serializer_options},
                           role: %{options: role_options},
                           realm: realm} = options)
      when is_atom(transport_module) and is_list(transport_options)
       and is_atom(serializer_module) and is_list(serializer_options)
       and is_list(role_options) and is_binary(realm) do
    {:ok, options}
  end

  defp normalize_options(options) do
    {:error, :bad_options}
  end
end
