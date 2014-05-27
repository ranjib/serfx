# encoding: UTF-8
#
require 'thread'

Thread.abort_on_exception = true

module Serfx
  # Implements all of Serf's rpc commands using
  # Serfx::Connection#request method
  module Commands

    # performs initial hanshake of an RPC session. Handshake has to be the
    # first command to be invoked during an RPC session.
    #
    # @return  [Response]
    def handshake
      tcp_send(:handshake, 'Version' => 1)
      read_response(:handshake)
    end

    # authenticate against the serf agent. if RPC credentials are setup, then
    # `auth` has to be second command, immediately after `handshake`.
    #
    # @return  [Response]
    def auth
      tcp_send(:auth, 'AuthKey' => @authkey)
      read_response(:auth)
    end
    # fires an user event
    #
    # @param name [String] a string representing name of the event
    # @param payload [String] payload, default is nil
    # @param coalesce [Boolena] whether serf should coalesce events within
    # same name during  similar time frame
    # @return  [Response]
    def event(name, payload = nil, coalesce = true)
      event = {
        'Name' => name,
        'Coalesce' => coalesce
      }
      event['Payload'] = payload unless payload.nil?
      request(:event, event)
    end

    # force a failed node to leave the cluster
    # 
    # @param node [String] name of the failed node
    # @return  [Response]
    def force_leave(node)
      request(:force_leave, 'Node' => node)
    end
    
    # join an existing cluster.
    #
    # @param existing [Array] an array of existing serf agents
    # @param replay [Boolean] Whether events should be replayed upon joining
    # @return  [Response]
    def join(existing, replay = false)
      request(:join, 'Existing' => existing, 'Replay' => replay)
    end
    
    # obtain the list of existing members
    #
    # @return  [Response]
    def members
      request(:members)
    end

    # obatin the list of cluster members, filtered by tags.
    #
    # @param tags [Array] an array of tags for filter
    # @param status [Boolean] filter members based on their satatus
    # @param name [String] filter based on exact name or pattern.
    # @return  [Response]
    def members_filtered(tags, status = 'alive', name = nil)
      filter = {
        'Tags' => tags,
        'Status' => status
        }
      filter['Name'] = name unless name.nil?
      request(:members_filtered, filter)
    end

    # alter the tags on a Serf agent while it is running. A member-update
    # event will be triggered immediately to notify the other agents in the
    # cluster of the change. The tags command can add new tags, modify
    # existing tags, or delete tags
    #
    # @param tags [Hash] a hash representing tags as key-value pairs
    # @param delete_tags [Array] an array of tags to be deleted
    # @return  [Response]
    def tags(tags, delete_tags = [])
      request(:tags, 'Tags' => tags, 'DeleteTags' => delete_tags)
    end

    # subscribe to a stream of all events matching a given type filter.
    # Events will continue to be sent until the stream is stopped
    #
    # @param types [String] comma separated list of events
    # @return  [Thread, Response]
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
      
    # monitor is similar to the stream command, but instead of events it
    # subscribes the channel to log messages from the agent
    #
    # @param loglevel [String]
    # @return  [Response]
    def monitor(loglevel = 'debug')
      request(:monitor, 'LogLevel' => loglevel.upcase)
    end
    
    # stop is used to stop either a stream or monitor
    def stop(sequence_number)
      tcp_send(:stop, 'Stop' => sequence_number)
    end
    
    # leave is used trigger a graceful leave and shutdown of the current agent
    #
    # @return  [Response]
    def leave
      request(:leave)
    end

    # query is used to issue a new query
    #
    # @param name [String] name of the query
    # @param payload [String] payload for this query event
    # @param opts [Hash] additional query options
    # @return  [Response]
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

    # respond is used with `stream` to subscribe to queries and then respond.
    #
    # @param id [Integer] an opaque value that is assigned by the IPC layer
    # @param payload [String] payload for the response event
    # @return  [Response]
    def respond(id, payload)
      request(:respond, 'ID' => id, 'Payload' => payload)
    end

    # install a new encryption key onto the cluster's keyring
    #
    # @param key [String] 16 bytes of base64-encoded data.
    # @return  [Response]
    def install_key(key)
      request(:install_key, 'Key' => key)
    end

    # change the primary key, which is used to encrypt messages
    #
    # @param key [String] 16 bytes of base64-encoded data.
    # @return  [Response]
    def use_key(key)
      request(:use_key, 'Key' => key)
    end

    # remove a key from the cluster's keyring
    #
    # @param key [String] 16 bytes of base64-encoded data.
    # @return  [Response]
    def remove_key(key)
      request(:remove_key, 'Key' => key)
    end

    # return a list of all encryption keys currently in use on the cluster
    #
    # @return  [Response]
    def list_keys
      request(:list_keys)
    end
  end
end
