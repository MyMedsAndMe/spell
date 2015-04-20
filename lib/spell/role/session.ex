defmodule Spell.Role.Session do
  use Spell.Role

  alias Spell.Message
  alias Spell.Peer

  require Logger

  # Module Attributes

  defstruct [:realm, :middleware_stack]

  @goodbye_and_out "wamp.error.goodbye_and_out"

  # Middleware Callbacks

  @doc """
  Called when initializing the middleware.
  """
  def init(options) do
    {:ok, get_state(options)}
  end

  @doc """
  Called on connection open.
  """
  def on_open(peer, %{realm: realm} = state) when realm != nil do
    {:ok, hello} = new_hello(state.realm, %{roles: get_features(state)})
    case Peer.send_message(peer, hello) do
      :ok              -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Called on connection close.
  """
  def on_close(%{}, peer, state) do
    Peer.send_message(peer, new_goodbye())
    {:ok, state}
  end

  @doc """
  Called when the peer receives a message.
  """
  def handle(%Message{type: :welcome, args: [session, _details]},
             peer, state) do
    case Peer.set_session(peer, session) do
      :ok              -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  def handle(%Message{type: :goodbye} = goodbye, _peer, state) do
    {:close, goodbye, state}
  end

  def handle(%Message{type: :abort} = abort, _peer, _state) do
    {:error, abort}
  end

  # Private Functions

  defp new_hello(realm, details \\ %{}) do
    Message.new(type: :hello, args: [realm, details])
  end

  defp new_goodbye(reason \\ @goodbye_and_out, details \\ %{}) do
    Message.new(type: :goodbye, args: [details, reason])
  end

  defp get_state(options) do
    struct(%__MODULE__{}, options)
  end

  defp get_features(state) do
    # TODO: get this working across modules
    %{publisher: %{}}
    # Enum.reduce(state.middleware_stack || [], %{}, fn
    #   middleware, features ->
    #     Dict.merge(features, middleware.features())
    # end)
  end

end
