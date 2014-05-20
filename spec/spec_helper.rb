# encoding: UTF-8

$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
$LOAD_PATH.unshift(File.expand_path('../spec', __FILE__))
require 'rspec'
require 'serfx'
require 'singleton'
require 'tmpdir'
require 'codeclimate-test-reporter'
if ENV['CODE_COVERAGE']
  CodeClimate::TestReporter.start
end

module Serfx
  # adds helper method for unit testing
  module SpecHelper
  # provides serf cluster setup helper methods
    class Spawner
      include Singleton
      attr_reader :pids

      def initialize
        @pids = []
      end

      def servers
        @pids.size.times.reduce([]) { |a, e| a << { port: (7373 + e) } }
      end

      def start(numbers = 1, opts = {})
        (numbers).times do |n|
          join = if @pids.empty?
                   false
                 elsif opts.key?(:join)
                   opts[:join]
                 else
                   true
                 end
          @pids << daemonize(Dir.mktmpdir, join)
        end
      end

      def daemonize(dir, join = false)
        command = serf_command(join)
        pid = spawn(command, out: '/dev/null', chdir: dir)
        Process.detach(pid)
        pid
      end

      def serf_command(join)
        n = @pids.size
        group = n.even? ? 'even' : 'odd'
        config = File.expand_path('../data/config.json', __FILE__)
        args = " -bind 127.0.0.1:#{4000 + n} -rpc-addr 127.0.0.1:#{5000 + n} "
        args << "-config-file #{config} -node node_#{n} -tag group=#{group}"
        args << ' -join 127.0.0.01:4000' if join
        serf_binary + ' agent ' + args
      end

      def serf_binary
        path = File.expand_path('../../serf_binaries/serf', __FILE__)
        if File.exist?(path)
          path
        elsif ENV['SERF_BIN']
          ENV['SERF_BIN']
        else
          fail 'serf binary not found., you need to set SERF_BIN'
        end
      end

      def stop
        @pids.each do |pid|
          Process.kill('TERM', pid)
        end
        FileUtils.remove_entry_secure(@tmpdir, true)
        @pids.clear
      end
    end

    def start_cluster(numbers = 1, opts = {})
      Spawner.instance.start(numbers, opts)
      sleep 1
    end

    def stop_cluster
      Spawner.instance.stop
    end
  end
end

RSpec.configure do |c|
  c.include Serfx::SpecHelper
end
