# This example want to show how to call a Remote Procedure.
# Inside the module RPC we have the module Callee where the procedure 
# is defined and the module Calleer who will call the procedure.
#
# Run this script from the Spell root with
#
#     mix spell.example.rpc

defmodule RPC do
  @moduledoc """
  The `RPC` module implements the example for asynchronous Remote Procedure Call.
  """

  defmodule Caller do
    @moduledoc """
    This Caller need to be initialised with the `procedure` where the Callee is subscribed 
    and the `params` used within the remote procedure

    iex> Caller.start_link("com.spell.rpc.sum", [arguments: [1, 2, 3]])
    """
    require Logger
    defstruct [:caller, :procedure, :params, interval: 1500]

    # Public Functions

    @doc """
    Initialize the caller
    """
    def start_link(procedure, params \\ [], options \\ []) do
      {:ok, spawn_link(fn -> init(procedure, params, options) end)}
    end

    # Private Functions

    defp init(procedure, params, options) do
      {:ok, caller} = RPC.new_peer([Spell.Role.Caller], options)
      %__MODULE__{caller: caller,
                  procedure: procedure,
                  params: params}
        |> struct(options)
        |> loop()
    end

    defp loop(state) do


      # `Spell.cast_call` performs an asyncronous call to the remote procedure, the result will 
      # be intercepted and parsed by the block `Spell.receive_result`
      {:ok, call_id} = Spell.cast_call(state.caller, state.procedure, state.params)
      Logger.info("<Caller: #{inspect(state.caller)}> send params: #{inspect(state.params)}")
      
      case Spell.receive_result(state.caller, call_id) do
        {:ok, result} -> IO.inspect handle_result(state, result)
        {:error, reason} -> {:error, reason}
      end

      :timer.sleep(1000)
      loop(state)
    end

    def handle_result(state, [_result_id, _options, _arguments, %{"result" => res}]) do
      Logger.info("<Caller: #{inspect(state.caller)}> received result: #{inspect(res)}")
    end
  end

  defmodule Callee do
    @moduledoc """
    The callee need to be registered to the WAMP Dealer in order to be accesseble and expose
    the procedure. Once it is registered it will wait an invocation from the Dealer and yield 
    the result back. in this case it will receive an array of integer `[1, 2, 3]` and return
    the sum of them `6`

    iex> Callee.start_link("com.spell.rpc.sum")
    """
    require Logger
    defstruct [:callee, :reg_id, timeout: 1000]

    # Public Functions

    @doc """
    Start the callee with the passed procedure.
    """
    def start_link(topics, options \\ []) do
      {:ok, spawn_link(fn -> init(topics, options) end)}
    end

    # Private Functions

    defp init(procedure, options) do
      {:ok, callee} = RPC.new_peer([Spell.Role.Callee], options)

      # `Spell.cast_register` receive the callee and the procedure where it
      # has to be registered
      {:ok, _reg_id} = Spell.cast_register(callee, procedure)

      %__MODULE__{callee: callee} |> struct(options) |> loop()
    end

    defp loop(state) do
      receive do
        :stop -> :ok
        {Spell.Peer, _pid, message} -> state = handle_message(state, message)
        _ -> {:error, :wrong_message}
      after
        state.timeout -> {:error, :timeout}
      end
      loop(state)
    end

    defp handle_message(state, %Spell.Message{args: [_request, reg_id], type: :registered}) do
      Logger.info("<Callee: #{inspect(state.callee)}> registered")
      %{state | reg_id: reg_id}
    end

    defp handle_message((%{callee: callee, reg_id: reg_id}) = state, %Spell.Message{args: [request, reg_id, _msg, params], type: :invocation}) do
      Logger.info("<Callee: #{inspect(callee)}> received #{inspect(params)} on #{reg_id}")
      Spell.cast_yield(callee, request, [arguments_kw: %{result: Math.sum(params, 0)}])
      state
    end
  end

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

defmodule Math do
  @doc """
  Module to provide some simple mathematic operation
  """
  def sum([], acc), do: acc
  def sum(int, acc) when is_integer(int), do: sum([int], acc)
  def sum([h | t] = list, acc) when is_list(list) and is_integer(h), do: sum(t, acc + h)
  def sum([h | t] = list, acc) when is_list(list), do: sum(t, acc + String.to_integer(h))
end

alias RPC.Callee
alias RPC.Caller
require Logger

Logger.info("Starting the Crossbar.io test server...")

# Start the crossbar testing server
{:ok, _pid} = Crossbar.start()

procedure_sum = "com.spell.rpc.sum"

# Register callee to the WAMP router
{:ok, _callee} = Callee.start_link(procedure_sum)

# Call the remote procedure passing the agruments
{:ok, _caller} = Caller.start_link(procedure_sum, [arguments: [1, 2, 3]])
:timer.sleep(10000)

Logger.info("DONE... Stopping Crossbar.io server")
# Stop the crossbar.io testing server
:ok = Crossbar.stop()

Logger.info("DONE.")
