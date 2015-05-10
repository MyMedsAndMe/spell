defmodule Spell.Serializer.MessagePack do
  @behaviour Spell.Serializer
  alias Spell.Message

  # Serializer Callbacks

  def name, do: "msgpack"

  def frame_type, do: :binary

  def decode(string) do
    case Msgpax.unpack(string) do
      {:ok, [code | args]} ->
        {:ok, Message.new!(code: code, args: args)}
      {:ok, _other} ->
        {:error, :bad_message}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def encode(%Message{code: code, args: args}) do
    case Msgpax.pack([code | args]) do
      {:ok, enc_message} ->
        {:ok, :erlang.iolist_to_binary(enc_message)}
      {:error, reason} ->
        {:error, reason}
    end
  end

end
