defmodule Spell.Role do
  @moduledoc """
  The `Spell.Role` module defines the behaviour of a role in spell.

  A role specifies logic for handling groups of commands.
  """
  use Behaviour

  # Macros

  defmacro __using__(_options) do
    quote do
      @behaviour Spell.Role

      def init(options),                  do: {:ok, options}

      def on_open(_peer, state),          do: {:ok, state}

      def on_close(_peer, state),         do: {:ok, state}

      def handle(_message, _peer, state), do: {:ok, state}

      defoverridable [init: 1,
                      on_open: 2,
                      on_close: 2,
                      handle: 3]
    end
  end

  # Callback Definitions

  @doc """
  init callback for generating the role's initial state given `options`.
  """
  defcallback init(options :: Keyword.t) :: {:ok, any} | {:error, any}

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
  Call the `on_init` function for a list of roles.
  """
  @spec map_init([{module, any}]) :: {:ok, [{module, any}]} | {:error, any}
  def map_init(roles) do
    case map(roles, fn {role, options} -> role.init(options) end) do
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
