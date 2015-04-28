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
  Publish a message from `peer`.
  """
  def cast_publish(peer, topic, options \\ [])
      when is_pid(peer) and is_binary(topic) and is_list(options) do
    {:ok, %{args: [request_id | _]} = publish} =
      new_publish_message(topic, options)
    :ok = Peer.send_message(peer, publish)
    {:ok, request_id}
  end

  @doc """
  Synchronously publish a message from `peer` for `topic`.
  """
  def call_publish(peer, topic,
                   options \\ [options: %{acknowledge: true}]) do
    options = if options[:options] do
                put_in(options, [:options, :acknowledge], true)
              else
                Keyword.put(options, :options, %{acknowledge: true})
              end
    {:ok, request_id} = cast_publish(peer, topic, options)
    receive do
      {Peer, ^peer, %Message{type: :published,
                              args: [^request_id, publication]}} ->
        {:ok, publication}
    after
      1000 -> {:error, :timeout}
    end
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
                       args: [_request, _publication]} = message,
                     peer, state) do
    Peer.send_to_owner(peer, message)
    {:ok, state}
  end

  def handle_message(message, peer, state) do
    super(message, peer, state)
  end

  # Private Functions

  @spec new_publish_message(Message.wamp_uri, Keyword.t) ::
    {:ok, Message.t} | {:error, any}
  defp new_publish_message(topic, options) do
    # TODO: Allow `publish` messages with partial args
    Message.new(type: :publish,
                args: [Message.new_id(),
                       Keyword.get(options, :options, %{}),
                       topic,
                       Keyword.get(options, :arguments, []),
                       Keyword.get(options, :arguments_kw, %{})])
  end

end
