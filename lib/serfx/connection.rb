# encoding: UTF-8
#
require 'msgpack'
require 'timeout'
require 'serfx/log'
require 'serfx/response'
require 'socket'

module Serfx
  # provide tcp connection layer and msgpack wrapping
  class Connection
    COMMANDS = {
      handshake:        [:header],
      auth:             [:header],
      event:            [:header],
      force_leave:      [:header],
      join:             [:header, :body],
      members:          [:header, :body],
      members_filtered: [:header, :body],
      tags:             [:header],
      stream:           [:header],
      monitor:          [:header],
      stop:             [:header],
      leave:            [:header],
      query:            [:header],
      respond:          [:header]
      }

    attr_reader :host, :port, :seq, :timeout

    def initialize(host, port, authkey = nil)
      @host = host
      @port = port
      @seq = 0
      @timeout = 3
      @authkey = authkey
    end

    def socket
      @socket ||= TCPSocket.new(host, port)
    end

    def tcp_send(command, body = nil)
      @seq += 1
      header = {
        'Command' => command.to_s.gsub('_', '-'),
        'Seq' => seq
        }
      buff = MessagePack::Buffer.new
      buff << header.to_msgpack
      buff << body.to_msgpack unless body.nil?
      socket.send(buff.to_str, 0)
    end

    def read_response(command)
      unpacker = MessagePack::Unpacker.new(socket)
      header =  read(unpacker)
      if COMMANDS[command].include?(:body)
        body = read(unpacker)
        Response.new(header, body)
      else
        Response.new(header)
      end
    end

    def read(reader)
      Timeout.timeout(timeout) do
        reader.read
      end
    end

    def handshake
      tcp_send(:handshake, 'Version' => 1)
      read_response(:handshake)
    end

    def auth
      handshake if seq == 0
      tcp_send(:auth, 'AuthKey' => @authkey)
      read_response(:auth)
    end

    def request(command, body = nil)
      handshake if seq == 0
      auth unless @authkey.nil?
      tcp_send(command, body)
      read_response(command)
    end

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

    def members_filtered(tags, status = "alive", name = nil)
     filter = {
       'Tags' => tags,
       'Status' => status
      }
     filter['Name'] = name unless name.nil?
     request(:members_filtered, filter)
    end

    def tags(tags, delete_tags)
      request(:tags, 'Tags' => tags, 'DeleteTags' => delete_tags) 
    end

    def stream(types)
      request(:stream, 'Type' => types)
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
