defmodule Spell.RoleTest do
  use ExUnit.Case
  alias Spell.Role

  defmodule DefaultRole do
    use Spell.Role
  end

  test "default role functions" do
    assert DefaultRole.init(:options) == {:ok, :options}
    assert DefaultRole.on_open(nil, :state) == {:ok, :state}
    assert DefaultRole.on_close(nil, :state) == {:ok, :state}
    assert DefaultRole.handle(nil, nil, :state) == {:ok, :state}
  end

  defmodule MapRole do
    use Spell.Role

    def init(options) do
      case Dict.fetch(options, :map) do
        {:ok, config} -> {:ok, config}
        :error        -> {:error, :no_map}
      end
    end

    def on_open(_peer, :error), do: {:error, :reason}
    def on_open(_peer, state),  do: {:ok, {:opened, state}}

    def on_close(_peer, :error), do: {:error, :reason}
    def on_close(_peer, state),  do: {:ok, {:closed, state}}

    def handle(_message, _peer, :error), do: {:error, :reason}
    def handle(message, _peer, state) do
      {:ok, {:messaged, message, state}}
    end
  end

  test "map_init/1" do
    assert {:ok, [{MapRole, :opts}]} ==
      Role.map_init([{MapRole, [map: :opts]}])
    assert {:ok, [{MapRole, :opts_a}, {MapRole, :opts_b}]} ==
      Role.map_init([{MapRole, [map: :opts_a]}, {MapRole, [map: :opts_b]}])
    assert {:error, {{MapRole, []}, :no_map}} ==
      Role.map_init([{MapRole, []}])
  end

  test "map_on_open/2" do
    assert {:ok, [{Spell.RoleTest.MapRole, {:opened, :state}}]} ==
      Role.map_on_open([{MapRole, :state}], :peer)
    assert {:error, {{Spell.RoleTest.MapRole, :error}, :reason}} ==
      Role.map_on_open([{MapRole, :error}], :peer)
  end

  test "map_on_close/2" do
    assert {:ok, [{Spell.RoleTest.MapRole, {:closed, :state}}]} ==
      Role.map_on_close([{MapRole, :state}], :peer)
    assert {:error, {{Spell.RoleTest.MapRole, :error}, :reason}} ==
      Role.map_on_close([{MapRole, :error}], :peer)
  end

  test "map_handle/3" do
    assert {:ok, [{Spell.RoleTest.MapRole, {:messaged, :msg, :state}}]} ==
      Role.map_handle([{MapRole, :state}], :msg, :peer)
  end

end
