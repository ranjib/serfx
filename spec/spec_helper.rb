# encoding: UTF-8

$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
$LOAD_PATH.unshift(File.expand_path('../spec', __FILE__))
require 'rspec'
require 'serfx'
require 'singleton'

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
        fail "Already running serf(#{@pids.inspect})" unless @pids.empty?
        @tmpdir = Dir.mktmpdir
        @pids << daemonize(@tmpdir)
        (numbers - 1).times do |n|
          @pids << daemonize(@tmpdir)
        end
      end

      def daemonize(dir)
        n = @pids.size
        config = File.expand_path('../data/config.json', __FILE__)
        bind, rpc = 4000 + n, 5000 + n
        args = "-bind=127.0.0.1:#{bind} -config-file=#{config}"
        args << " -rpc-addr=127.0.0.1:#{rpc} -node=node_#{n}"
        args << ' -join=127.0.0.01:4000' unless @pids.empty?
        command = serf_binary + ' agent ' + args
        pid = spawn(command, out: '/dev/null', chdir: dir)
        Process.detach(pid)
        pid
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
