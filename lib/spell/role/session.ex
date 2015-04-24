defmodule Spell.Role.Session do
  @moduledoc """
  The `Spell.Role.Session` module implements the behaviour for a session
  role.

  Unlike other roles, sessions are implicit.

  ## TODO

   * Auth
  """
  use Spell.Role

  alias Spell.Message
  alias Spell.Peer

  require Logger

  # Module Attributes

  defstruct [:realm, :roles, session: nil, details: nil]

  @goodbye_and_out "wamp.error.goodbye_and_out"


  # Role Callbacks

  @doc """
  Returns the state with the specified realm and role.

   * `peer_options :: Map.t`
  """
  def init(peer_options, session_options) do
    {:ok, struct(%__MODULE__{},
                 [{:roles, peer_options.role.features}
                  | session_options])}
  end

  @doc """
  Send a HELLO message when the connection is opened.
  """
  def on_open(peer, %{realm: realm} = state) when realm != nil do
    {:ok, hello} = new_hello(state.realm, %{roles: state.roles})
    case Peer.send_message(peer, hello) do
      :ok              -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Handle WELCOME, GOODBYE, and ABORT messages.

  ## Behaviour

   * WELCOME: set the peer session
   * GOODBYE: close the connection normally
   * ABORT: close the connection with an error. With the default supervision
     settings, the peer will be restarted.
  """
  def handle_message(%Message{type: :welcome, args: [session, details]},
             peer, state) do
    {:ok, %{state | session: session, details: details}}
  end

  def handle_message(%Message{type: :goodbye} = goodbye, _peer, state) do
    {:close, goodbye, state}
  end

  def handle_message(%Message{type: :abort} = abort, _peer, _state) do
    {:error, abort}
  end

  # Private Functions

  defp new_hello(realm, details \\ %{}) do
    Message.new(type: :hello, args: [realm, details])
  end

  defp new_goodbye(reason \\ @goodbye_and_out, details \\ %{}) do
    Message.new(type: :goodbye, args: [details, reason])
  end

end
