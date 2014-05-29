# encoding: UTF-8

require 'json'
module Serfx
  module Utils

    # serf event handler invocations are blocking calls. i.e. serf
    # will not process any other event when a handler invocation is
    # in progress. due to this limitations long running tasks can not be
    # orchestrated or invoked as serf handler directly.
    # AsynchJob address this by spawning the task as a background job,
    # allowing the handler code to return immediately. It does double fork
    # where the first child process is detached (attached to init as parent
    # process) and spawn the second child process with the target,
    # long running task. This allows the parent process to wait and reap the
    # output of target task and save it in disk so that it can be exposed
    # via other serf events
    #
    # @example
    #   require 'serfx/utils/async_job'
    #   require 'serfx/utils/handler'
    #
    #   job = Serfx::Utils::AsyncJob.new(
    #     name: "bash_test"
    #     command: "bash -c 'for i in `seq 1 3`; do echo $i; sleep 1; done'",
    #     state: '/opt/serf/states/long_task'
    #     )
    #
    #   on :query, 'task_fire' do |event|
    #     puts job.run
    #   end
    #
    #   on :query, 'task_check' do |event|
    #     puts job.state_info.inspect
    #   end
    #
    #   on :query, 'task_kill' do |event|
    #     puts job.kill
    #   end
    #
    #   on :query, 'task_reap' do |event|
    #     puts job.reap
    #   end
    #
    #   run
    class AsyncJob

      attr_reader :command, :state_file, :stdout_file, :stderr_file

      # @param opts [Hash] specify the job details
      # @option opts [Symbol] :state file path which will be used to store
      #   task state locally
      # @option opts [Symbol] :command actual command which will be invoked
      #   in the background
      # @option opts [Symbol] :stdout standard output file for the task
      # @option opts [Symbol] :stderr standard error file for the task
      def initialize(opts = {})
        @state_file = opts[:state] || fail(ArgumentError, 'Specify state file')
        @command = opts[:command]
        @stdout_file = opts[:stdout] || File::NULL
        @stderr_file = opts[:stderr] || File::NULL
      end

      # kill an already running task
      #
      # @param sig [String] kill signal that will sent to the backgroun process
      # @return [TrueClass,FalseClass] true on success, false on failure
      def kill(sig = 'KILL')
        if running?
          begin
            Process.kill(sig, state_info['pid'].to_i)
            'success'
          rescue Exception => e
            'failed'
          end
        else
          'failed'
        end
      end

      # obtain current state information about the task
      #
      # @return [Hash]
      def state_info
        if exists?
          JSON.parse(File.read(state_file))
        else
          {'status' => 'absent' }
        end
      end

      # delete the statefile of a finished task
      #
      # @return [String] 'success' if the task is reaped, 'failed' otherwise
      def reap
        if state_info['status'] == 'finished'
          File.unlink(state_file)
          'success'
        else
          'failed'
        end
      end


      # start a background daemon and spawn another process to run specified
      # command. writes back state information in the state file
      # after spawning daemon process (state=invoking), after spawning the
      # child process (state=running) and after reaping the child process
      # (sate=finished).
      #
      # @return [String] 'success' if task is started
      def start
        if exists? or command.nil?
          return 'failed'
        end
        pid = fork do
          Process.daemon
          state = {
            ppid: Process.pid,
            status: 'invoking',
            pid: -1,
            time: Time.now.to_i
          }
          write_state(state)
          begin
            child_pid = Process.spawn(command, out: stdout_file, err: stderr_file)
            state[:pid] = child_pid
            state[:status] = 'running'
            write_state(state)
            _ , status = Process.wait2(child_pid)
            state[:exitstatus] = status.exitstatus
            state[:status] = 'finished'
          rescue Errno::ENOENT => e
            state[:error] = e.class.name
            state[:status] = 'failed'
          end
          write_state(state)
          exit 0
        end
        Process.detach(pid)
        'success'
      end

      private

      # check if a task already running
      #
      # @return [TrueClass, FalseClass] true if the task running, else false
      def running?
        if exists?
          File.exist?(File.join('/proc', state_info['pid'].to_s))
        else
          false
        end
      end

      # check if a task already exist
      #
      # @return [TrueClass, FalseClass] true if the task exists, else false
      def exists?
        File.exists?(state_file)
      end

      # writes a hash as json in the state_file
      # @param [Hash] state represented as a hash, to be written
      def write_state(state)
        File.open(state_file, 'w'){|f| f.write(JSON.generate(state))}
      end
    end
  end
end
