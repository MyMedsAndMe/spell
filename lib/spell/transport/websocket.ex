defmodule Spell.Transport.WebSocket do
  @moduledoc """
  The `Spell.Transport.WebSocket` module implements a webosocket transport.

  By default the websocket will use port `443`. Use `new/2` to set the
  port when creating a new websocket transport.
  """
  @behaviour Spell.Transport
  require Logger

  # Module Attributes

  @options_spec [:host, {:port, default: 80}, {:path, default: ""}]

  # Type Declarations

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
  @spec connect(String.t, options) :: {:ok, pid} | {:error, any}
  def connect(serializer, options) when is_list(options) do
    case get_all(options, @options_spec) do
      {:ok, [host, port, path]}
          when is_binary(host) and is_integer(port) and is_binary(path) ->
        url = "ws://#{host}:#{port}#{path}"
        extra_headers = get_extra_headers(serializer)
        Logger.debug(fn -> "Connecting to #{url}..." end)
        :websocket_client.start_link(url, __MODULE__, {self()},
                                     extra_headers: extra_headers)
          # {:ok, pid} ->
          #   Logger.debug(fn -> "Successfully connected to #{url}." end)
          #   {:ok, %__MODULE__{pid: pid, owner: nil, host: host, port: port}}
          # {:error, reason} ->
          #   Logger.debug(fn -> "Error [#{url}]: #{inspect(reason)}" end)
          #   {:error, reason}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def send_message(transport, raw_message) do
    send(transport, {:send, raw_message})
    :ok
  end


  # :websocket_client Callbacks

  def init({owner}, _conn_state) do
    {:ok, %{owner: owner}}
  end

  def websocket_handle({:text, raw_message}, _conn_state, state) do
    :ok = send_to_owner(state.owner, {:message, raw_message})
    {:ok, state}
  end

  def websocket_info({:send, raw_message}, _conn_state, state) do
    Logger.debug(fn -> "Sending message over websocket: #{raw_message}" end)
    {:reply, {:text, raw_message}, state}
  end

  def websocket_terminate(reason, _conn_state, state) do
    Logger.debug(fn -> "Connection terminating due to #{inspect(reason)}" end)
    :ok = send_to_owner(state.owner, {:terminating, reason})
    {:ok, state}
  end

  # Private Functions

  @spec send_to_owner(pid, any) :: :ok
  defp send_to_owner(owner, message) do
    send(owner, {__MODULE__, self(), message})
    :ok
  end

  @spec get_extra_headers(String.t) :: [{String.t, String.t}]
  defp get_extra_headers(serializer) do
    [{"Sec-WebSocket-Protocol", "wamp.2.#{serializer}"}]
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
