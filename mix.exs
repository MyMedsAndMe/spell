defmodule Spell.Mixfile do
  use Mix.Project

  def project do
    [app: :spell,
     version: "0.1.0",
     name: "Spell",
     source_url: "https://github.com/MyMedsAndMe/spell",
     elixir: "~> 1.0",
     description: description,
     package: package,
     deps: deps,
     aliases: aliases,
     docs: docs,
     preferred_cli_env: ["test.all": :test,
                         "test.unit": :test,
                         "test.integration": :test,
                         "hex.docs": :doc,
                         docs: :doc]
    ]
  end

  def application do
    [applications: [:logger,
                    :websocket_client,
                    :poison,
                    :pbkdf2],
    mod: {Spell, []}]
  end

  defp description do
    """
    Spell is an extensible Elixir WAMP client. Spell supports the client
    subscriber, publisher, callee, and caller roles.
    """
  end

  defp package do
    [files: ["lib", "priv", "mix.exs", "README.md", "LICENSE"],
     contributors: ["Daniel Marín",
                    "Thomas Moulia",
                    "Claudio Ortolina",
                    "Volker Rabe",
                    "Marco Tanzi"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/MyMedsAndMe/spell"}]
  end

  # TODO: allow transport/serialization deps to be filtered out
  defp deps do
    [
     # Req'd by: `Spell.Transport.Websocket`
     {:websocket_client, github: "jeremyong/websocket_client", tag: "v0.7"},
     # Req'd by: `Spell.Serializer.JSON`
     {:poison, "~> 1.4.0"},
     # Req'd by: `Spell.Serializer.MessagePack`
     {:msgpax, "~> 0.7"},
     # Req'd by: `Spell.Authentication.CRA`
     {:pbkdf2, github: "pma/erlang-pbkdf2", branch: "master"},
     # Doc deps
     {:earmark, "~> 0.1", only: :doc},
     {:ex_doc, "~> 0.7", only: :doc}
    ]
  end

  defp aliases do
    ["test.all": ["test.unit", "test.integration"],
     "test.unit":        "test test/unit",
     "spell.example.pubsub": "run examples/pubsub.exs",
     "spell.example.rpc":    "run examples/rpc.exs",
     "spell.example.auth":   "run examples/auth/auth_service.exs"]
  end

  defp docs do
    [
        # TODO: change markdown compiler to once that supports gfm
        #readme: "README.md"
    ]
  end
end
