defmodule Spell.Role.Callee do
  @moduledoc """
  The `Spell.Role.Callee` module implements the callee behaviour.
  """
  use Spell.Role

  alias Spell.Message
  alias Spell.Peer

  defstruct [register_requests:   HashDict.new(),
             unregister_requests: HashDict.new(),
             registrations:       HashDict.new()]

  # Public Functions

  @doc """
  Asynchronously send a REGISTER message from `paer` for `procedure`.

  ## Options

   * `:options :: map` Callee.Regster.options
  """
  def cast_register(peer, procedure, options \\ []) do
    {:ok, %{args: [register_id | _]} = register} =
      new_register_message(procedure, options)
    :ok = Peer.call(peer, __MODULE__, {:send, register})
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
    case Peer.call(peer, __MODULE__, {:send, message}) do
      :ok              -> {:ok, unregister_id}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Send an UNREGISTER message from `peer` for `registration` and wait to
  receive a matching UNREGISTERED response from the server.
  """
  def call_unregister(peer, registration) do
    case cast_unregister(peer, registration) do
      {:ok, unregister_id} ->
        receive_unregistered(peer, unregister_id)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Send a `YIELD` message from `peer` for `invocation`.
  """
  def cast_yield(peer, invocation, options \\ []) do
    {:ok, yield} = new_yield_message(invocation, options)
    # TODO: use `Peer.call` to validate this fn caller's pid against
    # the invocation requests
    Peer.send_message(peer, yield)
  end

  @doc """
  Receive a `REGISTERED` message from `peer` with `register_id`.
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
  Receive an `UNREGISTERED` message from `peer` with `unregister_id`.
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

  def init(_peer, []) do
    {:ok, %__MODULE__{}}
  end

  @doc """
  Handle `REGISTERED`, `UNREGISTERED`, and `INVOCATION` messages.
  """
  def handle_message(%Message{type: :registered,
                              args: [request, registration]} = message,
                     _peer, state) do
    case Dict.pop(state.register_requests, request) do
      {nil, _} ->
        {:error, {:register, :no_request}}
      {pid, register_requests} ->
        :ok = Peer.notify(pid, message)
        registrations = Dict.put_new(state.registrations, registration, pid)
        {:ok, %{state |
                register_requests: register_requests,
                registrations: registrations}}
    end
  end

  def handle_message(%Message{type: :unregistered,
                              args: [request]} = message,
                     _peer, state) do
    case Dict.pop(state.unregister_requests, request) do
      {nil, _} ->
        {:error, {:unregister, :no_request}}
      {{registration, pid}, unregister_requests} ->
        :ok = Peer.notify(pid, message)
        registrations = Dict.delete(state.registrations, registration)
        {:ok, %{state |
                unregister_requests: unregister_requests,
                registrations: registrations}}
    end
  end

  def handle_message(%Message{type: :invocation,
                              args: [_, registration | _]} = message,
                     _peer, state) do
    case Dict.get(state.registrations, registration) do
      nil ->
        {:error, :no_registration}
      pid ->
        :ok = Peer.notify(pid, message)
        {:ok, state}
    end
  end

  def handle_message(message, peer, state) do
    super(message, peer, state)
  end

  @doc """
  The `handle_call` callback is used to send `REGISTER` and `UNREGISTER`
  messages.
  """
  def handle_call({:send, %Message{type: :register,
                                   args: [request | _]} = message},
                  {pid, _}, peer, state) do
    :ok = Peer.send_message(peer, message)
    register_requests = Dict.put_new(state.register_requests, request, pid)
    {:ok, :ok, %{state | register_requests: register_requests}}
  end

  def handle_call({:send, %Message{type: :unregister,
                                   args: [request, registration]} = message},
                  {pid, _}, peer, state) do
    case Dict.get(state.registrations, registration) do
      nil ->
        {:ok, {:error, :no_registration}, state}
      ^pid ->
        :ok = Peer.send_message(peer, message)
        unregister_requests = Dict.put_new(state.unregister_requests, request,
                                            {registration, pid})
        {:ok, :ok, %{state | unregister_requests: unregister_requests}}
      other_pid when is_pid(other_pid) ->
        {:ok, {:error, :not_owner}, state}
    end
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
