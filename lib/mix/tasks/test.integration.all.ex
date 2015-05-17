defmodule Mix.Tasks.Test.Integration do
  use Mix.Task

  @available_serializers ["json", "msgpack"]

  def serializer_module(nil), do: serializer_module("json")
  def serializer_module("json"), do: Spell.Serializer.JSON
  def serializer_module("msgpack"), do: Spell.Serializer.MessagePack

  def set_serializer do
    Application.put_env(:spell, :serializer, serializer_module(System.get_env("SERIALIZER")))
  end

  def run(args) do
    args = if IO.ANSI.enabled?, do: ["--color"|args], else: ["--no-color"|args]
    args = ["test/integration" | args]

    for serializer <- serializer_list do
      {_, res} = run_integration(args, serializer: serializer)

      if res > 0 do
        System.at_exit(fn _ -> exit({:shutdown, 1}) end)
      end
    end
  end

  defp serializer_list do
    case System.get_env("SERIALIZER") do
      serializer when serializer in @available_serializers -> [serializer]
      "all" -> @available_serializers
      nil -> @available_serializers
    end
  end

  defp run_integration(args, serializer: serializer) do
    IO.puts "==> Running integration tests for serializer=#{serializer}"

    System.cmd "mix", ["test"|args],
                       into: IO.binstream(:stdio, :line),
                       env: [{"SERIALIZER", serializer}]
  end
end
