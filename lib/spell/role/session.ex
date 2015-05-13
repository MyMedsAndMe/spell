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
  alias Spell.Authentication, as: Auth

  require Logger

  # Module Attributes

  defstruct [
    :realm,
    :roles,
    :authentication,
    :auth_lookup,
    session: nil,
    details: nil,
    pid_hello: nil,
    pid_goodbye: nil]

  # TODO: rest of types
  @type t :: %__MODULE__{
    realm: String.t,
    authentication: Keyword.t,
    session: integer}

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
    {:ok, ^message} = Peer.call(peer, __MODULE__, {:send, message})
    :ok
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
  Returns the state with the specified realm, role, and authentication info.

   * `peer_options :: Map.t`
  """
  def init(%{realm: nil}, _) do
    {:error, :no_realm}
  end
  def init(%{role: role}, options) do
    auth_lookup = get_in(options, [:authentication, :schemes])
      |> Auth.schemes_to_lookup()
    {:ok, struct(%__MODULE__{roles: role.features, auth_lookup: auth_lookup},
                 options)}
  end

  @doc """
  Send a `HELLO` message when the connection is opened.
  """
  def on_open(peer, %{realm: realm} = state) when realm != nil do
    {:ok, hello} = new_hello(state.realm, get_hello_details(state))
    case Peer.send_message(peer, hello) do
      :ok ->
        {:ok, %{state | pid_hello: peer.owner}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handle `CHALLENGE`, `WELCOME`, `GOODBYE`, and `ABORT` messages.
  """
  def handle_message(%Message{type: :challenge,
                              args: [name, details]} = challenge,
                     peer, %{pid_hello: pid_hello} = state)
      when is_pid(pid_hello) do
   case get_auth_by_name(state, name) do
     nil ->
       {:error, {:challenge, :bad_scheme}}
     {auth_module, options} when is_atom(auth_module) ->
       case auth_module.response(details, options) do
         {:ok, signature, details} ->
           {:ok, message} = new_authenticate(signature, details)
           :ok = Peer.send_message(peer, message)
           {:ok, state}
         {:error, reason} ->
           {:error, {:challenge, reason}}
       end
    end
  end

  def handle_message(%Message{type: :welcome,
                              args: [session, details]} = welcome,
                     _peer, %{pid_hello: pid_hello} = state)
      when is_pid(pid_hello) do
    :ok = Peer.notify(pid_hello, welcome)
    {:ok, %{state | session: session, details: details, pid_hello: nil}}
  end

  def handle_message(%Message{type: :goodbye} = goodbye, _peer,
                     %{pid_goodbye: pid_goodbye} = state) do
    :ok = Peer.notify(pid_goodbye, goodbye)
    {:close, goodbye, state}
  end

  def handle_message(%Message{type: :abort} = abort, _peer, _state) do
    # TODO: test against various abort messages
    {:error, abort}
  end

  def handle_message(message, peer, state) do
    super(message, peer, state)
  end

  @doc """
  The `handle_call` function is used to send `GOODBYE` messages.
  """
  def handle_call({:send, %Message{type: :goodbye} = message},
                  {pid_goodbye, _}, peer, %{pid_goodbye: nil} = state) do
    :ok = Peer.send_message(peer, message)
    {:ok, {:ok, message}, %{state | pid_goodbye: pid_goodbye}}
  end

  # Private Functions

  @spec new_hello(String.t, map) :: {:ok, Message.t} | {:error, any}
  defp new_hello(realm, details) do
    Message.new(type: :hello, args: [realm, details])
  end

  @spec get_hello_details(t) :: map
  defp get_hello_details(state) do
    case state.authentication do
      nil -> %{}
      authentication -> Auth.get_details(authentication)
    end
    |> Dict.merge(%{roles: state.roles})
  end

  @spec new_goodbye(String.t, map) :: {:ok, Message.t} | {:error, any}
  defp new_goodbye(reason, details) do
    # TODO: if `reason` is an atom, lookup its value
    Message.new(type: :goodbye, args: [details, reason])
  end

  @spec new_authenticate(String.t, map) :: {:ok, Message.t} | {:error, any}
  def new_authenticate(signature, details) do
    Message.new(type: :authenticate, args: [signature, details])
  end

  @spec get_auth_by_name(t, String.t) :: {module, Keyword.t} | nil
  defp get_auth_by_name(state, name) do
    case Dict.get(state.auth_lookup, name) do
      nil -> nil
      auth_module when is_atom(auth_module) ->
        case Dict.get(state.authentication[:schemes], auth_module) do
          nil -> nil
          options -> {auth_module, options}
        end
    end
  end

end
