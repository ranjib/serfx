require 'spec_helper'
require 'serfx/utils/handler'

describe Serfx::Utils::Handler do
  it 'should invoke all the call backs' do
    class CustomHandler
      extend Serfx::Utils::Handler
      @@state = {}
      def self.state
        @@state
      end
      on :query, 'foo' do |event|
        @@state[:payload] = event.payload
      end
    end
    ENV['SERF_EVENT'] = 'query'
    ENV['SERF_QUERY_NAME'] = 'foo'
    STDIN.should_receive(:read_nonblock).and_return('yeah')
    CustomHandler.run
    expect(CustomHandler.state[:payload]).to eq('yeah')
  end
end
