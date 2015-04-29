defmodule Spell.Mixfile do
  use Mix.Project

  def project do
    [app: :spell,
     version: "0.0.1",
     name: "Spell",
     source_url: "https://github.com/MyMedsAndMe/spell",
     elixir: "~> 1.0",
     deps: deps,
     aliases: aliases,
     docs: docs,
     preferred_cli_env: [test_unit: :test,
                         test_integration: :test,
                         docs: :doc]
    ]
  end

  def application do
    [applications: [:logger,
                    # :sasl,
                    :websocket_client,
                    :poison],
    mod: {Spell, []}]
  end

  # TODO: allow transport/serialization deps to be filtered out
  defp deps do
    [
     # Req'd by: `Spell.Transport.Websocket`
     {:websocket_client, github: "jeremyong/websocket_client", tag: "v0.7"},
     # Req'd by: `Spell.Serializer.JSON`
     {:poison, "~> 1.4.0"},
     # Doc deps
     {:earmark, "~> 0.1", only: :doc},
     {:ex_doc, "~> 0.7", only: :doc}
    ]
  end

  defp aliases do
    [test_unit: "test --exclude integration --exclude pending",
     test_integration: "test --only integration --exclude pending"]
  end

  defp docs do
    [
        # TODO: change markdown compiler to once that supports gfm
        #readme: "README.md"
    ]
  end
end
