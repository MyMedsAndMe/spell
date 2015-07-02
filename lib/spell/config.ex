defmodule Spell.Config do
  @moduledoc """
  This module helps to get the configurable modules from within Spell
  """

  def available_serializers, do: ["json", "msgpack"]
  def available_transports,  do: ["websocket", "rawsocket"]

  @doc """
  Gets the serializer module name
  """
  def serializer_name, do: Application.get_env(:spell, :serializer) || "json"

  @doc """
  Gets the serializer module
  """
  def serializer, do: serializer(serializer_name)

  def serializer("json"), do: Spell.Serializer.JSON
  def serializer("msgpack"), do: Spell.Serializer.MessagePack

  @doc """
  Gets the transport module name
  """
  def transport_name, do: Application.get_env(:spell, :transport) || "websocket"

  @doc """
  Gets the transport module
  """
  def transport, do: transport(transport_name)

  def transport("websocket"), do: Spell.Transport.WebSocket
  def transport("rawsocket"), do: Spell.Transport.RawSocket
end
