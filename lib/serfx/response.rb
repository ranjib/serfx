# encoding: UTF-8
#
module Serfx
  # Store agent rpc response data
  class Response
    # {"Seq": 0, "Error": ""}
    Header = Struct.new(:seq, :error)
    attr_reader :header, :body
    def initialize(h, body = nil)
      @header = Header.new(h['Seq'], h['Error'])
      @body = body
    end
  end
end
