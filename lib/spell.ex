defmodule Spell do
  @moduledoc """
  `Spell` is an WAMP client library and an application for managing WAMP peers.

  ## Examples

  See `Crossbar` for how to start a Crossbar.io server for interactive
  development.

  Once up, you can connect a new peer by calling:

      {:ok, peer} = Spell.connect(Crossbar.uri, realm: Crossbar.realm)

  ## Peer Interface

  The WAMP protocol defines peers which communicate by passing messages.
  Peers create and communicate over one to one bidirectional channels.

  Use `Spell.connect` to create and connect a new peer to the WAMP server.

  `Spell` delegates common client role functions to provide a single
  interface. See the `defdelegate` statements in the source or run
  `Spell.__info__(:functions)` for the full list of module functions.

  ## WAMP Support

  Spell supports the client portion of the
  [basic WAMP profile, RC4](https://github.com/tavendo/WAMP/blob/master/spec/basic.md).

  ### Client Roles:

   * Publisher: `Spell.Role.Publisher`
   * Subscriber: `Spell.Role.Subscriber`
   * Caller: `Spell.Role.Caller`
   * Callee: `Spell.Role.Callee`

  See `Spell.Role` for how to create new roles.

  ### Transports

   * WebSocket: `Spell.Transport.WebSocket`

  See `Spell.Transport` for how to create new transports.

  ### Serializers

    * JSON: `Spell.Serializer.JSON`

  See `Spell.Serizlier` for how to create new serializers.

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
               call_subscribe(peer, topic, options),
               receive_event(peer, subscription)], to: Role.Subscriber
  defdelegate [cast_call(peer, procedure),
               cast_call(peer, procedure, options),
               receive_result(peer, call_id),
               call(peer, procedure),
               call(peer, procedure, options)], to: Role.Caller
  defdelegate [cast_register(peer, procedure),
               cast_register(peer, procedure, options),
               receive_registered(peer, register_id),
               call_register(peer, procedure),
               call_register(peer, procedure, options),
               cast_yield(peer, invocation),
               cast_yield(peer, invocation, options)], to: Role.Callee

  # Module Attributes

  @supervisor_name __MODULE__.Supervisor

  @default_serializer_module Serializer.JSON
  @default_transport_module  Transport.WebSocket
  @default_retries           5
  @default_retry_interval    1000
  @default_roles             [Role.Publisher,
                              Role.Subscriber,
                              Role.Caller,
                              Role.Callee]

  # Public API

  @doc """
  Create a new peer and connect it to `uri`.

  ## Options

   * `:realm :: String.t` the peer's configured realm
   * `:roles = #{inspect(@default_roles)} :: [module | {module, any}]` the
     list of roles to start the client with. Each item can be the bare role's
     module, or the a 2-tuple of the module and init options.
   * `:retries = #{@default_retries} :: integer` number of times to
     retry connecting
   * `:retry_interval = #{@default_retry_interval} :: integer` inteveral
     in milliseconds between retries

  """
  @spec connect(String.t, Keyword.t) :: {:ok, pid}
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
  Close the peer by sending a GOODBYE message. This call is synchronous; it
  blocks until receiving the acknowledging GOODBYE.
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
    case Dict.get(options, :roles, @default_roles)
         |> Role.normalize_role_options() do
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

  defp normalize_options(_options) do
    {:error, :bad_options}
  end
end
