defmodule Spell.Role.Callee do
  @moduledoc """
  The `Spell.Role.Callee` module implements the callee behaviour.
  """
  use Spell.Role

  alias Spell.Message
  alias Spell.Peer

  # Public Functions

  @doc """
  Asynchronously send a REGISTER message from `paer` for `procedure`.

  ## Options

   * `:options :: map` Callee.Regster.options
  """
  def cast_register(peer, procedure, options \\ []) do
    {:ok, %{args: [register_id | _]} = register} =
      new_register_message(procedure, options)
    :ok = Peer.send_message(peer, register)
    {:ok, register_id}
  end

  @doc """
  Send a REGISTER message from `peer` for `procedure` and
  wait for a REGISTERED response.

  ## Options

  See `cast_register/3`
  """
  def call_register(peer, procedure, options \\ []) do
    {:ok, register_id} = cast_register(peer, procedure, options)
    receive_registered(peer, register_id)
  end

  @doc """
  Send an UNREGISTER message from `peer` for `registration`.
  """
  def cast_unregister(peer, registration) do
    {:ok, %{args: [unregister_id | _]} = message} =
      new_unregister_message(registration)
    :ok = Peer.send_message(peer, message)
    {:ok, unregister_id}
  end

  @doc """
  Send an UNREGISTER message from `peer` for `registration` and wait to
  receive a matching UNREGISTERED response from the server.
  """
  def call_unregister(peer, registration) do
    {:ok, unregister_id} = cast_unregister(peer, registration)
    receive_unregistered(peer, unregister_id)
  end

  @doc """
  Send a YIELD message from `peer` for `invocation`.
  """
  def cast_yield(peer, invocation, options \\ []) do
    {:ok, yield} = new_yield_message(invocation, options)
    Peer.send_message(peer, yield)
  end

  @doc """
  Receive a REGISTERED message from `peer` with `register_id`.
  """
  def receive_registered(peer, register_id) do
    receive do
      {Peer, ^peer,
       %Message{type: :registered, args: [^register_id, registration]}} ->
        {:ok, registration}
    after
      1000 -> {:error, :timeout}
    end
  end

  @doc """
  Receive an UNREGISTERED message from `peer` with `unregister_id`.
  """
  def receive_unregistered(peer, unregister_id) do
    receive do
      {Peer, ^peer,
       %Message{type: :unregistered, args: [^unregister_id]}} ->
        :ok
    after
      1000 -> {:error, :timeout}
    end
  end

  @spec receive_invocation(pid, Message.wamp_id) ::
    {:ok, map} | {:error, any}
  def receive_invocation(peer, invocation) do
    receive do
      {Peer, ^peer,
       # TODO: handle arguments
       %Message{type: :invocation,
                 args: [^invocation, registration, details]}} ->
        {:ok, %{id: invocation, registration: registration,
                details: details}}
    after
      1000 -> {:error, :timeout}
    end
  end

  # Role Callbacks

  def get_features(_options), do: {:callee, %{}}

  def handle_message(%Message{type: type} = message, peer, state)
      when type == :registered or type == :unregistered or type == :invocation do
    :ok = Peer.send_to_owner(peer, message)
    {:ok, state}
  end

  def handle_message(message, peer, state) do
    super(message, peer, state)
  end

  # Private Functions

  @spec new_register_message(Message.wamp_id, Keyword.t) ::
    {:ok, Message.t} | {:error, any}
  defp new_register_message(procedure, options) do
    Message.new(type: :register,
                args: [Message.new_id(),
                       Keyword.get(options, :options, %{}),
                       procedure])
  end

  @spec new_yield_message(Message.wamp_id, Keyword.t) ::
    {:ok, Message.t} | {:error, any}
  defp new_yield_message(invocation, options) do
    Message.new(type: :yield,
                args: [invocation,
                       Keyword.get(options, :options, %{}),
                       Keyword.get(options, :arguments, []),
                       Keyword.get(options, :arguments_kw, %{})])
  end

  @spec new_unregister_message(Message.wamp_id) ::
    {:ok, Message.t} | {:error, any}
  defp new_unregister_message(registration) do
    Message.new(type: :unregister,
                args: [Message.new_id(), registration])
  end
end
