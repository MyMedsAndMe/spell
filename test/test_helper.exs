ExUnit.configure(exclude: [pending: true])
ExUnit.start(formatters: [ExUnit.CLIFormatter, Crossbar])

serializers = %{
  "json" => Spell.Serializer.JSON,
  "msgpack" => Spell.Serializer.MessagePack
}
serializer = case Map.get(serializers, System.get_env("SERIALIZER")) do
  nil -> Application.get_env(:spell, :serializer, Spell.Serializer.JSON)
  name -> name
end

Application.put_env(:spell, :serializer, serializer)
