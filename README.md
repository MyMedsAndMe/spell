# Spell

**WARNING** This software has not yet been tested in production, and it will
eat your pet.

Spell is an [Elixir](http://elixir-lang.org/) [WAMP](http://wamp.ws/) client
implementing the
[basic profile](https://github.com/tavendo/WAMP/blob/master/spec/basic.md)
specification.

Spell is

  - Sync and async calls: use what your problem calls for
  - Happy to manage many peers: peer processes are supervised, and
  will retry on connection failure, or restart on an error.
  - Easily extensible: add new roles, transports, or serializers without
  changing the core libary.

WAMP is an open standard WebSocket subprotocol that provides two application
messaging patterns in one unified protocol: Remote Procedure Calls + Publish
&amp; Subscribe.


## How it Works

The examples below are abbreviated; most functions can accept additonal keyword
arguments.

See Spell's source code documentation for more information:

```elixir
iex> h Spell
```

### PubSub

Once subscribed to a topic, the subscriber will receive all messages
published to the topic.

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

For simplicity's sake, let's start with the caller's half.

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

## Testing

To run Spell's integration tests, you must have [crossbar](http://crossbar.io/)
installed. Via pip:

```shell
$ pip install crossbar
```

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
