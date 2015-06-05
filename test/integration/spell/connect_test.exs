defmodule Spell.ConnectTest do
  use ExUnit.Case

  @transport  Application.get_env(:spell, :transport)
  @serializer Application.get_env(:spell, :serializer)
  @bad_host   "192.168.100.100"
  @bad_uri    "ws://" <> @bad_host

  setup do: {:ok, Crossbar.get_config()}

  test "connecting the transport", %{host: host, port: port, path: path} do
    assert {:error, {:missing, keys}} =
      @transport.connect(@serializer, [])
    assert :host in keys

    {:ok, transport} =
      @transport.connect(@serializer, host: host, port: port, path: path)
    assert transport
  end

  test "connecting the transport to a bad host" do
    assert {:error, reason} =
      @transport.connect(@serializer, host: @bad_host, port: 80)
    assert reason in [:timeout, :enetunreach],
      "the reason is timeout if the network is available, enetunreach if not"
  end

  test "connecting the peer to a bad host" do
    {:error, reason} = Spell.connect(@bad_uri,
                                     realm: Crossbar.get_realm(),
                                     retries: 1)
    assert reason in [:timeout, :enetunreach],
      "the reason is timeout if the network is available, enetunreach if not"
  end


end
