defmodule Mix.Tasks.Test.Integration do
  use Mix.Task

  def set_transport do
    Application.put_env(:spell, :transport, System.get_env("TRANSPORT"))
  end

  def set_serializer do
    Application.put_env(:spell, :serializer, System.get_env("SERIALIZER"))
  end

  def run(args) do
    args = if IO.ANSI.enabled?, do: ["--color"|args], else: ["--no-color"|args]
    args = ["test/integration" | args]

    for transport <- transport_list, serializer <- serializer_list do
      {_, res} = run_integration(args, transport: transport, serializer: serializer)

      if res > 0 do
        System.at_exit(fn _ -> exit({:shutdown, 1}) end)
      end
    end
  end

  defp transport_list, do: get_list_from_env("TRANSPORT", Spell.Config.available_transports)
  defp serializer_list, do: get_list_from_env("SERIALIZER", Spell.Config.available_serializers)

  defp run_integration(args, transport: transport, serializer: serializer) do
    IO.puts "==> Running integration tests for transport=#{transport}, serializer=#{serializer}"

    System.cmd "mix", ["test"|args],
                       into: IO.binstream(:stdio, :line),
                       env: [{"TRANSPORT", transport}, {"SERIALIZER", serializer}]
  end

  defp get_list_from_env(env_var, default_list) do
    case System.get_env(env_var) do
      "all" -> default_list
      nil -> default_list
      value -> [value]
    end
  end
end
