defmodule Spell.Mixfile do
  use Mix.Project

  def project do
    [app: :spell,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  def application do
    [applications: [:logger, :gun, :poison]]
  end

  # TODO: allow transport/serialization deps to be filtered out
  defp deps do
    [
     # TODO: Get gun off the bleeding edge -- hex.pm?
     # Req'd by: `Spell.Transport.Websocket`
     {:gun, github: "ninenines/gun", branch: "master"},

     # Req'd by: `Spell.Serializer.JSON`
     {:poison, "~> 1.3.1"}
    ]
  end
end
