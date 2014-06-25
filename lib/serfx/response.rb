# encoding: UTF-8
#
module Serfx
  # Store agent rpc response data
  # All RPC responses in Serf composed of an header and an optional
  # body.
  #
  class Response
    # Header is composed of two sub-parts
    # - Seq : an integer representing the original request
    # - Error: a string that represent whether the request made, was
    #   successfull or no. For all successful RPC requests, Error should
    #   be an empty string
    #
    # `{"Seq": 0, "Error": ""}`
    #
    Header = Struct.new(:seq, :error)
    attr_reader :header, :body

    # Constructs a response object from a given header and body.
    #
    # @param header [Hash] header of the response as hash
    # @param body [Hash] body of the response as hash
    def initialize(header, body = nil)
      @header = Header.new(header['Seq'], header['Error'])
      @body = body
    end
  end
end
