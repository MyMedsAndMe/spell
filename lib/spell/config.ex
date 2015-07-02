defmodule Spell.Config do
  @moduledoc """
  This module helps to get the configurable modules from within Spell
  """
  @doc """
  Gets the serializer module
  """
  def serializer do
    serializer(Application.get_env(:spell, :serializer))
  end

  def serializer(nil), do: serializer("json")
  def serializer("json"), do: Spell.Serializer.JSON
  def serializer("msgpack"), do: Spell.Serializer.MessagePack

  @doc """
  Gets the transport module
  """
  def transport do
    transport(Application.get_env(:spell, :transport))
  end

  def transport(nil), do: transport("websocket")
  def transport("websocket"), do: Spell.Transport.WebSocket
  def transport("rawsocket"), do: Spell.Transport.RawSocket
end
