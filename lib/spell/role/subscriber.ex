defmodule Spell.Role.Subscriber do
  @moduledoc """
  The `Spell.Role.Subscriber` module implements the behaviour
  of the subscriber role.
  """
  use Spell.Role

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

  If different selective receives for events are needed, roll your own!
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

  # Role Callbacks

  def get_features(_) do
    {:subscriber, %{}}
  end

  def handle_message(%{type: :subscribed} = subscribed, peer, state) do
    :ok = Peer.send_to_owner(peer, subscribed)
    {:ok, state}
  end

  def handle_message(%{type: :event} = event, peer, state) do
    :ok = Peer.send_to_owner(peer, event)
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

end
