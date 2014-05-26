# Serfx
A bare minimal ruby client for [serf](http://www.serfdom.io/) [RPC protocol](http://www.serfdom.io/docs/agent/rpc.html)
## Introduction
Serf RPC protocol involves communication with a local or remote serf agent over tcp using [msgpack](http://msgpack.org/) for serialization. Serf's RPC protocol also mandates `handshake` (followed by `auth` if applicable) to be the first command(s) in an RPC session. Seefx exposes all the low level RPC commands via the Connection class.
The main Serfx module also offers a convenient `connect` method which creates a connection object, performs the handshake (and auth if applicable), yield the connetcion object and closes the connection afterwards.
If you are creating the `Serfx::Connection` directly, they you have to do the handshake (auth if applicable) and connection closing explicitly.

- Following will create an user event named 'play' with payload `PinkFloyd`
```ruby
Serfx.connect do |conn|
  conn.event('play', 'PinkFloyd')
end

```
Which is equivalent to
```ruby
conn = Serfx::Connection.new
conn.handshake
conn.event('play', 'PinkFloyd')
conn.close
```
## Sending custom events

## Query and response

## Writing handlers

## Managing long running tasks

## API

```ruby
conn.handshake
conn.auth
conn.event
conn.force_leave
conn.join
conn.members_filtered
conn.tags
conn.stream
conn.stop
conn.query
conn.respond
```
## Supported ruby versions
Serfx aims to support and is [tested against](https://travis-ci.org/ranjib/serfx) the following Ruby implementations:
* Ruby 1.9.2
* Ruby 1.9.3
* Ruby 2.0.0
* Ruby 2.1.0

## Versioning
Serfx adhere's to [Semantic Versioning 2.0.0](http://semver.org/).

## License
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
