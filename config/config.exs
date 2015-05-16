use Mix.Config

log_level = :info

config :spell,
  serializer: Spell.Serializer.JSON

config :logger,
  # handle_otp_reports: true,
  # handle_sasl_reports: true,
  level: log_level

config :logger, :console,
  level: log_level

# Import env config

config_file = "#{Mix.env}.exs"
if Path.join("config", config_file) |> Path.expand |> File.exists? do
  #import_config(config_file)
end
