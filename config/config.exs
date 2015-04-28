use Mix.Config

config :logger,
  handle_otp_reports: true,
  handle_sasl_reports: true

config :logger, :console,
  level: :info

# Import env config

config_file = "#{Mix.env}.exs"
if Path.join("config", config_file) |> Path.expand |> File.exists? do
  import_config(config_file)
end
