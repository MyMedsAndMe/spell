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
  require EEx

  # Module Attributes

  @timeout       1000

  @crossbar_host "localhost"
  @crossbar_port 8080

  @crossbar_exec "/usr/local/bin/crossbar"
  @crossbar_path Application.app_dir(:spell, ".crossbar")
  @crossbar_args ["--cbdir", @crossbar_path]
  @crossbar_template Application.app_dir(:spell, "priv/config.json.eex")

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
  def start(options \\ get_config()) do
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
  def start_link(options \\ get_config()) do
    {:ok, pid} = GenEvent.start_link(name: __MODULE__)
    :ok = GenEvent.add_handler(pid, __MODULE__, [options])
    {:ok, pid}
  end


  @doc """
  Return the port which the crossbar transport is listening on.

  The default value of `8080` can be overrode using the environment
  variable `CROSSBAR_PORT`.
  """
  @spec get_port(:websocket) :: :inet.port
  def get_port(:websocket) do
    case System.get_env("CROSSBAR_PORT") do
      nil -> 8080
      port when is_binary(port) -> String.to_integer(port)
    end
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
  def get_config(listener \\ :websocket) do
    [host: get_host(),
     port: get_port(listener),
     path: get_path(listener),
     realm: get_realm()]
  end

  @doc """
  Get the config as a uri.
  """
  @spec uri(Keyword.t) :: String.t
  def uri(options \\ get_config()) do
    "ws://#{options[:host]}:#{options[:port]}#{options[:path]}"
  end

  @doc """
  Hack to get the auth uri.

  TODO: support this as part of templating out the config file.
  """
  @spec uri_auth(Keyword.t) :: String.t
  def uri_auth(options \\ get_config()) do
    uri(options) <> "_auth"
  end

  @doc """
  Get the default realm.
  """
  @spec get_realm :: String.t
  def get_realm do
    "realm1"
  end

  @doc """
  Create the Crossbar.io config dir for `config`.

  ## Options

   * `:crossbar_path :: String.t` the path to the Crossbar.io config directory.

  See `get_config/0` for other options.
  """
  def create_config(config \\ []) do
    {path, config} = Dict.pop(config, :crossbar_path, @crossbar_path)
    case File.mkdir_p(path) do
      :ok ->
        json_config = Dict.merge(get_config(), config)
          |> template_config()
        Path.join(path, "config.json")
          |> File.write(json_config)
      {:error, reason} ->
        {:error, reason}
    end
  end

  # GenEvent Callbacks

  @doc """
  Initialize the GenEvent handler with opts.
  """
  @spec init(Keyword.t) :: {:ok, t} | {:error, term}
  def init(opts) do
    :ok = create_config()
    executable = Dict.get(opts, :executable, @crossbar_exec)
    arguments  = Dict.get(opts, :arguments, @crossbar_args)
    Logger.debug(fn ->
      command = Enum.intersperse([executable, "start" | arguments], " ")
      ["Starting crossbar: ", command]
    end)
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

  def handle_info({:EXIT, _pid, :normal}, state) do
    # Swallow the notification of a websocket connection dying
    {:ok, state}
  end

  def terminate(reason, state) do
    Logger.debug(fn -> "Crossbar.io terminating due to: #{reason}" end)
    handle_event({:suite_finished, nil, nil}, state)
  end

  # Private Functions

  # Template out a crossbar config file
  EEx.function_from_file :defp, :template_config, @crossbar_template, [:assigns]

  @spec await(Keyword.t) :: :ok | {:error, :timeout | term}
  defp await(config \\ get_config(:websocket), interval \\ 250, retries \\ 40)
  defp await(_config, _interval, 0), do: {:error, :timeout}
  defp await(config, interval, retries) do
    case Spell.Transport.WebSocket.connect(Application.get_env(:spell, :serializer), config) do
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
