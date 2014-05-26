# encoding: UTF-8
#

Thread.abort_on_exception = true

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
          header = read_data
          check_rpc_error!(header)
          if header['Seq'] == res.header.seq
            ev = read_data
            block.call(ev) if block
          else
            break
          end
        end
      end
      [res, t]
    end

    def monitor(loglevel = 'debug')
      request(:monitor, 'LogLevel' => loglevel.upcase)
    end

    def stop(sequence_number)
      tcp_send(:stop, 'Stop' => sequence_number)
    end

    def leave
      request(:leave)
    end

    def query(name, payload, opts = {}, &block)
      params = { 'Name' => name, 'Payload' => payload }
      params.merge!(opts)
      res = request(:query, params)
      loop do
        header = read_data
        check_rpc_error!(header)
        ev = read_data
        if ev['Type'] == 'done'
          break
        else
          block.call(ev) if block
        end
      end
      res
    end

    def respond(id, payload)
      request(:respond, 'ID' => id, 'Payload' => payload)
    end
  end
end
