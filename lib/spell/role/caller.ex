defmodule Spell.Role.Caller do
  @moduledoc """
  The `Spell.Role.Caller` module implements the caller behaviour.
  """
  use Spell.Role

  alias Spell.Message
  alias Spell.Peer


  @doc """
  Using `peer` asynchronously call `procedure` with `options`.

  ## Options

  See `call/3`.
  """
  @spec cast_call(pid, Message.wamp_uri, Keyword.t) :: {:ok, integer}
  def cast_call(peer, procedure, options \\ []) do
    {:ok, %{args: [call_id | _]} = register} =
      new_call_message(procedure, options)
    :ok = Peer.send_message(peer, register)
    {:ok, call_id}
  end

  @doc """
  Using `peer` synchronously call `procedure` with `options`.

  ## Options

  TODO
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

  def handle_message(%Message{type: :result} = result, peer, state) do
    :ok = Peer.send_to_owner(peer, result)
    {:ok, state}
  end

  def handle_message(message, peer, state) do
    super(message, peer, state)
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
