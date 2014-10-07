# encoding: UTF-8

require 'serfx/log'
require 'serfx/version'
require 'serfx/connection'

# Serfx is a minimal ruby client for serf.
module Serfx
  # Creates a serf rpc connection, performs handshake and auth
  # (if authkey is supplied). If a block is provided, the connection
  # object will be yield-ed and the connection will be closed after
  # the block's execution, otherwise the connection will be returned
  # Params:
  # +opts+:: An optional hash which can have following keys:
  # * host => Serf host's rpc bind address (127.0.0.1 by default)
  # * port => Serf host's rpc port (7373 by default)
  # * authkey => Encryption key for RPC communiction
  #
  # @return value of the block evaluation or the connection object
  def self.connect(opts = {})
    conn = Serfx::Connection.new(opts)
    conn.handshake
    conn.auth if opts.key?(:authkey)
    res = nil
    if block_given?
      res = yield conn
      conn.close unless conn.closed?
      res
    else
      conn
    end
  end
end
