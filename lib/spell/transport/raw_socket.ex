defmodule Spell.Transport.RawSocket do
  @moduledoc """
  The `Spell.Transport.RawSocket` module implements a raw socket transport.
  """
  @behaviour Spell.Transport
  require Logger

  defstruct [:socket, :owner, :serializer_id, :max_length, :router_max_length]

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
        timeout = Keyword.get(options, :timeout, 6000)
        max_length = Keyword.get(options, :max_length, 15)
        %{serializer_id: serializer_id} = serializer.transport_info(__MODULE__)

        state = %__MODULE__{owner: self, serializer_id: serializer_id, max_length: max_length}
        :proc_lib.start_link(__MODULE__, :init, [{host, port, timeout}, state])
      {:error, reason} ->
        {:error, reason}
    end
  end

  def send_message(transport, raw_message) do
    send(transport, {:send, raw_message})
    :ok
  end

  # GenServer Callbacks

  def init({host, port, timeout}, state) do
    Logger.debug(fn -> "Connecting to #{host}:#{port}..." end)
    case :gen_tcp.connect(String.to_char_list(host), port, [:binary, active: false], timeout) do
      {:ok, socket}    -> handshake(%{state | socket: socket})
      {:error, reason} -> :proc_lib.init_ack({:error, reason})
    end
  end

  def handle_info({:tcp, socket, raw_message}, %__MODULE__{socket: socket} = state) do
    Logger.debug(fn -> "Received message over socket: #{inspect(raw_message)}" end)
    :ok = handle_messages(to_string(raw_message), state)
    {:noreply, state}
  end

  def handle_info({:send, raw_message}, %__MODULE__{socket: socket} = state) do
    Logger.debug(fn -> "Sending message over socket: #{inspect(raw_message)}" end)
    frame = <<0::5,0::3,byte_size(raw_message)::24>>
    :gen_tcp.send(socket, frame <> raw_message)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    Logger.debug(fn -> "Socket connection terminating" end)
    :ok = send_to_owner(state.owner, {:terminating, socket})
    {:noreply, state}
  end

  # Private Functions

  defp handshake(%__MODULE__{socket: socket, serializer_id: serializer_id, max_length: max_length} = state) do
    :gen_tcp.send(socket, <<127,max_length::4,serializer_id::4,0,0>>)
    :gen_tcp.recv(socket, 0)
    |> process_handshake_response(state)
  end

  defp process_handshake_response({:ok, <<127,max_length::4,ser_id::4,0,0>>}, %__MODULE__{serializer_id: ser_id} = state) do
    :inet.setopts(state.socket, active: true)
    :proc_lib.init_ack({:ok, self})
    :gen_server.enter_loop(__MODULE__, [], %{state | router_max_length: max_length})
  end

  defp process_handshake_response({:ok, <<127,error_code::4,0::4,0,0>>}, _state) do
    :proc_lib.init_ack({:error, error_code})
  end

  defp process_handshake_response({:error, reason}, _state) do
    :proc_lib.init_ack({:error, reason})
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
