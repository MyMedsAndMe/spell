# Run this script from the Spell root with
#
#     mix spell.example.auth

defmodule Auth do
  @moduledoc """
  The `Auth` module implements the example for a login RPC.
  """

  defmodule Callee do
    use GenServer

    require Logger
    defstruct [:callee]

    # Public Functions

    def start_link(procedure, options \\ []) do
      GenServer.start_link(__MODULE__, {procedure, options}, name: __MODULE__)
    end

    def stop, do: GenServer.cast(__MODULE__, :stop)

    # Private Functions

    def init({procedure, options}) do
      {:ok, callee} = Auth.new_peer([Spell.Role.Callee], options)
      {:ok, _register_id} = Spell.call_register(callee, procedure)

      state = %__MODULE__{callee: callee}
      {:ok, state}
    end

    def handle_cast(:stop, state), do: {:stop, :normal, state}

    def handle_info({Spell.Peer, _pid, %Spell.Message{args: [request, _reg_id, _msg, params], type: :invocation}}, (%{callee: callee}) = state) do
      Spell.cast_yield(callee, request, [arguments_kw: Poison.Parser.parse!(params) |> Auth.login])
      {:noreply, state}
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
{:ok, _callee} = Callee.start_link(procedure)

:timer.sleep(1000000)

Logger.info("DONE... Stopping Crossbar.io server")
:ok = Crossbar.stop()
Logger.info("DONE.")
