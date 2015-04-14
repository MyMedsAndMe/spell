defmodule Spell.Transport.WebSocket do
  @moduledoc """
  The `Spell.Transport.WebSocket` module implements a webosocket transport.

  By default the websocket will use port `443`. Use `new/2` to set the
  port when creating a new websocket transport.
  """
  require Logger

  # Module Attributes

  defstruct [:monitor, :pid, :host, port: 443]

  @options_spec [:host, {:port, default: 80}, {:path, default: ""}]

  # Type Declarations

  @type t :: %__MODULE__{
    pid:     pid,
    monitor: Process.ref,
    host:    :inet.hostname,
    port:    :inet.port}

  @type options :: [
      {:host, String.t}
    | {:port, :inet.port}
    | {:path, String.t}]


  # Public Functions

  @doc """
  Create a new websocket transport.

  ## Options

   * `:host` required, the target host.
   * `:port` required, the target port.
   * `:path` defaults to "", HTTP resource path. It must be
     prefixed with a `/`.
  """
  @spec new(options) :: {:ok, t} | {:error, term}
  def new(options) when is_list(options) do
    case get_all(options, @options_spec) do
      {:ok, [host, port, path]}
          when is_binary(host) and is_integer(port) and is_binary(path) ->
        url = "ws://#{host}:#{port}#{path}"
        headers = [{"Sec-WebSocket-Protocol", "wamp.2.json"}]
        Logger.debug(fn -> "Connecting to #{url}..." end)
        case :websocket_client.start_link(url, __MODULE__, [],
                                          extra_headers: headers) do
          {:ok, pid} ->
            Logger.debug(fn -> "Successfully connected to #{url}." end)
            {:ok, %__MODULE__{pid: pid, host: host, port: port,
                              monitor: Process.monitor(pid)}}
          {:error, reason} ->
            Logger.debug(fn -> "Error [#{url}]: #{inspect(reason)}" end)
            {:error, reason}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  # `websocket_client` Callbacks

  def init([], _conn_state) do
    {:ok, nil}
  end

  def websocket_handle(msg, _conn_state, state) do
    IO.inspect msg
    {:ok, state}
  end

  def websocket_info(info, _conn_state, state) do
    IO.inspect info
    {:ok, state}
  end

  def websocket_terminate(reason, _conn_state, _state) do
    Logger.debug(fn -> "Connection terminating due to #{inspect(reason)}" end)
    :ok
  end

  # Private Functions

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


defimpl Spell.Transportable, for: Spell.Transport.WebSocket do
  alias Spell.Transport.WebSocket

  def connect(transport, opts, owner) do
    :ok
  end
end
