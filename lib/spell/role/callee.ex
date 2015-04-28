defmodule Spell.Role.Callee do
  @moduledoc """
  The `Spell.Role.Callee` module implements the callee behaviour.
  """
  use Spell.Role

  alias Spell.Message
  alias Spell.Peer

  # Public Functions

  def cast_register(peer, procedure, options \\ []) do
    {:ok, %{args: [register_id | _]} = register} =
      new_register_message(procedure, options)
    :ok = Peer.send_message(peer, register)
    {:ok, register_id}
  end

  def call_register(peer, procedure, options \\ []) do
    {:ok, register_id} = cast_register(peer, procedure, options)
    receive_registered(peer, register_id)
  end

  def receive_registered(peer, register_id) do
    receive do
      {Peer, ^peer,
       %Message{type: :registered, args: [^register_id, registration]}} ->
        {:ok, registration}
    after
      1000 -> {:error, :timeout}
    end
  end

  def cast_yield(peer, invocation, options \\ []) do
    {:ok, yield} = new_yield_message(invocation, options)
    Peer.send_message(peer, yield)
  end

  # Role Callbacks

  def get_features(_options), do: {:callee, %{}}

  def handle_message(%Message{type: :registered} = registered, peer, state) do
    :ok = Peer.send_to_owner(peer, registered)
    {:ok, state}
  end

  def handle_message(%Message{type: :invocation} = invocation, peer, state) do
    :ok = Peer.send_to_owner(peer, invocation)
    {:ok, state}
  end

  def handle_message(message, peer, state) do
    super(message, peer, state)
  end

  # Private Functions

  defp new_register_message(procedure, options) do
    Message.new(type: :register,
                args: [Message.new_id(),
                       Keyword.get(options, :options, %{}),
                       procedure])
  end

  defp new_yield_message(invocation, options) do
    Message.new(type: :yield,
                args: [invocation,
                       Keyword.get(options, :options, %{}),
                       Keyword.get(options, :arguments, []),
                       Keyword.get(options, :arguments_kw, %{})])
  end

end
