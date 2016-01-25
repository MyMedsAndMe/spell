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
     deps: deps(Mix.env),
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

  defp deps(:prod) do
    [
     # Req'd by: `Spell.Authentication.CRA`
     {:pbkdf2, github: "pma/erlang-pbkdf2", branch: "master"}
    ]
  end

  defp deps(_) do
    deps(:prod) ++ [
      # Req'd by: `Spell.Transport.Websocket`
      {:websocket_client, github: "jeremyong/websocket_client", tag: "v0.7"},
      # Req'd by: `Spell.Serializer.JSON`
      {:poison, "~> 1.4"},
      # Req'd by: `Spell.Serializer.MessagePack`
      {:msgpax, "~> 0.7"},
      # Doc deps
      {:earmark, "~> 0.2", only: :doc},
      {:ex_doc, "~> 0.11", only: :doc}
    ]
  end

  defp aliases do
    examples = for {k, v} <- [pubsub: "pubsub.exs",
                              rpc: "rpc.exs",
                              auth: "auth/auth_service.exs"] do
      {:"spell.example.#{k}", "run examples/#{v}"}
    end
    ["test.all":  ["test.unit", "test.integration"],
     "test.unit": "test test/unit"] ++
      ["spell.example.all": Dict.keys(examples) |> Enum.map(&Atom.to_string/1)] ++
      examples
  end

  defp docs do
    [main: "overview",
     extras: ["README.md": [title: "Overview", path: "overview"]]]
  end
end
