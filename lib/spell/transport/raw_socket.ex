defmodule Spell.Transport.RawSocket do
  @moduledoc """
  The `Spell.Transport.RawSocket` module implements a raw socket transport.
  """
  @behaviour Spell.Transport
  require Logger

  # Module Attributes

  @options_spec [:host, {:port, default: 80}]

  # Type Declarations

  @type options :: [
      {:host, String.t}
    | {:port, :inet.port}]


  # Spell.Transport Callbacks

  @doc """
  Negotiate a RawSocket connection.

  ## Options

   * `:host` required, the target host.
   * `:port` required, the target port.
  """
  @spec connect(module, options) :: {:ok, pid} | {:error, any}
  def connect(serializer, options) when is_list(options) do
    case get_all(options, @options_spec) do
      {:ok, [host, port]} when is_binary(host) and is_integer(port) ->
        serializer_info = serializer.transport_info(__MODULE__)
        timeout = Keyword.get(options, :timeout, 6000)

        :proc_lib.start_link(__MODULE__, :init, [{host, port, self(), serializer_info, timeout}])
      {:error, reason} ->
        {:error, reason}
    end
  end

  def send_message(transport, raw_message) do
    send(transport, {:send, raw_message})
    :ok
  end

  # GenServer Callbacks

  def init({host, port, owner, serializer_info, timeout}) do
    Logger.debug(fn -> "Connecting to #{host}:#{port}..." end)
    case :gen_tcp.connect(String.to_char_list(host), port, [:binary, active: false], timeout) do
      {:ok, socket} ->
        {:ok, _m} = handshake(socket, serializer_info)
        :inet.setopts(socket, active: true)
        :proc_lib.init_ack({:ok, self})
        :gen_server.enter_loop(__MODULE__, [], %{socket: socket, owner: owner, serializer_info: serializer_info})
      {:error, reason} ->
        :proc_lib.init_ack({:error, reason})
    end
  end

  def handle_info({:tcp, socket, raw_message}, %{socket: socket} = state) do
    Logger.debug(fn -> "Received message over socket: #{inspect(raw_message)}" end)
    :ok = handle_messages(to_string(raw_message), state)
    {:noreply, state}
  end


  def handle_info({:send, raw_message}, %{socket: socket} = state) do
    Logger.debug(fn -> "Sending message over socket: #{inspect(raw_message)}" end)
    frame = <<0::5,0::3,byte_size(raw_message)::24>>
    :gen_tcp.send(socket, frame <> raw_message)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    Logger.debug(fn -> "Socket connection terminating" end)
    :ok = send_to_owner(state.owner, {:terminating, socket})
    {:noreply, state}
  end

  # Private Functions

  defp handshake(socket, %{serializer_id: serializer_id}) do
    :gen_tcp.send(socket, <<127,15::4,serializer_id::4,0,0>>)
    case :gen_tcp.recv(socket, 0) do
      {:ok, m} -> {:ok, m}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_messages(<<>>, _state), do: :ok
  defp handle_messages(raw_message, state) do
    <<_res::5,_type::3,length::24,message::binary-size(length)>> <> remaining_messages = raw_message
    :ok = send_to_owner(state.owner, {:message, message})
    handle_messages(remaining_messages, state)
  end

  @spec send_to_owner(pid, any) :: :ok
  defp send_to_owner(owner, message) do
    send(owner, {__MODULE__, self(), message})
    :ok
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
