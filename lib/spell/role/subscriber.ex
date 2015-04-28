defmodule Spell.Role.Subscriber do
  @moduledoc """
  The `Spell.Role.Subscriber` module implements the behaviour
  of the subscriber role.
  """
  use Spell.Role

  alias Spell.Peer
  alias Spell.Message

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
      1000 -> {:error, :timeout}
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
