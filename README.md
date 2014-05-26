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
## Versioning
## License
