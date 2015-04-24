defmodule Spell.Role do
  @moduledoc """
  The `Spell.Role` module defines the behaviour of a role in spell.

  A role specifies logic for handling groups of commands. A peer
  is started with zero or more roles, which the peer uses to configure
  its state and handle its messages.
  """
  use Behaviour

  # Type Specs

  # TODO: broken typespec
  @type peer_options :: %{roles: %{features: Map.t}}

  # Macros

  defmacro __using__(_options) do
    quote do
      @behaviour Spell.Role

      def get_features(_options),         do: nil

      def init(peer_options, options),    do: {:ok, options}

      def on_open(_peer, state),          do: {:ok, state}

      def on_close(_peer, state),         do: {:ok, state}

      def handle(_message, _peer, state), do: {:ok, state}

      defoverridable [get_features: 1,
                      init: 2,
                      on_open: 2,
                      on_close: 2,
                      handle: 3]
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
  defcallback on_open(peer :: pid, state :: any) :: {:ok, any} | {:error, any}

  @doc """
  Called when the connection is being closed. Returns the state wrapped in
  an ok tuple or an error tuple
  """
  defcallback on_close(peer :: pid, state :: any) :: {:ok, any} | {:error, any}

  @doc """
  Handle an incoming message.
  """
  defcallback handle(message :: Message.t, peer :: pid, state :: any) ::
    {:ok, any} | {:error, any}

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
    mapper = fn {role, role_options} ->
      role.init(peer_options, role_options)
    end
    case map(roles, mapper) do
      {:ok, results} ->
        {:ok, (for {r, _} <- roles, do: r) |> Enum.zip(results)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Call the `on_open` function for a list of roles.
  """
  @spec map_on_open([{module, any}], pid) ::
    {:ok, [{module, any}]} | {:error, any}
  def map_on_open(roles, peer) do
    case map(roles, fn {role, state} -> role.on_open(peer, state) end) do
      {:ok, results} ->
        {:ok, (for {r, _} <- roles, do: r) |> Enum.zip(results)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Call the `on_close` function for a list of roles.
  """
  @spec map_on_close([{module, any}], pid) ::
    {:ok, [{module, any}]} | {:error, any}
  def map_on_close(roles, peer) do
    case map(roles, fn {role, state} -> role.on_close(peer, state) end) do
      {:ok, results} ->
        {:ok, (for {r, _} <- roles, do: r) |> Enum.zip(results)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Call the `on_close` function for a list of roles.
  """
  @spec map_handle([{module, any}], Message.t, pid) ::
    {:ok, [{module, any}]} | {:error, any}
  def map_handle(roles, message, peer) do
    case map(roles, fn {role, s} -> role.handle(message, peer, s) end) do
      {:ok, results} ->
        {:ok, (for {r, _} <- roles, do: r) |> Enum.zip(results)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private Functions

  @spec map([module], ((any) -> {:ok, any} | {:error, any}),
            Keyword.t) ::
    {:ok, [any]} | {:error, any}
  defp map(roles, function, results \\ [])

  defp map([], _function, results) do
    {:ok, Enum.reverse(results)}
  end

  defp map([role | roles], function, results) do
    case function.(role) do
      {:ok, result}    -> map(roles, function, [result | results])
      {:error, reason} -> {:error, {role, reason}}
    end
  end


end
