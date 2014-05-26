# Serfx

A bare minimal ruby client for [Serf][serf-homepage].

## Introduction

Serfx uses  Serf's [RPC protocol][rpc-protocol] under the hood. Serf RPC protocol involves communication with a local or remote serf agent over tcp using [msgpack][msgpack] for serialization.
Serf's RPC protocol mandates `handshake` (followed by `auth` if applicable) to be the first command(s) in an RPC session. Serfx exposes all the low level RPC commands via the `Connection` class, as well  a convenient `connect` method which creates a connection object and does the handshake, auth and connection closing for you.
If you are creating the `Serfx::Connection` directly, they you have to do the handshake (auth if applicable) and connection closing explicitly.
For example, the command `members` can be invoked as:

```ruby
Serfx.connect do |conn|
  conn.members
end
```
Which is equivalent to

```ruby
conn = Serfx::Connection.new
conn.handshake
conn.members
conn.close
```

[serf-homepage]: http://www.serfdom.io
[rpc-protocol]: http://www.serfdom.io/docs/agent/rpc.html
[msgpack]: http://msgpack.org

## Sending custom events
Serf allows creating user events. An user event must have a name and can have an optional payload.
Following will create an user event named `play` with payload `PinkFloyd`

```ruby
conn.event('play', 'PinkFloyd')
```

Serf agents can be configured to invoke arbtrary script as [event handlers][event-handlers]. When serf agents receive the `play` event thay'll invoke the corresponding handler(s) and pass the payload 'PinkFloyd' via standard input.
[event-handlers]: http://www.serfdom.io/docs/agent/event-handlers.html

## Query and response

Serf queries are special events that can be fired against a set of node(s) and the target node(s) can respond to aginst the queried event. Since Serf's event pipeline is asyn, every query event is timeboxed (by default 15s) and only those responses that are received within the timeout period is yield-ed. Following is an example will fire a query event name 'foo' with 'bar' payload and print the incoming responses from any node within the default timeout(15s).

```ruby
conn.query('foo', 'bar') do |response|
  p response
end
```

## Specifying connection details
By default Serfx will try to connect to localhost at port 7373 (serf agent's default RPC port). Both `Serfx::Connection#new` as well as `Serfx.connect` accepts a hash specifying connection options i.e host, port, encryption, which can be used to specify non-default values.

```ruby
Serfx.client(host: 'serf1.example.com', port: 7373, authkey: 'secret')
```

## API documentation

[Detailed api documentation][api-doc] is accessible via rubydoc.
[api-doc]: http://rubydoc.info/gems/serfx

## Supported ruby versions

Serfx aims to support and is [tested against][serfx-travis] the following Ruby implementations:

* *Ruby 1.9.2*
* *Ruby 1.9.3*
* *Ruby 2.0.0*
* *Ruby 2.1.0*

[serfx-travis]: https://travis-ci.org/ranjib/serfx

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
