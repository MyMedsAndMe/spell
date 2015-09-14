defmodule Spell.Role.Subscriber do
  @moduledoc """
  The `Spell.Role.Subscriber` module implements the behaviour
  of the subscriber role.
  """
  use Spell.Role

  require Logger
  import Spell.Message, only: [receive_message: 3]

  alias Spell.Peer
  alias Spell.Message

  defstruct [subscribe_requests: HashDict.new(),
             unsubscribe_requests: HashDict.new(),
             subscriptions: HashDict.new()]

  @default_timeout 1000

  # Public Interface

  @doc """
  Subscribe `peer` to messages from `topic`.
  """
  @spec cast_subscribe(pid, Message.wamp_uri, Keyword.t) ::
    {:ok, Message.wamp_id}
  def cast_subscribe(peer, topic, options \\ [])
      when is_pid(peer) and is_binary(topic) and is_list(options) do
    # TODO: `defmessage` to avoid this leaky abstraction
    {:ok, %{args: [subscribe_id | _]} = message} =
      new_subscribe_message(topic, options)
    :ok = Peer.call(peer, __MODULE__, {:send, message})
    {:ok, subscribe_id}
  end

  @doc """
  Send a subscribe message from `peer` for `topic` and block until a response is
  received or timeout.
  """
  @spec call_subscribe(pid, Message.wamp_uri, Keyword.t) ::
    {:ok, Message.wamp_id} | {:error, :timeout}
  def call_subscribe(peer, topic, options \\ []) do
    {:ok, subscribe_id} = cast_subscribe(peer, topic, options)
    receive do
      {Peer, ^peer, %Message{type: :subscribed,
                             args: [^subscribe_id, subscription]}} ->
        {:ok, subscription}
    after
      config_timeout -> {:error, :timeout}
    end
  end

  @doc """
  Helper to receive an event for the given peer and subscription.
  """
  @spec receive_event(pid, integer) ::
    {:ok, %{subscription: integer, publication: integer, details: map,
            arguments: list, arguments_kw: map}}
  | {:error, :timeout}
  def receive_event(peer, subscription)
      when is_pid(peer) and is_integer(subscription) do
    receive_message peer, :event do
      {:ok, [^subscription, publication, details | rest]} ->
        {arguments, arguments_kw} = case rest do
                                      [] ->
                                        {[], %{}}
                                      [arguments] ->
                                        {arguments, %{}}
                                      [arguments, arguments_kw] ->
                                        {arguments, arguments_kw}
                                    end
        {:ok, %{subscription: subscription,
                publication: publication,
                details: details,
                arguments: arguments,
                arguments_kw: arguments_kw}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Asynchronously send an unsubscribe message from `peer` for
  `subscription`.
  """
  @spec cast_unsubscribe(pid, Message.wamp_id) ::
    {:ok, Message.wamp_id} | {:error, any}
  def cast_unsubscribe(peer, subscription) do
    {:ok, %{args: [unsubscribe | _]} = message} =
      new_unsubscribe_message(subscription)
    case Peer.call(peer, __MODULE__, {:send, message}) do
      :ok              -> {:ok, unsubscribe}
      {:error, reason} -> {:error, reason}
    end
  end

  def call_unsubscribe(peer, subscription) do
    case cast_unsubscribe(peer, subscription) do
      {:ok, unsubscribe} ->
        receive_unsubscribed(peer, unsubscribe)
      {:error, reason} ->
        {:error, reason}
    end
  end

  def receive_unsubscribed(peer, unsubscribe) do
    receive_message peer, :unsubscribed do
      {:ok, [^unsubscribe]} -> :ok
      {:error, reason}      -> {:error, reason}
    end
  end
  # def receive_unsubscribed(peer, unsubscribe) do
  #   receive do
  #     {Spell.Peer, ^peer,
  #       %Message{type: :unsubscribed, args: [^unsubscribe]}} ->
  #       :ok
  #   after
  #     @timeout -> {:error, :timeout}
  #   end
  # end

  # Role Callbacks

  def get_features(_) do
    {:subscriber, %{}}
  end

  def init(_peer, []) do
    {:ok, %__MODULE__{}}
  end

  @doc """
  Handle `SUBSCRIBED`, `UNSUBSCRIBED`, and `EVENT` messages.
  """
  def handle_message(%Message{type: :subscribed,
                              args: [request, subscription]} = message,
                     _peer, state) do
    case Dict.pop(state.subscribe_requests, request) do
      {nil, _} ->
        {:error, {:subscribe, :no_request}}
      {pid, subscribe_requests} ->
        :ok = Peer.notify(pid, message)
        subscriptions = Dict.put_new(state.subscriptions, subscription, pid)
        {:ok, %{state |
                subscribe_requests: subscribe_requests,
                subscriptions: subscriptions}}
    end
  end

  def handle_message(%Message{type: :unsubscribed,
                              args: [request]} = message,
                     _peer, state) do
    case Dict.pop(state.unsubscribe_requests, request) do
      {nil, _} ->
        {:error, {:unsubscribe, :no_request}}
      {{subscription, pid}, unsubscribe_requests} ->
        :ok = Peer.notify(pid, message)
        subscriptions = Dict.delete(state.subscriptions, subscription)
        {:ok, %{state |
                unsubscribe_requests: unsubscribe_requests,
                subscriptions: subscriptions}}
    end
  end

  def handle_message(%Message{type: :event,
                              args: [subscription | _]} = message,
                     _peer, state) do
    case Dict.get(state.subscriptions, subscription) do
      nil ->
        {:error, :no_subscription}
      pid ->
        :ok = Peer.notify(pid, message)
        {:ok, state}
    end
  end

  def handle_message(message, peer, state) do
    super(message, peer, state)
  end

  @doc """
  The `handle_call` function is used to send `SUBSCRIBE` and `UNSUBSCRIBE`
  messages.
  """
  def handle_call({:send, %Message{type: :subscribe,
                                   args: [request | _]} = message},
                  {pid, _}, peer, state) do
    :ok = Peer.send_message(peer, message)
    subscribe_requests = Dict.put_new(state.subscribe_requests, request, pid)
    {:ok, :ok, %{state | subscribe_requests: subscribe_requests}}
  end

  def handle_call({:send, %Message{type: :unsubscribe,
                                   args: [request, subscription]} = message},
                  {pid, _}, peer, state) do
    case Dict.get(state.subscriptions, subscription) do
      nil ->
        {:ok, {:error, :no_subscription}, state}
      ^pid ->
        :ok = Peer.send_message(peer, message)
        unsubscribe_requests = Dict.put_new(state.unsubscribe_requests, request,
                                            {subscription, pid})
        {:ok, :ok, %{state | unsubscribe_requests: unsubscribe_requests}}
      other_pid when is_pid(other_pid) ->
        {:ok, {:error, :not_owner}, state}
    end
  end

  # Private Functions

  @spec new_subscribe_message(Message.wamp_uri, Keyword.t) ::
    {:ok, Message.t} | {:error, any}
  defp new_subscribe_message(topic, options) do
    Message.new(type: :subscribe,
                args: [Message.new_id(),
                       Keyword.get(options, :options, %{}),
                       topic])
  end

  @spec new_unsubscribe_message(Message.wamp_uri) ::
    {:ok, Message.t} | {:error, any}
  defp new_unsubscribe_message(subscription) do
    Message.new(type: :unsubscribe,
                args: [Message.new_id(), subscription])
  end

  @spec config_timeout() :: integer
  defp config_timeout do
    Application.get_env(:spell, :timeout, @default_timeout)
  end
end
