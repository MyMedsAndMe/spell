# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [0.1.0] - 2015-09-14

### Added

- [RawSocket transport](https://github.com/tavendo/WAMP/blob/master/spec/advanced/rawsocket-transport.md)
- [Session authentication](https://github.com/tavendo/WAMP/blob/master/spec/advanced/authentication.md) with examples
- Example for RPC calls
- Msgpack serializer
- Testing matrix for transport/serializer combinations
- [Pattern based subscriptions](https://github.com/tavendo/WAMP/blob/master/spec/advanced/pattern-based-subscription.md)

### Changed

- Configurable timeouts for session, hello, and goodbye

### Fixed

- Seed passwords using `:crypto.rand_bytes` to avoid forced clock skew
