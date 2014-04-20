# encoding: UTF-8
#
module Serfx
  # provides rpc client to serf cluster
  class Client
    attr_reader :host, :port

    def initialize(opts = {})
      @host = opts[:host] || 'localhost'
      @port = opts[:host] || '7373'
    end

    def self.connect
      client = new
      yield client.connection if block_given?
    end

    def connection
      Serfx::Connection.new(host, port)
    end
  end
end
