module Serfx
  module Utils
    # helper module to for serf custom handlers
    #
    # serf agents can be configured to invoke an executable
    # script when an user event is received.
    #
    # [Serfx::Utils::Handler] module provides a set of helper methods to ease
    # writing ruby based serf event handlers
    #
    # For example, following script will respond to any qury event named
    # 'upcase' and return the uppercase version of the original query event's
    # payload
    # @example
    #   require 'serfx/utils/handler'
    #   include Serfx::Utils::Handler
    #   on :query, 'upcase' do |event|
    #     unless event.payload.nil?
    #       STDOUT.write(event.payload.upcase)
    #     end
    #   end
    #   run
    module Handler
      # when serf agent invokes a handler it passes the event payload
      # through STDIN. while event metadata such as event type, name etc
      # is passed as a set of environment variables.
      # [SerfEvent] encapsulates such event.
      class SerfEvent
        attr_reader :environment, :payload, :type, :name

        # @param env [Hash] environment
        # @param stdin [IO] stadard input stream for the event
        def initialize(env = ENV, stdin = STDIN)
          @environment = {}
          @payload = nil
          @name = nil
          env.keys.select { |k| k =~ /^SERF/ }.each do | k|
            @environment[k] = env[k].strip
          end
          @type = @environment['SERF_EVENT']
          case @type
          when 'query'
            @name = @environment['SERF_QUERY_NAME']
            begin
              @payload = stdin.read_nonblock(4096).strip
            rescue Errno::EAGAIN, EOFError
            end
          when 'user'
            @name = @environment['SERF_USER_EVENT']
            begin
              @payload = stdin.read_nonblock(4096).strip
            rescue Errno::EAGAIN, EOFError
            end
          end
        end
      end

      # register a callback against an event
      #
      # @param type [Symbol] event type for which this handler will be invoked
      # @param name [String, Regex] match against name of the event
      def on(type, name = nil,  &block)
        callbacks[type] << SerfCallback.new(name, block)
        nil
      end

      # execute callbacks registerd using `on`
      def run
        event = SerfEvent.new
        callbacks[event.type.downcase.to_sym].each do |cbk|
          if cbk.name
            cbk.block.call(event) if event.name === cbk.name
          else
            cbk.block.call(event)
          end
        end
      end

      private

      SerfCallback = Struct.new(:name, :block)

      def callbacks
        @_callbacks ||= Hash.new { |h, k| h[k] = [] }
      end
    end
  end
end
