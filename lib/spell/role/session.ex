defmodule Spell.Role.Session do
  @moduledoc """
  The `Spell.Role.Session` module implements the behaviour for a session
  role.

  Sessions are pseudo-roles; each peer started with `Spell.Connect`
  has `Spell.Role.Session` added as the first role in `roles`.

  """
  use Spell.Role

  alias Spell.Message
  alias Spell.Peer

  require Logger

  # Module Attributes

  defstruct [:realm, :roles, session: nil, details: nil]

  @goodbye_close_realm "wamp.error.close_realm"
  @goodbye_and_out     "wamp.error.goodbye_and_out"

  # Public Functions

  @doc """
  Send a GOODBYE message to the remote peer. The remote peer should
  reply with a GOODBYE.
  """
  @spec cast_goodbye(pid, Keyword.t) :: :ok
  def cast_goodbye(peer, options \\ []) do
    reason = Keyword.get(options, :reason, @goodbye_close_realm)
    details = Keyword.get(options, :details, %{message: "goodbye"})
    {:ok, message} = new_goodbye(reason, details)
    Peer.send_message(peer, message)
  end

  @doc """
  Send a GOODBYE message to the remote peer and wait for the GOODBYE reply.

  This must be called from the peer's owner, otherwise the listening
  process won't receive the GOODBYE message.
  """
  @spec call_goodbye(pid, Keyword.t) :: {:ok, Message.t} | {:error, :timeout}
  def call_goodbye(peer, options \\ []) do
    timeout = Keyword.get(options, :timeout, 1000)
    :ok = cast_goodbye(peer, options)
    Peer.await(peer, :goodbye, timeout)
  end

  @doc """
  Await the welcome message. Useful for blocking until the session is
  established.
  """
  @spec await_welcome(pid) :: {:ok, Message.t} | {:error, :timeout}
  def await_welcome(peer), do: Peer.await(peer, :welcome)

  # Role Callbacks

  @doc """
  Returns the state with the specified realm and role.

   * `peer_options :: Map.t`
  """
  def init(%{realm: nil}, _) do
    {:error, :no_realm}
  end
  def init(%{realm: realm, role: role}, []) when is_binary(realm) do
    {:ok, %__MODULE__{realm: realm, roles: role.features}}
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
  def handle_message(%Message{type: :welcome,
                              args: [session, details]} = welcome,
                     peer, state) do
    :ok = Peer.send_to_owner(peer, welcome)
    {:ok, %{state | session: session, details: details}}
  end

  def handle_message(%Message{type: :goodbye} = goodbye, peer, state) do
    :ok = Peer.send_to_owner(peer, goodbye)
    {:close, goodbye, state}
  end

  def handle_message(%Message{type: :abort} = abort, _peer, _state) do
    # TODO: test against various abort messages
    {:error, abort}
  end

  def handle_message(message, peer, state) do
    super(message, peer, state)
  end

  # Private Functions

  @spec new_hello(String.t, map) :: {:ok, Message.t} | {:error, any}
  defp new_hello(realm, details) do
    Message.new(type: :hello, args: [realm, details])
  end

  @spec new_goodbye(String.t, map) :: {:ok, Message.t} | {:error, any}
  defp new_goodbye(reason, details) do
    # TODO: if `reason` is an atom, lookup its value
    Message.new(type: :goodbye, args: [details, reason])
  end

end
