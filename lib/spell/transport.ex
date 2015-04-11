defprotocol Spell.Transportable do

  @type t :: term

  @doc """
  Set the pid which the transport should send received messages to.

  Once connected, The transport must send all messages it receives to
  the owner process. See `Spell.Transport.send/2`.
  """
  @spec connect(t, Keyword.t, pid) :: :ok | {:error, term}
  def connect(transport, opts, owner)

  @doc """
  Send a raw message over the transport.
  """
  @spec send(t, String.t) :: :ok
  def send(t, raw_message)

end
