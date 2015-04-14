defmodule Spell.Mixfile do
  use Mix.Project

  def project do
    [app: :spell,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  def application do
    [applications: [:logger, :websocket_client, :poison]]
  end

  # TODO: allow transport/serialization deps to be filtered out
  defp deps do
    [
     # Req'd by: `Spell.Transport.Websocket`
     {:websocket_client, github: "jeremyong/websocket_client", tag: "v0.7"},

     # Req'd by: `Spell.Serializer.JSON`
     {:poison, "~> 1.3.1"}
    ]
  end
end
