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

## Writing custom handlers

serf agents can be configured to invoke an executable script when an user event is received.

`Serfx::Utils::Handler` module provides a set of helper methods to ease writing ruby based serf event handlers. It wraps the data passed via serf into a convenient `SerfEvent` object, as well as provides observer like API where callbacks can be registered based on event name and type.

For example, following script will respond to any qury event named 'upcase' and return the uppercase version of the original query event's payload

```ruby
require 'serfx/utils/handler'

include Serfx::Utils::Handler

on :query, 'upcase' do |event|
  STDOUT.write(event.payload.upcase)
end

run
```

Assuming this event handler is configured with `upcase` user event (-event-handler 'query:upcase=/path/to/handler'), it can be used as:

```sh
serf query -no-ack upcase foo
Response from 'node1': FOO
```

## Managing long running tasks via serf handlers

Serf event handler invocations are blocking calls. i.e. serf
will not process any other event when a handler invocation is
in progress. Due to this, long running tasks should not be
invoked as serf handler directly.

AsyncJob helps buildng serf handlers that involve long running commands.
It starts the command in background, allowing handler code to
return immediately. It does double fork where the first child process is
detached (attached to init as parent process) and and the target long
running task is spawned as a second child process. This allows the first
child  process to wait and reap the output of actual long running task.

The first child process updates a state file before spawing
the long ranning task(state='invoking'), during the lon running task
execution (state='running') and after the spawned process' return
(state='finished'). This state file provides a convenient way to
query the current state of an AsyncJob.

AsyncJob provides four methods to manage jobs. AsyncJob#start will
start the task. Once started, `AyncJob#state_info` can be used to check
whether the job is still running or finished. One started a job can be
either in 'running' state or in 'finished' state. `AsyncJob#reap`
is used for deleting the state file once the task is finished.
An AsyncJob can be killed, if its in running state, using the
`AsyncJob#kill` method. A new AyncJob can not be started unless previous
AsyncJob with same name/state file is reaped.

```ruby
require 'serfx/utils/async_job'
require 'serfx/utils/handler'

include Serfx::Utils::Handler

job = Serfx::Utils::AsyncJob.new(
  name: "bash_test",
  command: "bash -c 'for i in `seq 1 300`; do echo $i; sleep 1; done'",
  state: '/opt/serf/states/long_task'
  )

on :query, 'bash_test' do |event|
  case event.payload
  when 'start'
    puts job.start
  when 'kill'
    puts job.kill
  when 'reap'
    puts job.reap
  when 'check'
    puts job.state_info
  else
    puts 'failed'
  end
end

run
```
Assuming this handler is configured with `bash_test` query events (-event-handler query:bash_test=/path/to/handler), it can be used as:

```sh
serf query bash_test start
serf query bash_test check # check if job is running or finished
serf query bash_test reap # delete a finished job's state file
serf query bash_test kill
```

## Specifying connection details
By default Serfx will try to connect to localhost at port 7373 (serf agent's default RPC port). Both `Serfx::Connection#new` as well as `Serfx.connect` accepts a hash specifying connection options i.e host, port, encryption, which can be used to specify non-default values.

```ruby
Serfx.client(host: 'serf1.example.com', port: 7373, authkey: 'secret')
```

## API documentation

[Detailed api documentation][api-doc] is accessible via rubydoc.
[api-doc]: http://rubydoc.info/gems/serfx

## Note
Currently the response of `members` RPC method returns the ipaddress of cluster members as byte array. You can use `unpack` method to convert it to string.

```ruby
Serfx.client(host: 'serf1.example.com') do |conn|
  response = conn.members
  puts response.body['Members'].first['Addr'] # first member's IP in bytes
  puts response.body['Members'].first['Addr'].unpack('CCCC').join('.') # Same as string
end
```

## Supported ruby versions

Serfx aims to support and is [tested against][serfx-travis] the following Ruby implementations:

* *Ruby 1.9.3*
* *Ruby 2.0.0*
* *Ruby 2.1.0*

[serfx-travis]: https://travis-ci.org/ranjib/serfx

## License
Copyright (c) 2014, PagerDuty

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
