# Spell

Spell is an [Elixir](http://elixir-lang.org/) [WAMP](http://wamp.ws/) client
implementing the
[basic profile](https://github.com/tavendo/WAMP/blob/master/spec/basic.md)
specification.

WAMP is an open standard WebSocket subprotocol that provides two application
messaging patterns in one unified protocol: Remote Procedure Calls + Publish
&amp; Subscribe.

## Documentation

See the source code documentation for example usage.

## Testing

To test Spell, you must have [crossbar](http://crossbar.io/) installed. Via
pip:

```shell
$ pip install crossbar
```

To run all tests:

```shell
$ mix test
```
