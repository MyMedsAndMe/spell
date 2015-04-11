defmodule Spell do
  @moduledoc """
  The `Spell` application is a basic WAMP client.

  Spell is

   * Easily extensible
   * Happy to manage many peers

  ## WAMP Support

  Spell supports the
  [basic WAMP profile, RC4](https://github.com/tavendo/WAMP/blob/master/spec/basic.md).

  TODO -- explain what this entails

  Client Roles:

   - Publisher
   - Subscriber
   - Caller
   - Callee

  ## Examples

  TODO

  """
  use Application

  # Module Attributes

  @supervisor_name __MODULE__.Supervisor

  # Public API



  # Application Callbacks

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [supervisor(Spell.Peer, [])]
    opts     = [strategy: :one_for_one, name: @supervisor_name]
    Supervisor.start_link(children, opts)
  end

end
