defmodule Spell.Role do
  @moduledoc """
  The `Spell.Role` module defines the behaviour of a role in spell.

  A role specifies the logic for handling groups of commands. A peer is started
  with one or more roles, which the peer uses to configure its state and handle
  its messages.

  ## Callbacks

  A module must implement all `Spell.Role` behaviour callbacks, though the `use
  Spell.Role` directive provides a sane default implementation for each.

   * `get_features/1`
   * `init/2`
   * `on_open/2`
   * `on_close/2`
   * `handle_message/3`
   * `handle_call/4`

  """
  use Behaviour

  # Type Specs

  # TODO: broken typespec
  @type peer_options :: %{roles: %{features: Map.t}}

  # Macros

  defmacro __using__(_options) do
    quote do
      @behaviour Spell.Role

      # Default Role Callbacks

      def get_features(_options),      do: nil

      def init(peer_options, options), do: {:ok, options}

      def on_open(_peer, state),       do: {:ok, state}

      def on_close(_peer, state),      do: {:ok, state}

      def handle_message(_, _, state), do: {:ok, state}

      def handle_call(_message, _from, _peer, state) do
        {:ok, :ok, state}
      end

      defoverridable [get_features: 1,
                      init: 2,
                      on_open: 2,
                      on_close: 2,
                      handle_message: 3,
                      handle_call: 4]
    end

  end

  # Callback Definitions

  @doc """
  Get the key and features that this role announces. Returns `nil`
  if the features announces no features.
  """
  defcallback get_features(options :: Keyword.t) :: {atom, map}

  @doc """
  init callback for generating the role's initial state given `options`.
  """
  defcallback init(peer_options :: peer_options, role_options :: Keyword.t) ::
    {:ok, any} | {:error, any}

  @doc """
  Called after the connection is opened. Returns the state wrapped in an
  ok tuple or an error tuple.

  """
  defcallback on_open(peer :: Peer.t, state :: any) ::
    {:ok, any} | {:error, any}

  @doc """
  Called when the connection is being closed. Returns the state wrapped in
  an ok tuple or an error tuple
  """
  defcallback on_close(peer :: Peer.t, state :: any) ::
    {:ok, any} | {:error, any}

  @doc """
  Handle an incoming WAMP message.
  """
  defcallback handle_message(message :: Message.t,
                             peer :: Peer.t, state :: any) ::
    {:ok, any} | {:error, any}

  @doc """
  Handle a call from the peer.

  ## Return values

   * `{:ok, reply, new_state}`: return `reply`
   * `{:error, reason}`
  """
  defcallback handle_call(message :: any, from :: pid,
                          peer :: Peer.t, state :: any) ::
    {:ok, any, any} | {:error, any}

  # Public Functions

  @doc """
  Normalize a list of role options by wrapping bare `module` items
  with an option tuple. If an unexpected role is encountered, an
  error tuple is returned.
  """
  @spec normalize_role_options([module | {module, Keyword.t}]) ::
    {:ok, [{module, Keyword.t}]} | {:error, {:bad_role, any}}
  def normalize_role_options(roles, acc \\ [])

  def normalize_role_options([], acc) do
    {:ok, Enum.reverse(acc)}
  end

  def normalize_role_options([module | roles], acc) when is_atom(module) do
    normalize_role_options(roles, [{module, []} | acc])
  end

  def normalize_role_options([{module, options} = role | roles], acc)
      when is_atom(module) and is_list(options) do
    normalize_role_options(roles, [role | acc])
  end

  def normalize_role_options([bad_role | _roles], _acc) do
    {:error, {:bad_role, bad_role}}
  end

  @doc """
  Returns a map with the features of the listed roles.
  """
  @spec collect_features([{module, any}]) :: Map.t(atom, Map.t)
  def collect_features(roles) do
    # TODO: overlapping keys will overwrite. Merging would be more usful
    roles
      |> Enum.map(fn {role, options} -> role.get_features(options) end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.into(%{})
  end

  @doc """
  Call the `on_init` function for a list of roles. `peer_options` is the
  list of options which a peer was initialized with.
  """
  @spec map_init([{module, any}], Keyword.t) ::
    {:ok, [{module, any}]} | {:error, any}
  def map_init(roles, peer_options) do
    map(roles, fn {role, role_options} ->
      role.init(peer_options, role_options)
    end)
  end

  @doc """
  Call the `on_open` function for a list of roles.
  """
  @spec map_on_open([{module, any}], Peer.t) ::
    {:ok, [{module, any}]} | {:error, any}
  def map_on_open(roles, peer) do
    map(roles, fn {role, state} -> role.on_open(peer, state) end)
  end

  @doc """
  Call the `on_close` function for a list of roles.
  """
  @spec map_on_close([{module, any}], Peer.t) ::
    {:ok, [{module, any}]} | {:error, any}
  def map_on_close(roles, peer) do
    map(roles, fn {role, state} -> role.on_close(peer, state) end)
  end

  @doc """
  Call the `handle_message` function for a list of roles.
  """
  @spec map_handle_message([{module, any}], Message.t, Peer.t) ::
    {:ok, [{module, any}]} | {:error, any}
  def map_handle_message(roles, message, peer) do
    map(roles, fn {r, s} -> r.handle_message(message, peer, s) end)
  end

  @doc """
  From `roles` call the `role`'s `send_message` function with the `message`
  and the role's state.
  """
  @spec call([{module, any}], module, any, pid, Peer.t) ::
    {:ok, [{module, any}]} | {:error, :no_role}
  def call(roles, role, message, from, peer) do
    case Keyword.fetch(roles, role) do
      {:ok, role_state} ->
        case role.handle_call(message, from, peer, role_state) do
          {:ok, reply, role_state} ->
            {:ok, reply, Keyword.put(roles, role, role_state)}
          {:error, reason} ->
            {:error, reason}
        end
      :error ->
        {:error, :no_role}
    end
  end

  # Private Functions

  @spec map([module], ((any) -> {:ok, any} | {:error, any}),
            Keyword.t, Keyword.t) ::
    {:ok, Keyword.t} | {:close, Keyword.t, Keyword.t} | {:error, any}
  defp map(roles, function, results \\ [], reasons \\ [])

  defp map([], _function, results, []) do
    {:ok, Enum.reverse(results)}
  end
  defp map([], _function, results, reasons) do
    {:close, Enum.reverse(reasons), Enum.reverse(results)}
  end

  defp map([{role_module, _} = role | roles], function, results, reasons) do
    case function.(role) do
      {:ok, result} ->
        map(roles, function, [{role_module, result} | results], reasons)
      {:close, reason, result} ->
        map(roles, function,
            [{role_module, result} | results],
            [{role_module, reason} | reasons])
      {:error, reason} ->
        {:error, {role, reason}}
    end
  end

end
