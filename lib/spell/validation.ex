defmodule Spell.Validation do

  alias Spell.Role

  @default_roles  [Role.Publisher,
                   Role.Subscriber,
                   Role.Caller,
                   Role.Callee]

  def get_role_options(options) do
    Dict.get(options, :roles, @default_roles)
    |> Role.normalize_role_options()
  end

  def serializer do
    Application.get_env(:spell, :serializer)
  end

  def session_options(options) do
    Keyword.take(options, [:realm, :authentication])
  end

  def build_message(options, role_options) do
    %{transport: Keyword.get(options, :transport),
      serializer: Keyword.get(options, :serializer, serializer),
      owner: Keyword.get(options, :owner),
      role: %{options: Keyword.put_new(role_options, Role.Session,
                                       session_options(options)),
              features: Keyword.get(options, :features,
                                    Role.collect_features(role_options))},
      realm: Keyword.get(options, :realm),
      retries: Keyword.get(options, :retries, @default_retries),
      retry_interval: Keyword.get(options, :retry_interval,
                               @default_retry_interval)}
  end

  @spec normalize_options(Keyword.t) :: tuple
  def normalize_options(options) when is_list(options) do
    case get_role_options(options) do
      {:ok, role_options} ->
        build_message(options, role_options)
        |> normalize_options()
      {:error, reason} -> {:error, {:role, reason}}
    end
  end

  def normalize_options(%{transport: nil}) do
    {:error, :transport_required}
  end

  def normalize_options(%{transport: transport_options} = options)
      when is_list(transport_options) do
    %{options | transport: %{module: @default_transport_module,
                             options: transport_options}}
      |> normalize_options()
  end

  def normalize_options(%{transport: transport_module} = options)
      when is_atom(transport_module) do
    %{options | transport: %{module: transport_module, options: options}}
      |> normalize_options()
  end

 def normalize_options(%{serializer: serializer_module} = options)
      when is_atom(serializer_module) do
    %{options | serializer: %{module: serializer_module, options: []}}
      |> normalize_options()
  end

  def normalize_options(%{realm: nil}) do
    {:error, :realm_required}
  end

  def normalize_options(%{transport: %{module: transport_module,
                                        options: transport_options},
                           serializer: %{module: serializer_module,
                                         options: serializer_options},
                           role: %{options: role_options},
                           realm: realm} = options)
      when is_atom(transport_module) and is_list(transport_options)
       and is_atom(serializer_module) and is_list(serializer_options)
       and is_list(role_options) and is_binary(realm) do
    {:ok, options}
  end

  def normalize_options(_options) do
    {:error, :bad_options}
  end

end
