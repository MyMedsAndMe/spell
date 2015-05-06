defmodule Spell.Message do
  @moduledoc """
  The `Spell.Message` module defines the struct and functions to
  back WAMP messages.

  Note that these are distinct from Erlixir's messages.
  """
  # Module Attributes
  defstruct [:type, :code, :args]

  @basic_codes [hello:        1,
                welcome:      2,
                abort:        3,
                challenge:    4,
                authenticate: 5,
                goodbye:      6,
                error:        8,
                publish:      16,
                published:    17,
                subscribe:    32,
                subscribed:   33,
                unsubscribe:  34,
                unsubscribed: 35,
                event:        36,
                call:         48,
                cancel:       49,
                result:       50,
                register:     64,
                registered:   65,
                unregister:   66,
                unregistered: 67,
                invocation:   68,
                interrupt:    69,
                yield:        70]

  # Type Specs

  # TODO - these types are probably an over-abstraction. cut?
  @typep type :: atom | nil
  @typep args :: args

  # Message Datatypes
  @type wamp_type ::
      wamp_integer
    | wamp_string
    | wamp_bool
    | wamp_dict
    | wamp_list
    | wamp_id
    | wamp_uri

  @type wamp_integer :: integer      # non-negative
  @type wamp_string  :: String.t
  @type wamp_bool    :: boolean
  @type wamp_id      :: wamp_integer # see id
  @type wamp_uri     :: wamp_string  # see uri
  @type wamp_list    :: List.t(wamp_type)
  @type wamp_dict    :: Dict.t(wamp_string, wamp_type)

  @type new_error    :: :type_code_missing
                      | :type_code_mismatch
                      | {:args, :not_list}
                      | {:code, :out_of_range | :bad_value}

  @type t :: %__MODULE__{
    type: type,
    code: integer,
    args: args}

  # Public Functions

  @doc """
  Returns a new message, or raises an exception.

  ## Options

  See `new/1`.
  """
  @spec new!(Keyword.t) :: t
  def new!(options) do
    # `:_unknown` is used to prevent conflicts with existing types
    case new(options) do
      {:ok, message} ->
        message
      {:error, :type_code_missing} ->
        raise ArgumentError, message: ":type or :code must be present"
      {:error, :type_code_mismatch} ->
        raise ArgumentError, message: ":type is not consistent with `code`"
      {:error, {:code, :out_of_range}} ->
        raise ArgumentError, message: ":code is out of range [0 - 1024]"
      {:error, {:code, :bad_value}} ->
        raise ArgumentError, message: "bad value for :code"
      {:error, {:args, :not_list}} ->
        raise ArgumentError, message: ":args must be a list"
    end
  end

  @doc """
  Returns a new message.

  ## Options

  There is a one to one mapping between `type` and `code`. Either `type` or
  `code` must be provided. If both are provided, they must be consistent.

   * `type :: atom` the name of the message type. If `type` isn't provided,
     it is be set by `get_type_for_integer(code)`.
   * `code :: integer` the integer code for the message type. If `code` isn't
     isn't provided it is set by `get_integer_for_type(type)`. `type` must
     have a valid code.
   * `args :: [wamp_type]` defaults to `[]`, the list of message arguments.
  """
  @spec new([type: type, code: integer, args: [wamp_type]]) ::
    {:ok, t} | {:error, new_error}
  def new(options) do
    new(Dict.get(options, :type, :_unknown),
        Dict.get(options, :code, :_unknown),
        Dict.get(options, :args, []))
  end

  @spec new(type    | nil | :_unkown,
            integer | nil | :_unkown,
            [wamp_type]) :: {:ok, t} | {:error, new_error}
  defp new(:_unknown, :_unknown, _args) do
    {:error, :type_code_missing}
  end
  defp new(:_unknown, code, args) do
    new(get_type_for_code(code), code, args)
  end
  defp new(type, :_unknown, args) do
    new(type, get_code_for_type(type), args)
  end
  defp new(_type, _code, args) when not is_list(args) do
    {:error, {:args, :not_list}}
  end
  defp new(_type, nil, _args) do
    {:error, {:code, :bad_value}}
  end
  defp new(_type, code, _args) when code < 1 or code > 1024 do
    {:error, {:code, :out_of_range}}
  end
  defp new(type, code, args) do
    if code == get_code_for_type(type) do
      {:ok, %__MODULE__{type: type, code: code, args: args}}
    else
      {:error, :type_code_mismatch}
    end
  end

  @doc """
  Return a new WAMP id.
  """
  @spec new_id :: integer
  def new_id do
    (:math.pow(2, 53) |> round |> :random.uniform) - 1
  end

  @doc """
  Get the `code` for the message `type`.
  """
  @spec get_code_for_type(type, default) :: integer | nil | default
    when default: any
  def get_code_for_type(type, default \\ nil)
  for {type, code} <- @basic_codes do
      def get_code_for_type(unquote(type), _default), do: unquote(code)
  end
  def get_code_for_type(_, default), do: default

  @doc """
  Get the message `type` for `code`.
  """
  @spec get_type_for_code(integer, default) :: type | nil | default
    when default: any
  def get_type_for_code(type, default \\ nil)
  for {type, code} <- @basic_codes do
    def get_type_for_code(unquote(code), _default), do: unquote(type)
  end
  def get_type_for_code(_, default), do: default

end
