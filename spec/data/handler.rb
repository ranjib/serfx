require 'serfx/utils/handler'

include Serfx::Utils::Handler

on :query, 'upcase' do |event|
  unless event.payload.nil?
    STDOUT.write(event.payload.upcase)
  end
end

run
