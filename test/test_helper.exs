ExUnit.configure(exclude: [pending: true])
ExUnit.start(formatters: [ExUnit.CLIFormatter, Crossbar])

Mix.Tasks.Test.Integration.set_transport
Mix.Tasks.Test.Integration.set_serializer
