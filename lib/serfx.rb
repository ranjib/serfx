# encoding: UTF-8

require 'serfx/log'
require 'serfx/version'
require 'serfx/connection'

# Provides top level namespace for the Serfx module
module Serfx
  def self.connect(opts = {})
    conn = Serfx::Connection.new(opts)
    conn.handshake
    conn.auth if opts.key?(:authkey)
    res = yield conn
    conn.close
    res
  end
end
