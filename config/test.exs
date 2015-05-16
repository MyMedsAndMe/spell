use Mix.Config

config :spell,
  serializer: Spell.Serializer.MessagePack

config :logger,
  log_level: :warning,
  backends: []
