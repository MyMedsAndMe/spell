defmodule Spell.Transport.RawSocket do
  @moduledoc """
  The `Spell.Transport.RawSocket` module implements a raw socket transport.
  https://github.com/tavendo/WAMP/blob/master/spec/advanced.md#rawsocket-transport
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
    :gen_tcp.send(socket, frame_message(raw_message))
    {:noreply, state}
  end

  def handle_info({:ping, raw_message}, %__MODULE__{socket: socket} = state) do
    Logger.debug(fn -> "Sending pong over socket: #{inspect(raw_message)}" end)
    :gen_tcp.send(socket, frame_message(raw_message, :pong))
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    Logger.debug(fn -> "Socket connection terminating" end)
    :ok = send_to_owner(state.owner, {:terminating, {:remote, :closed}})
    {:stop, {:remote, :closed}, state}
  end

  # Private Functions

  defp handshake(%__MODULE__{socket: socket, serializer_id: serializer_id, max_length: max_length} = state) do
    :gen_tcp.send(socket, handshake_frame(max_length, serializer_id))
    :gen_tcp.recv(socket, 0)
    |> process_handshake_response(state)
  end

  # WAMP handshake frame format: 0111 1111 LLLL SSSS RRRR RRRR RRRR RRRR
  # LLLL = value is used by the Client to signal the maximum message length of messages it is willing to receive.
    # 0: 2**9 octets
    # 1: 2**10 octets
    # ...
    # 15: 2**24 octets
  # SSSS = used by the Client to request a specific serializer to be used
    # 0: illegal
    # 1: JSON
    # 2: MsgPack
    # 3 - 15: reserved for future serializers
  # RRRR RRRR RRRR RRRR = reserved and MUST be all zeros for now
  defp handshake_frame(max_length, serializer_id) do
    <<127,max_length::4,serializer_id::4,0,0>>
  end

  # WAMP successful handshake response format: 0111 1111 LLLL SSSS RRRR RRRR RRRR RRRR
  # LLLL = limit on the length of messages sent by the Client
  # SSSS = echo the serializer value requested by the Client
  # RRRR RRRR RRRR RRRR = reserved and MUST be all zeros for now
  defp process_handshake_response({:ok, <<127,max_length::4,ser_id::4,0,0>>}, %__MODULE__{serializer_id: ser_id} = state) do
    :inet.setopts(state.socket, active: true)
    :proc_lib.init_ack({:ok, self})
    :gen_server.enter_loop(__MODULE__, [], %{state | router_max_length: max_length})
  end

  # WAMP error handshake response format: 0111 1111 EEEE 0000 RRRR RRRR RRRR RRRR
  # EEEE = encode the error:
    # 0: illegal (must not be used)
    # 1: serializer unsupported
    # 2: maximum message length unacceptable
    # 3: use of reserved bits (unsupported feature)
    # 4: maximum connection count reached
    # 5 - 15: reserved for future errors
  # RRRR RRRR RRRR RRRR = reserved and MUST be all zeros for now
  # TODO: return error explanation instead of code
  defp process_handshake_response({:ok, <<127,error_code::4,0::4,0,0>>}, _state) do
    :proc_lib.init_ack({:error, error_code})
  end

  defp process_handshake_response({:error, reason}, _state) do
    :proc_lib.init_ack({:error, reason})
  end

  defp handle_messages(<<>>, _state), do: :ok
  defp handle_messages(raw_message, state) do
    {message, type, remaining_messages} = extract_message(raw_message)
    respond_to(message, type, state)
    handle_messages(remaining_messages, state)
  end

  defp respond_to(message, :wamp, state) do
    :ok = send_to_owner(state.owner, {:message, message})
  end
  defp respond_to(message, :ping, _state) do
    send(self, {:ping, message})
  end

  # WAMP message frame format: RRRR RTTT LLLL LLLL LLLL LLLL LLLL LLLL
  # RRRR R = reserved and MUST be all zeros for now
  # TTT = encode the type of the transport message
    # 0: regular WAMP message
    # 1: PING
    # 2: PONG
    # 3-7: reserved
  # LLLL LLLL LLLL LLLL LLLL LLLL = length of the serialized WAMP message
  defp extract_message(<<_res::5,type_id::3,length::24,message::binary-size(length)>> <> remaining_messages) do
    {message, message_type(type_id), remaining_messages}
  end

  defp frame_message(raw_message, type \\ :wamp) do
    <<0::5,message_type_id(type)::3,byte_size(raw_message)::24>> <> raw_message
  end

  defp message_type(0), do: :wamp
  defp message_type(1), do: :ping
  defp message_type(2), do: :pong
  defp message_type_id(:wamp), do: 0
  defp message_type_id(:ping), do: 1
  defp message_type_id(:pong), do: 2

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
