# encoding: UTF-8

require 'json'
module Serfx
  module Utils
    # Serf event handler invocations are blocking calls. i.e. serf
    # will not process any other event when a handler invocation is
    # in progress. Due to this, long running tasks should not be
    # invoked as serf handler directly.
    #
    # AsyncJob helps building serf handlers that involve long running commands.
    # It starts the command in background, allowing handler code to
    # return immediately. It does double fork where the first child process is
    # detached (attached to init as parent process) and and the target long
    # running task is spawned as a second child process. This allows the first
    # child  process to wait and reap the output of actual long running task.
    #
    # The first child process updates a state file before spawning
    # the long ranning task(state='invoking'), during the long running task
    # execution (state='running') and after the spawned process' return
    # (state='finished'). This state file provides a convenient way to
    # query the current state of an AsyncJob.
    #
    # AsyncJob provides four methods to manage jobs. AsyncJob#start will
    # start the task. Once started, AyncJob#state_info can be used to check
    # whether the job is still running or finished. One started a job can be
    # either in 'running' state or in 'finished' state. AsyncJob#reap
    # is used for deleting the state file once the task is finished.
    # An AsyncJob can be killed, if its in running state, using the
    # AsyncJob#kill method. A new AyncJob can not be started unless previous
    # AsyncJob with same name/state file is reaped.
    #
    # If the state file is nil, no state will be persisted for the job.
    # As such, AsyncJob#state_info, AsyncJob#kill, and AsyncJob#reap will
    # be a NO-OP.
    #
    # Following is an example of writing a serf handler using AsyncJob.
    #
    # @example
    #   require 'serfx/utils/async_job'
    #   require 'serfx/utils/handler'
    #
    #   include Serfx::Utils::Handler
    #
    #   job = Serfx::Utils::AsyncJob.new(
    #     name: "bash_test"
    #     command: "bash -c 'for i in `seq 1 300`; do echo $i; sleep 1; done'",
    #     state: '/opt/serf/states/long_task'
    #     )
    #
    #   on :query, 'bash_test' do |event|
    #     case event.payload
    #     when 'start'
    #       puts job.start
    #     when 'kill'
    #       puts job.kill
    #     when 'reap'
    #       puts job.reap
    #     when 'check'
    #       puts job.state_info
    #     else
    #       puts 'failed'
    #     end
    #   end
    #
    #   run
    #
    # Which can be managed via serf as:
    #
    # serf query bash_test start
    # serf query bash_test check # check if job is running or finished
    # serf query bash_test reap # delete a finished job's state file
    # serf query bash_test kill
    class AsyncJob

      attr_reader :command
      attr_reader :state_file
      attr_reader :stdout_file
      attr_reader :stderr_file
      attr_reader :environment
      attr_reader :cwd

      # @param opts [Hash] specify the job details
      # @option opts [Symbol] :state file path which will be used to store
      #   task state locally
      # @option opts [Symbol] :command actual command which will be invoked
      #   in the background
      # @option opts [Symbol] :stdout standard output file for the task
      # @option opts [Symbol] :stderr standard error file for the task
      # @option opts [Symbol] :environment a hash containing environment variables
      # @option opts [Symbol] :cwd a string (directory path) containing current directory of the command
      def initialize(opts = {})
        @state_file = opts[:state]
        @command = opts[:command]
        @stdout_file = opts[:stdout] || File::NULL
        @stderr_file = opts[:stderr] || File::NULL
        @environment = opts[:environment] || {}
        @cwd = opts[:cwd] || Dir.pwd
      end

      # kill an already running task
      #
      # @param sig [String] kill signal that will sent to the background process
      # @return [TrueClass,FalseClass] true on success, false on failure
      def kill(sig = 'KILL')
        if running?
          begin
            Process.kill(sig, stateinfo['pid'].to_i)
            File.unlink(state_file) if File.exist?(state_file)
            'success'
          rescue Exception
            'failed'
          end
        else
          'failed'
        end
      end

      # obtain current state information about the task as JSON
      #
      # @return [String] JSON string representing current state of the task
      def state_info
        if exists?
          File.read(state_file)
        else
          JSON.generate(status: 'absent')
        end
      end

      # obtain current state information about the task as hash
      #
      # @return [Hash] JSON string representing current state of the task
      def stateinfo
        JSON.parse(state_info)
      end

      # delete the state file of a finished task
      #
      # @return [String] 'success' if the task is reaped, 'failed' otherwise
      def reap
        if stateinfo['status'] == 'finished'
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
        if exists? || command.nil?
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
            child_pid = Process.spawn(
              environment,
              command,
              out: stdout_file,
              err: stderr_file,
              chdir: cwd
            )
            state[:pid] = child_pid
            state[:status] = 'running'
            write_state(state)
            _, status = Process.wait2(child_pid)
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
          File.exist?(File.join('/proc', stateinfo['pid'].to_s))
        else
          false
        end
      end

      # check if a task already exist
      #
      # @return [TrueClass, FalseClass] true if the task exists, else false
      def exists?
        state_file.nil? ? false : File.exist?(state_file)
      end

      # writes a hash as JSON in the state_file
      # @param [Hash] state represented as a hash, to be written
      def write_state(state)
        if state_file
          File.open(state_file, 'w') do |f|
            f.write(JSON.generate(state))
          end
        end
      end
    end
  end
end
