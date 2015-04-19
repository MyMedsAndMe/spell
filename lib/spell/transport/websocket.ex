defmodule Spell.Transport.WebSocket do
  @moduledoc """
  The `Spell.Transport.WebSocket` module implements a webosocket transport.

  By default the websocket will use port `443`. Use `new/2` to set the
  port when creating a new websocket transport.
  """
  @behaviour Spell.Transport
  require Logger

  # Module Attributes

  defstruct [:pid, :owner, :host, port: 443]

  @options_spec [:host, {:port, default: 80}, {:path, default: ""}]

  # Type Declarations

  @type t :: %__MODULE__{
    pid:     pid,
    owner:   pid,
    host:    :inet.hostname,
    port:    :inet.port}

  @type options :: [
      {:host, String.t}
    | {:port, :inet.port}
    | {:path, String.t}]


  # Public Functions


  # Spell.Transport Callbacks

  @doc """
  Negotiate a WebSocket connection.

  ## Options

   * `:host` required, the target host.
   * `:port` required, the target port.
   * `:path` defaults to "", HTTP resource path. It must be
     prefixed with a `/`.
  """
  @spec connect(module, options) :: {:ok, t} | {:error, any}
  def connect(serializer, options) when is_list(options) do
    case get_all(options, @options_spec) do
      {:ok, [host, port, path]}
          when is_binary(host) and is_integer(port) and is_binary(path) ->
        url = "ws://#{host}:#{port}#{path}"
        extra_headers = get_extra_headers(serializer.name())
        Logger.debug(fn -> "Connecting to #{url}..." end)
        case :websocket_client.start_link(url, __MODULE__,
                                          {self(), serializer},
                                          extra_headers: extra_headers) do
          {:ok, pid} ->
            Logger.debug(fn -> "Successfully connected to #{url}." end)
            {:ok, %__MODULE__{pid: pid, owner: nil, host: host, port: port}}
          {:error, reason} ->
            Logger.debug(fn -> "Error [#{url}]: #{inspect(reason)}" end)
            {:error, reason}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  def send_message(%__MODULE__{} = transport, raw_message) do
    send(transport.pid, {:send, raw_message})
    :ok
  end


  # :websocket_client Callbacks

  def init({owner, serializer}, _conn_state) do
    {:ok, %{owner: owner, serializer: serializer}}
  end

  def websocket_handle({:text, raw_message}, _conn_state, state) do
    case state.serializer.decode(raw_message) do
      {:ok, message} ->
        :ok = send_to_owner(state.owner, message)
        {:ok, state}
    end
  end

  def websocket_info({:send, raw_message}, _conn_state, state) do
    Logger.debug(fn -> "Sending message over websocket: #{raw_message}" end)
    {:reply, {:text, raw_message}, state}
  end

  def websocket_terminate(reason, _conn_state, state) do
    Logger.debug(fn -> "Connection terminating due to #{inspect(reason)}" end)
    send_to_owner(state.owner, reason)
  end

  # Private Functions

  @spec send_to_owner(pid, any) :: :ok
  defp send_to_owner(owner, message) do
    send(owner, {Spell, self(), message})
    :ok
  end

  @spec get_extra_headers(String.t) :: [{String.t, String.t}]
  defp get_extra_headers(serializer) do
    [{"Sec-WebSocket-Protocol", "wamp.2.json"}]
  end

  @spec get_all(Dict.t(key, value), [key], [value], [value]) ::
    {:ok, [value]} | {:error, {:missing, [key]}} when key: var, value: var
  defp get_all(dict, keys, values \\ [], missing \\ [])
  defp get_all(_, [], values, []), do: {:ok, Enum.reverse(values)}
  defp get_all(_, [], _, missing), do: {:error, {:missing, missing}}
  defp get_all(dict, [{key, opts} | keys], values, missing) do
    case Dict.fetch(dict, key) do
      {:ok, value} -> get_all(dict, keys, [value | values], missing)
      :error ->
        case Keyword.fetch(opts, :default) do
          {:ok, value} -> get_all(dict, keys, [value | values], missing)
          :error       -> get_all(dict, keys, values, [key | missing])
        end
    end
  end
  defp get_all(dict, [key | keys], values, missing) do
    get_all(dict, [{key, []} | keys], values, missing)
  end

end
