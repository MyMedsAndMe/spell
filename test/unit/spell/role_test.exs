defmodule Spell.RoleTest do
  use ExUnit.Case
  alias Spell.Role

  defmodule DefaultRole do
    use Spell.Role
  end

  test "default role functions" do
    assert nil == DefaultRole.get_features(:options)
    assert {:ok, :options} == DefaultRole.init(:peer_options, :options)
    assert {:ok, :state} == DefaultRole.on_open(nil, :state)
    assert {:ok, :state} == DefaultRole.on_close(nil, :state)
    assert {:ok, :state} == DefaultRole.handle_message(nil, nil, :state)
  end

  test "collect_features/1 with nil" do
    assert %{} == Role.collect_features([{DefaultRole, []}])
  end


  defmodule MapRole do
    use Spell.Role

    def get_features(options), do: {:map_role, %{options: options}}

    def init(_peer_options, role_options) do
      case Dict.fetch(role_options, :map) do
        {:ok, config} -> {:ok, config}
        :error        -> {:error, :no_map}
      end
    end

    def on_open(_peer, :error), do: {:error, :reason}
    def on_open(_peer, state),  do: {:ok, {:opened, state}}

    def on_close(_peer, :error), do: {:error, :reason}
    def on_close(_peer, state),  do: {:ok, {:closed, state}}

    def handle_message(_message, _peer, :error), do: {:error, :reason}
    def handle_message(message, _peer, state) do
      {:ok, {:messaged, message, state}}
    end

    def handle_call(message, _from, _peer, state) do
      {:ok, {:called, message}, state}
    end
  end

  test "collect_features/1" do
    assert %{map_role: %{options: [map: :opts]}} ==
      Role.collect_features([{MapRole, [map: :opts]}])
  end

  test "map_init/1" do
    assert {:ok, [{MapRole, :opts}]} ==
      Role.map_init([{MapRole, [map: :opts]}], [])
    assert {:ok, [{MapRole, :opts_a}, {MapRole, :opts_b}]} ==
      Role.map_init([{MapRole, [map: :opts_a]},
                     {MapRole, [map: :opts_b]}],
                    [])
    assert {:error, {{MapRole, []}, :no_map}} ==
      Role.map_init([{MapRole, []}], [])
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

  test "map_handle_message/3" do
    assert {:ok, [{Spell.RoleTest.MapRole, {:messaged, :msg, :state}}]} ==
      Role.map_handle_message([{MapRole, :state}], :msg, :peer)
  end

  test "call/5" do
    assert {:error, :no_role} == Role.call([], :role, :message, self(), :peer)
    assert {:ok, {:called, :message}, [{Spell.RoleTest.MapRole, :state}]} ==
      Role.call([{MapRole, :state}], MapRole, :message, self(), :peer)
  end

end
