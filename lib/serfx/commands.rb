# encoding: UTF-8

module Serfx
  # implements serf's rpc commands
  module Commands
    def event(name, payload = nil, coalesce = true)
      event = {
        'Name' => name,
        'Coalesce' => coalesce
      }
      event['Payload'] = payload unless payload.nil?
      request(:event, event)
    end

    def force_leave(node)
      request(:force_leave, 'Node' => node)
    end

    def join(existing, replay = false)
      request(:join, 'Existing' => existing, 'Replay' => replay)
    end

    def members
      request(:members)
    end

    def members_filtered(tags, status = 'alive', name = nil)
      filter = {
        'Tags' => tags,
        'Status' => status
        }
      filter['Name'] = name unless name.nil?
      request(:members_filtered, filter)
    end

    def tags(tags, delete_tags = [])
      request(:tags, 'Tags' => tags, 'DeleteTags' => delete_tags)
    end

    def stream(types, &block)
      res = request(:stream, 'Type' => types)
      t = Thread.new do
        loop do
          if socket.ready?
            unpacker = MessagePack::Unpacker.new(socket)
            header =  unpacker.read
            check_rpc_error!(header)
            body = unpacker.read
            new_event = Response.new(header, body)
            block.call(new_event) if block
          else
            sleep 0.1
          end
        end
      end
      [res, t]
    end

    def monitor(loglevel = 'debug')
      request(:monitor, 'LogLevel' => loglevel.upcase)
    end

    def stop(sequence_number)
      request(:stop, 'Stop' => sequence_number)
    end

    def leave
      request(:leave)
    end

    def query(name, payload, opts = nil)
      params = { 'Name' => name, 'Payload' => payload }
      params.merge!(opts)
      request(:query, params)
    end

    def respond(id, payload)
      request(:response, 'ID' => id, 'Payload' => payload)
    end
  end
end
