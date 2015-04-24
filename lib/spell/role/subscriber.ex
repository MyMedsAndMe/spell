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
  @spec subscribe(pid, Message.wamp_uri) :: {:ok, Message.wamp_id}
  def subscribe(peer, topic) do
    # TODO: `defmessage` to avoid this leaky abstraction
    {:ok, %{args: [subscribe_id | _]} = message} =
      new_subscribe_message(topic)
    :ok = Peer.cast_role(peer, __MODULE__, message)
    {:ok, subscribe_id}
  end

  # Role Callbacks

  def get_features(_) do
    {:subscriber, %{}}
  end

  # Private Functions

  @spec new_subscribe_message(Message.wamp_uri) ::
    {:ok, Message.t} | {:error, any}
  defp new_subscribe_message(topic) do
    Message.new(type: :subscribe, args: [Message.new_id(), topic])
  end

end
