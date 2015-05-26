defmodule Mix.Tasks.Test.Integration do
  use Mix.Task

  @available_transports  ["web_socket", "raw_socket"]
  @available_serializers ["json", "msgpack"]

  def transport_module(nil), do: transport_module("web_socket")
  def transport_module("web_socket"), do: Spell.Transport.WebSocket
  def transport_module("raw_socket"), do: Spell.Transport.RawSocket

  def serializer_module(nil), do: serializer_module("json")
  def serializer_module("json"), do: Spell.Serializer.JSON
  def serializer_module("msgpack"), do: Spell.Serializer.MessagePack

  def set_transport do
    Application.put_env(:spell, :transport, transport_module(System.get_env("TRANSPORT")))
  end

  def set_serializer do
    Application.put_env(:spell, :serializer, serializer_module(System.get_env("SERIALIZER")))
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

  defp transport_list do
    case System.get_env("TRANSPORT") do
      transport when transport in @available_transports -> [transport]
      "all" -> @available_transports
      nil -> @available_transports
    end
  end

  defp serializer_list do
    case System.get_env("SERIALIZER") do
      serializer when serializer in @available_serializers -> [serializer]
      "all" -> @available_serializers
      nil -> @available_serializers
    end
  end

  defp run_integration(args, transport: transport, serializer: serializer) do
    IO.puts "==> Running integration tests for transport=#{transport}, serializer=#{serializer}"

    System.cmd "mix", ["test"|args],
                       into: IO.binstream(:stdio, :line),
                       env: [{"TRANSPORT", transport}, {"SERIALIZER", serializer}]
  end
end
