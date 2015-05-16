ExUnit.configure(exclude: [pending: true])
ExUnit.start(formatters: [ExUnit.CLIFormatter, Crossbar])

Application.put_env(:spell, :serializer, Spell.Serializer.MessagePack)
IO.puts "Serializer: #{Application.get_env(:spell, :serializer)}"
