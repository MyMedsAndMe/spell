defmodule Spell.Role.Caller do
  @moduledoc """
  The `Spell.Role.Caller` module implements the caller behaviour.
  """
  use Spell.Role

  alias Spell.Message
  alias Spell.Peer

  defstruct [call_requests: HashDict.new()]

  @doc """
  Using `peer` asynchronously call `procedure` with `options`.

  ## Options

  See `call/3`.
  """
  @spec cast_call(pid, Message.wamp_uri, Keyword.t) :: {:ok, integer}
  def cast_call(peer, procedure, options \\ []) do
    {:ok, %{args: [call_id | _]} = register} =
      new_call_message(procedure, options)
    :ok = Peer.call(peer, __MODULE__, {:send, register})
    {:ok, call_id}
  end

  @doc """
  Using `peer` synchronously call `procedure` with `options`.

  ## Options

   * `:details :: map`
   * `:arguments :: list`
   * `:arguments_kw :: map`
  """
  @spec call(pid, Message.wamp_uri, Keyword.t) :: {:ok, integer}
  def call(peer, procedure, options \\ []) do
    {:ok, call_id} = cast_call(peer, procedure, options)
    receive_result(peer, call_id)
  end

  @doc """
  Block to receive from `peer` result of `call_id`.
  """
  def receive_result(peer, call_id) do
    receive do
      {Peer, ^peer,
       %Message{type: :result, args: [^call_id | _]} = result} ->
        {:ok, result}
    after
      1000 -> {:error, :timeout}
    end
  end

  # Role Callbacks

  def get_features(_options), do: {:caller, %{}}

  def init(_peer, _options) do
    {:ok, %__MODULE__{}}
  end

  @doc """
  Handle `RESULT` messages.
  """
  def handle_message(%Message{type: :result,
                              args: [request | _]} = result,
                     peer, state) do
    case Dict.pop(state.call_requests, request) do
      {nil, _} ->
        {:error, :no_call}
      {pid, call_requests} ->
        :ok = Peer.notify(pid, result)
        {:ok, %{state | call_requests: call_requests}}
    end
  end

  def handle_message(message, peer, state) do
    super(message, peer, state)
  end

  @doc """
  The `handle_call` callback is used to send `CALL` messages.
  """
  def handle_call({:send, %Message{type: :call,
                                   args: [request | _]} = message},
                  {pid, _}, peer, state) do
    :ok = Peer.send_message(peer, message)
    call_requests = Dict.put_new(state.call_requests, request, pid)
    {:ok, :ok, %{state | call_requests: call_requests}}
  end

  # Private Functions

  defp new_call_message(procedure, options) do
    Message.new(type: :call,
                args: [Message.new_id(),
                       Keyword.get(options, :options, %{}),
                       procedure,
                       Keyword.get(options, :arguments, []),
                       Keyword.get(options, :arguments_kw, %{})])
  end

end
