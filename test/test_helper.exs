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

    require Logger
    use GenEvent

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
    @spec get_port(atom) :: :inet.port
    def get_port(:websocket), do: 8080

    @doc """
    Return the crossbar host.
    """
    @spec get_host :: String.t
    def get_host, do: "localhost"

    @doc """
    ExUnit setup helper function.
    """
    def config(listener \\ :websocket)
    def config(listener), do: [host: get_host, port: get_port(listener)]

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
    def init(opts) do
      executable = Dict.get(opts, :executable, @crossbar_exec)
      arguments  = Dict.get(opts, :executable, @crossbar_args)
      Logger.debug("Starting crossbar: #{inspect([executable | arguments])}")
      port = Port.open({:spawn_executable, executable}, port_opts(arguments))
      # Wait for crossbar to start.
      # TODO: poll a listener or some such.
      :timer.sleep(400)
      {:ok, %__MODULE__{port: port,
                        executable: executable,
                        arguments: arguments}}
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

    def terminate({:error, :finished}, state) do
      Logger.debug("Terminating due to: finished")
    end


    # Private Functions

    @doc false
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

ExUnit.start(formatters: [TestHelper.Crossbar])
