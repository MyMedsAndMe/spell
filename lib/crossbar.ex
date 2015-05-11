defmodule Crossbar do
  @moduledoc """
  The `Crossbar` module provides commands for configuring, starting, and
  stopping the Crossbar server. You might want to use it for running tests or
  interactive development.

  Why does this module implement the `GenEvent` behavior? It can be hooked into
  the `ExUnit.EventManager`:

      ExUnit.start(formatters: [ExUnit.CLIFormatter, Crossbar])

  Useful for interactive development, the Crossbar.io server can be started by
  calling `start`:

      Crossbar.start()

  ## Crossbar.io Dependency

  This module requires the [Crossbar.io
  executable](http://crossbar.io/docs/Quick-Start/).  Via
  [pip](https://pypi.python.org/pypi/pip/):

      pip install crossbar

  """

  use GenEvent
  require Logger

  # Module Attributes

  @timeout       1000

  @crossbar_host "localhost"
  @crossbar_port 8080

  @crossbar_exec "/usr/local/bin/crossbar"
  @crossbar_priv Application.app_dir(:spell, "priv/.crossbar")
  @crossbar_args ["--cbdir", @crossbar_priv]

  # Structs

  defstruct [:port, executable: @crossbar_exec, arguments:  @crossbar_args]

  @typep t :: %__MODULE__{
             port:       Port.t,
             executable: String.t,
             arguments:  [String.t]}

  # Public Interface

  @doc """
  Add an event manager with the `Crossbar` handler to `Spell.Supervisor`.
  """
  @spec start(Keyword.t) :: {:ok, pid} | {:error, any}
  def start(options \\ config()) do
    import Supervisor.Spec
    Supervisor.start_child(Spell.Supervisor,
                           worker(__MODULE__, [options],
                                  restart: :transient,
                                  shutdown: 10000))
  end

  @doc """
  Stop the Crossbar.io server. This can only be used with `start/1`.
  """
  @spec stop() :: :ok | {:error, any}
  def stop() do
    GenEvent.stop(Crossbar)
    Supervisor.delete_child(Spell.Supervisor, Crossbar)
  end

  @doc """
  Start an event manager with the `Crossbar` handler.

  Stop the process with:

      GenEvent.stop(pid)
  """
  @spec start_link(Keyword.t) :: {:ok, pid} | {:error, any}
  def start_link(options \\ config()) do
    {:ok, pid} = GenEvent.start_link(name: __MODULE__)
    :ok = GenEvent.add_handler(pid, __MODULE__, [options])
    {:ok, pid}
  end


  @doc """
  Return the port which the crossbar transport is listening on.
  """
  @spec get_port(:websocket) :: :inet.port
  def get_port(:websocket) do
    8080
  end

  @doc """
  Return the crossbar host.
  """
  @spec get_host :: String.t
  def get_host, do: "localhost"

  @doc """
  Get the crossbar resource path.
  """
  @spec get_path(:websocket) :: String.t
  def get_path(:websocket), do: "/ws"

  @doc """
  ExUnit setup helper function.
  """
  def config(listener \\ :websocket) do
    [host: get_host, port: get_port(listener), path: get_path(listener)]
  end

  @doc """
  Get the config as a uri.
  """
  @spec uri(Keyword.t) :: String.t
  def uri(options \\ config()) do
    "ws://#{options[:host]}:#{options[:port]}#{options[:path]}"
  end

  @doc """
  Get the default realm.
  """
  @spec realm :: String.t
  def realm do
    "realm1"
  end

  # GenEvent Callbacks

  @doc """
  Initialize the GenEvent handler with opts.
  """
  @spec init(Keyword.t) :: {:ok, t} | {:error, term}
  def init(opts) do
    executable = Dict.get(opts, :executable, @crossbar_exec)
    arguments  = Dict.get(opts, :executable, @crossbar_args)
    Logger.debug("Starting crossbar: #{inspect([executable | arguments])}")
    port = Port.open({:spawn_executable, executable}, port_opts(arguments))
    # Wait for crossbar to start.
    case await do
      :ok ->
        Logger.debug("Crossbar started.")
        {:ok, %__MODULE__{port: port,
                          executable: executable,
                          arguments: arguments}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handle the `ExUnit.EventManager` events. When the test suite is
  finished stop the crossbar server.
  """
  def handle_event({:suite_finished, _, _}, state) do
    {msg, exit_code} =
      System.cmd(state.executable, ["stop" | state.arguments])
    Logger.debug("Exited crossbar [status: " <>
      "#{Integer.to_string(exit_code)}] -- #{inspect msg}")
    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  def handle_info({Spell.Transport.WebSocket, _pid,
                   {:terminating, {:remote, :closed}}}, _state) do
    # Remove the handler when receiving a remote closed message
    # Logger.debug(fn -> "Crossbar out: #{inspect(message)}" end)
    :remove_handler
  end

  def handle_info({port, {:data, message}}, %{port: port} = state) do
    # Handle the stdout data coming in from the port
    Logger.debug(fn -> "Crossbar.io stdout: #{inspect(message)}" end)
    {:ok, state}
  end

  def terminate(reason, state) do
    Logger.debug(fn -> "Crossbar.io terminating due to: #{reason}" end)
    handle_event({:suite_finished, nil, nil}, state)
  end

  # Private Functions

  @spec await(Keyword.t) :: :ok | {:error, :timeout | term}
  defp await(config \\ config(:websocket), interval \\ 250, retries \\ 40)
  defp await(_config, _interval, 0), do: {:error, :timeout}
  defp await(config, interval, retries) do
    case Spell.Transport.WebSocket.connect("json", config) do
      {:error, :econnrefused} ->
        # Flush the error message of the linked websocket crashing
        receive do
          {:EXIT, pid, :normal} when is_pid(pid) -> :ok
        after
          0 -> :ok
        end
        :timer.sleep(interval)
        await(config, interval, retries - 1)
      {:ok, _pid}      -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec port_opts([String.t]) :: Keyword.t
  defp port_opts(arguments) do
    [{:args, ["start" | arguments]},
     :binary,
     :use_stdio,
     :stderr_to_stdout]
  end
end
