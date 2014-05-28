require 'serfx/utils/async_job'
require 'serfx/utils/handler'

include Serfx::Utils::Handler

command = "bash -c 'for i in `seq 1 300`; do echo $i; sleep 1; done'"
job = Serfx::Utils::AsyncJob.new(command: command, state: '/tmp/long_task')

on :query, 'task' do |event|
  case event.payload
  when 'start'
    puts job.start
  when 'check'
    puts job.state_info.inspect
  when 'reap'
    puts job.reap
  when 'kill'
    puts job.kill
  else
    puts "unknown: #{event.payload}"
  end
end

run
