# Spell

**Alpha Quality** though it's getting better quickly.

Spell is an [Elixir](http://elixir-lang.org/) [WAMP](http://wamp.ws/) client
implementing the
[basic profile](https://github.com/tavendo/WAMP/blob/master/spec/basic.md)
specification.

Why WAMP?

[WAMP](http://wamp.ws/) is the Web Application Message Protocol supported by
[Tavendo](http://tavendo.com/). It's an open standard WebSocket subprotocol that
provides two application messaging patterns in one unified protocol: Remote
Procedure Calls + Publish &amp; Subscribe.

Why Spell?

- Flexible interface: one line blocking calls or raw message handling -- use
whichever tool works best.
- Robust peers: peer processes are supervised, and will restart or retry when
appropriate.
- Easy to extend: add new roles, transports, or serializers without changing
the core libary:


Read up on the [pitfall](#pitfall) before using.

## How it Works

You can run the examples you're about to run into, though first you'll need
[crossbar.io](http://crossbar.io/). You might install it via pip:

```shell
$ pip install crossbar
```

Start an Elixir shell:

```bash
$ mix -S iex
```

<a href="#crossbar-install" \>Start up Crossbar.io:

```
Crossbar.start()
```

There's a bug in the Crossbar termination. You'll have to close the Crossbar.io
server from the shell. Something like:

```
pkill -f crossbar  # a bit dangerous
```

TODO: Create an issue for this.

You can find more detailed documentation at any time by checking
the source code documentation. `Spell` provides an entrypoint:

```elixir
iex> h Spell
```

Hit <kbd>C-c C-c</kdb> to exit the shell and shutdown Crossbar.

### Peers

In WAMP, messages are exchanged between peers. Peers are assigned a set of roles
which define how they handle messages. A client peer (Spell!) may have any
choice of client roles, and a server peer may have any choice of server roles.

There are two functional groupings of roles:

- PubSub
  - Publisher
  - Subscriber
  - Broker _Server_
- RPC
  - Caller
  - Callee
  - Dealer _[Server]_

See `Spell.Peer` and `Spell.Role`.


#### Pitfall

Spell has a very sharp edge at the moment. In line with it's Erlang socket
heritage, each peer has an owner, which the peer sends all WAMP related messages
to. As a result, if you call a synchronous function from a process which isn't
the target peer's owner, the calling process will never receive the message, the
command will timeout, and the owner process will receive an unexpected message.

TODO: Open an issue with ideas:

- error if a call is made by a process which isn't the subject peer's owner
- sending messages to appropriate owner

### PubSub

Once subscribed to a topic, the subscriber will receive all messages
published to that topic.

(TODO: cut this?) Note: The examples are abbreviated; most functions can accept
additonal keyword arguments.


```elixir
# Events must be published to a topic.
topic = "com.spell.example.pubsub.topic"

# Create a peer with the subscriber role.
subscriber = Spell.connect("ws://example.org/path",
                           realm: "example",
                           roles: [Spell.Role.Subscriber])

# `call_subscribe/2,3` synchronously subscribes to the topic.
{:ok, subscription} = Spell.call_subscribe(subscriber, topic)

# Create a peer with the publisher role.
publisher = Spell.connect("ws://example.org/path",
                           realm: "example"
                           roles: [Spell.Role.Publisher])

# `call_publish/2,3` synchronously publishes a message to the topic.
{:ok, publication} = Spell.call_publish(publisher, topic)

# `receive_event/2,3` blocks to receive the event.
case Spell.receive_event(publisher, subscription) do
  {:ok, event}     -> handle_event(event)
  {:error, reason} -> {:error, reason}
end

# Cleanup.
for peer <- [subscriber, publisher], do: Spell.close(peer)
```

See `Spell.Role.Publisher` and `Spell.Role.Subscriber` for more information.

### RPC

RPC allows a caller to call a procedure using a remote callee.

Let's start with the caller's half:

```elixir
realm = "realm"

# Calls are sent to a particular procedure.
procedure = "com.spell.example.rpc.procedure"

# Create a peer with the callee role.
caller = Spell.connect("ws://example.org/path",
                       realm: realm,
                       roles: [Spell.Role.Callee])

# `call_register/2,3` synchronously calls the procedure with the arguments.
{:ok, registration} = Spell.call(subscriber, procedure,
                                 arguments: ["args"],
                                 arguments_kw: %{})
```

In addition to the synchronous `Spell.call_...` type functions described so far,
Spell includes asynchronous `Spell.cast_...` functions. To handle the result of
these messages, either 

Next is a convoluted + contrived example showing managing both the caller and
the callee from a single process. Note how it uses the asynchronous casts and
receive functions to avoid a deadlock. They'll be useful if you'd like to use
Spell without blocking the calling process.

Note: I omitted the `arguments` and `arguments_kw` options for brevity's sake.

```elixir
realm = "realm"

# Calls are sent to a particular procedure.
procedure = "com.spell.example.rpc.procedure"

# Create a peer with the callee role.
callee = Spell.connect("ws://example.org/path",
                       realm: realm,
                       roles: [Spell.Role.Callee])

# `call_register/2,3` synchronously registers the procedure.
{:ok, registration} = Spell.call_register(subscriber, procedure)

# Create a peer with the caller role.
caller = Spell.connect("ws://example.org/path",
                       realm: realm,
                       roles: [Spell.Role.Caller])

# `cast_call/2,3` asynchronously calls the procedure.
{:ok, call} = Spell.cast_call(caller, procedure)

# `receive_invocation/2,3` blocks until it receives the call invocation.
{:ok, invocation} = Spell.receive_invocation(callee, call)

# `cast_yield/2,3` asynchronously yields the result back to the caller
:ok = Spell.cast_yield(callee, invocation.id, handle_invocation(invocation))

# `receive_event/2,3` blocks until timeout to receive the result.
case Spell.receive_result(publisher, call) do
  {:ok, result}    -> handle_result(result)
  {:error, reason} -> {:error, reason}
end

# Cleanup.
for peer <- [callee, caller], do: Spell.close(peer)
```


See `Spell.Role.Caller` and `Spell.Role.Callee` for more information.

### Adding New Roles

In Spell, Roles are middleware for handling messages. Technically they're most
similar to GenEvent handlers: callbacks which are hook into a manager. In this
case, the manager is a `Spell.Peer` process.

See `Spell.Role` for descriptions of the Role callbacks.

It's easy to get started:

```elixir
defmodule Broker do
  use Spell.Role

  def get_features(_options), do: {:broker, %{}}

  def handle_message(%Message{type: :publish} = message, peer, state) do
    publish(message, peer, state)
  end

  ... shamelessly skipping the real work.
end

Spell.Peer.connect(Crossbar.uri, realm: Crossbar.realm, roles: [Broker])
```

## Testing

To run Spell's integration tests, you must have
[crossbar installed](#crossbar-install).


To the tests:

```shell
$ mix test              # all tests
$ mix test_integration  # only integration tests
$ mix test_unit         # only unit tests
```

## Server-Side Peers ?

Spell implements peer roles through a middleware-esque framework. Only
client-side roles have been implemented, but it would be work equally
well for server-side roles, e.g. dealer and broker.
