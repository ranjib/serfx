module Serfx
  module Utils

    class SerfEvent
      attr_reader :environment, :payload, :type, :name

      def initialize(env=ENV)
        @environment ={}
        @payload = nil
        @name = nil
        env.keys.select{|k|k=~/^SERF/}.each do | k|
          @environment[k] = env[k].strip
        end
        @type = @environment['SERF_EVENT']
        if %w{query user}.include?(@type)
          @name = @environment['SERF_USER_EVENT'] || @environment['SERF_QUERY_NAME']
          begin
            @payload = STDIN.read_nonblock(4096).strip
          rescue Errno::EAGAIN => e
          end
        end
      end
    end

    module Callbacks
      def callbacks
        @_callbacks ||= Hash.new{|h,k| h[k] = []}
      end
      def on(type, name = nil,  &block)
        callbacks[event_type] << [name, block]
      end
      def run
        event = ::Serfx::Utils::SerfEvent.new
        callbacks[event.type.downcase.to_sym].each do |name, cbk|
          if name && (event.name === name)
            cbk.call(event)
          end
        end
      end
    end

    class Handler
      extend Callbacks
      def run
        self.class.run
      end
    end
  end
end
