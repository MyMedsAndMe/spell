# Run this script from the Spell root with
#
#     mix spell.example.auth

defmodule Auth do
  @moduledoc """
  The `RPC` module implements the example for asynchronous Remote Procedure Call.
  """

  defmodule Callee do
    require Logger
    defstruct [:callee, :procedure, timeout: 1000]

    # Public Functions

    @doc """
    Start the callee with the passed procedures.
    """
    def start_link(procedures, options \\ []) do
      {:ok, spawn_link(fn -> init(procedures, options) end)}
    end

    # Private Functions

    defp init(procedure, options) do
      {:ok, callee} = Auth.new_peer([Spell.Role.Callee], options)
      {:ok, _register_id} = Spell.cast_register(callee, procedure)

      %__MODULE__{callee: callee,
                  procedure: procedure}
        |> struct(options)
        |> loop()
    end

    defp loop(state) do
      receive do
        :stop -> :ok
        {Spell.Peer, pid, message} ->
          handle_message(state, message)
          loop(state)
      after
        state.timeout -> {:error, :timeout}
      end
    end

    defp handle_message(state, %Spell.Message{args: _args, code: _code, type: :registered}) do
      Logger.info("Function registered")
    end

    defp handle_message(state, %Spell.Message{args: [request, _reg_id, _msg], code: code, type: :invocation} = message) do
      Spell.cast_yield(state.callee, request)
    end

    defp handle_message(state, %Spell.Message{args: [request, _reg_id, _msg, params], code: code, type: :invocation} = message) do
      Spell.cast_yield(state.callee, request, [arguments_kw: Poison.Parser.parse!(params) |> Auth.login])
    end

  end

  @doc """
  For the sake of the example login function contains a very dumb logic to authorize
  only 'username' = 'marco' and 'password' = 'pass'.
  """
  def login(%{"password" => "pass", "username" => "marco"}), do: %{ok: "Welcome back Marco!"}
  def login(_data), do: %{error: "Wrong credentials"}

  # Public Interface

  @doc """
  Shared helper function for create a new peer configured with `roles` and
  `options`.
  """
  def new_peer(roles, options) do
    uri   = Keyword.get(options, :uri, Crossbar.uri)
    realm = Keyword.get(options, :realm, Crossbar.get_realm())
    Spell.connect(uri, realm: realm, roles: roles)
  end

end

alias Auth.Callee
require Logger

Logger.info("Starting the Crossbar.io test server...")
# Start the crossbar testing server
{:ok, _pid} = Crossbar.start()

procedure = "api.mymedsandme.auth"
{:ok, callee} = Callee.start_link(procedure)

:timer.sleep(1000000)

Logger.info("DONE... Stopping Crossbar.io server")
:ok = Crossbar.stop()
Logger.info("DONE.")
