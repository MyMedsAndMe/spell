defmodule Spell.Transport.WebSocket do
  @moduledoc """
  The `Spell.Transport.WebSocket` module implements a webosocket transport.

  By default the websocket will use port `443`. Use `new/2` to set the
  port when creating a new websocket transport.
  """

  # Module Attributes

  defstruct [:monitor, :pid, :host, port: 443]

  # Type Declarations

  @type t :: %__MODULE__{
    pid:     pid,
    monitor: Process.ref,
    host:    :inet.hostname,
    port:    :inet.port}

  @type opts :: [
      {:host, String.t}
    | {:port, :inet.port}
    | {:gun_opts, :gun.opts}]


  # Public Functions

  @doc """
  Create a new websocket transport.

  ## Options

   * `:host` required, the target host.
   * `:port` required, the target port.
   * `:gun_opts` optional, options to be passed to `gun:open/3`
  """
  @spec new(opts) :: {:ok, t} | {:error, term}
  def new(opts) when is_list(opts) do
    case get_all(opts, [:host, :port, {:gun_opts, default: []}]) do
      {:ok, [host_bin, port, gun_opts]}
          when is_binary(host_bin) and is_integer(port) ->
        # `:inet.hostname` is a charlist. O Erlang compat
        host = String.to_char_list(host_bin)
        case :gun.open(host, port, gun_opts) do
          {:ok, pid} ->
            {:ok, %__MODULE__{pid: pid, host: host, port: port,
                              monitor: Process.monitor(pid)}}
          {:error, reason} ->
            {:error, reason}
        end
      {:error, reason} ->
        {:error, reason}
    end
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
