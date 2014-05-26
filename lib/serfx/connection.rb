# encoding: UTF-8
#
require 'msgpack'
require 'timeout'
require 'serfx/log'
require 'serfx/response'
require 'serfx/commands'
require 'serfx/exceptions'
require 'socket'
require 'thread'

Thread.abort_on_exception = true

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

    include Serfx::Commands

    attr_reader :host, :port, :seq

    def initialize(opts = {})
      @host = opts[:host] || '127.0.0.1'
      @port = opts[:port] || 7373
      @seq = 0
      @authkey = opts[:authkey]
      @requests = {}
      @responses = {}
    end

    def socket
      @socket ||= TCPSocket.new(host, port)
    end

    def unpacker
      @unpacker ||= MessagePack::Unpacker.new(socket)
    end

    def read_data
      unpacker.read
    end

    def tcp_send(command, body = nil)
      @seq += 1
      header = {
        'Command' => command.to_s.gsub('_', '-'),
        'Seq' => seq
        }
      Log.info("#{__method__}|Header: #{header.inspect}")
      buff = MessagePack::Buffer.new
      buff << header.to_msgpack
      buff << body.to_msgpack unless body.nil?
      res = socket.send(buff.to_str, 0)
      Log.info("#{__method__}|Res: #{res.inspect}")
      @requests[seq] = {header: header, ack?: false}
      seq
    end

    def check_rpc_error!(header)
      raise RPCError, header['Error'] unless header['Error'].empty?
    end

    def read_response(command)
      header =  read_data
      check_rpc_error!(header)
      if COMMANDS[command].include?(:body)
        body = read_data
        Response.new(header, body)
      else
        Response.new(header)
      end
    end

    def handshake
      tcp_send(:handshake, 'Version' => 1)
      read_response(:handshake)
    end

    def auth
      tcp_send(:auth, 'AuthKey' => @authkey)
      read_response(:auth)
    end

    def request(command, body = nil)
      id = tcp_send(command, body)
      read_response(command)
    end

    def close
      socket.close
    end
  end
end
