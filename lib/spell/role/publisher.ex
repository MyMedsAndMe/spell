defmodule Spell.Role.Publisher do
  @moduledoc """
  The `Spell.Role.Publisher` module implements the publisher
  behaviour.
  """
  use Spell.Role

  alias Spell.Message
  alias Spell.Peer

  defstruct [published: HashDict.new()]

  # Type Specs

  @type t :: %__MODULE__{
    published: HashDict.t(String.t, Message.t)}

  # Public Interface

  @doc """
  Publish a message with the given peer.
  """
  def publish(peer, topic, options \\ []) do
    {:ok, %{args: [request_id | _]} = message} =
      new_publish_message(topic, options)
    :ok = Peer.cast_role(peer, __MODULE__, {:publish, message})
    {:ok, request_id}
  end

  # Role Callbacks

  @doc """
  Announces the `publisher` role.

  No advanced features are yet supported.
  """
  def get_features(_options), do: {:publisher, %{}}

  def init(_peer_options, _role_options) do
    {:ok, %__MODULE__{}}
  end

  def handle_message(%{type: :published,
                       args: [request, publication]} = message,
                     peer, state) do
    Peer.send_to_owner(peer, message)
    {:ok, state}
  end

  def handle_message(_message, _peer, state) do
    {:ok, state}
  end

  def handle_cast({:publish, %{type: :publish} = publish}, state) do
    # TODO: Check for acknowledge option and save publish id if present
    :ok = send_message(publish)
    {:ok, state}
  end

  # Private Functions

  @spec new_publish_message(Message.wamp_uri, Keyword.t) ::
    {:ok, Message.t} | {:error, any}
  defp new_publish_message(topic, options) do
    # TODO: Allow `publish` messages with partial args
    Message.new(type: :publish,
                args: [Message.new_id(),
                       Dict.get(options, :options, %{}),
                       topic,
                       Dict.get(options, :arguments, []),
                       Dict.get(options, :arguments_kw, %{})])
  end

end
