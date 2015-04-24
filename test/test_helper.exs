defmodule TestHelper do
  @moduledoc """
  The `TestHelper` module is avaliable to all tests.
  """

  defmodule Crossbar do
    @moduledoc """
    The `TestHelper.Crossbar` module integrates the crossbar server with
    ExUnit. It is meant to be hooked into the `ExUnit.EventManager`.

    Requires the [crossbar executable](http://crossbar.io/docs/Quick-Start/).
    Via [pip](https://pypi.python.org/pypi/pip/):

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
    Return the port which the crossbar transport is listening on.
    """
    @spec get_port(:websocket) :: :inet.port
    def get_port(:websocket), do: 8080

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
    def get_uri(config) do
      "ws://#{config[:host]}:#{config[:port]}#{config[:path]}"
    end

    @doc """
    Stop the crossbar server.

    This is a synchronous call.
    """
    @spec stop(pid) :: :ok | {:error, :timeout}
    def stop(pid) do
      monitor_ref = Process.monitor(pid)
      Process.exit(pid, :normal)
      receive do
        {:DOWN, ^monitor_ref, _type, ^pid, _info} -> :ok
      after
        @timeout -> {:error, :timeout}
      end
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

    def handle_info(info, state) do
      Logger.debug("Info: #{inspect info}")
      {:ok, state}
    end

    def terminate({:error, :finished}, _state) do
      Logger.debug("Terminating due to: finished")
    end

    # Private Functions

    @spec await(Keyword.t) :: :ok | {:error, :timeout | term}
    defp await(config \\ config(:websocket), interval \\ 250, retries \\ 40)
    defp await(_config, _interval, 0), do: {:error, :timeout}
    defp await(config, interval, retries) do
      case Spell.Transport.WebSocket.connect("json", config) do
        {:error, :econnrefused} ->
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
       :stderr_to_stdout,
       {:packet, 2}]
    end

  end
end

ExUnit.start(formatters: [ExUnit.CLIFormatter, TestHelper.Crossbar])
