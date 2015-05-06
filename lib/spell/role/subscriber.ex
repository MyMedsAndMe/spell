defmodule Spell.Role.Subscriber do
  @moduledoc """
  The `Spell.Role.Subscriber` module implements the behaviour
  of the subscriber role.
  """
  use Spell.Role

  require Logger

  alias Spell.Peer
  alias Spell.Message

  @timeout 1000

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
    :ok = Peer.send_message(peer, message)
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
      @timeout -> {:error, :timeout}
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
    receive do
      {Spell.Peer, ^peer,
       %Message{type: :event,
                args: [^subscription, publication, details | rest]}} ->
        # This would also be useful for RPC -- refactor out to util?
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
    after
      @timeout -> {:error, :timeout}
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
    Peer.send_message(peer, message)
    {:ok, unsubscribe}
  end

  def call_unsubscribe(peer, subscription) do
    {:ok, unsubscribe} = cast_unsubscribe(peer, subscription)
    receive_unsubscribed(peer, unsubscribe)
  end

  def receive_unsubscribed(peer, unsubscribe) do
    receive do
      {Spell.Peer, ^peer,
        %Message{type: :unsubscribed, args: [^unsubscribe]}} ->
        :ok
    after
      @timeout -> {:error, :timeout}
    end
  end

  # Role Callbacks

  def get_features(_) do
    {:subscriber, %{}}
  end

  def handle_message(%{type: type} = message, peer, state)
      when type == :subscribed or type == :unsubscribed or type == :event do
    :ok = Peer.send_to_owner(peer, message)
    {:ok, state}
  end

  def handle_message(message, peer, state) do
    super(message, peer, state)
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

end
