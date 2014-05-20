module Serfx
  module Utils
    class AsyncJob

      attr_reader :command, :state_dir

      def initialize(command, state_dir)
        @command = command
        @state_dir = state_dir
      end

      def stdout_file
        File.join(state_dir, "#{command}_stdout")
      end

      def stderr_file
        File.join(state_dir, "#{command}_stderr")
      end

      def state_file
        File.join(state_dir, "#{command}_state")
      end

      def pid_file
        File.join(state_dir, "#{command}_pid")
      end

      def kill(sig='KILL')
        if File.exist?(pid_file)
          pid = File.read(pid_file)
          begin
            out = Process.kill(sig, pid)
          rescue Exception => e
            out = e.class.name
          end
        end
      end

      def start
        if exists?
          -1
        else
          execute
        end
      end

      def exists?
        [stdout_file, srderr_file, state_file, pid_file].any? do |file|
          File.exists?(file)
        end
      end

      def status
        if exists?
          if File.exist?(state_file)
            File.read(state_file)
          else
            'present but unknown'
          end
        else
          'absent'
        end
      end

      def reap
        deleted_files = []
        [state_file, stdout_file, stderr_file, pid_file].each do |file|
          if File.exists?(file)
            File.unlink(file)
            deleted_files << file
          end
        end
        deleted_files
      end

      private

      def execute
        pid = fork do
          Process.daemon
          begin
            child_pid = Process.spawn(command, out: stdout_file, err: stderr_file)
            _ , status = Process.wait2(child_pid)
            state = "pid=#{child_pid}|exit=#{status.exitstatus}"
          rescue Errno::ENOENT => e
            state = "failed|error=#{e.class.name})"
          end
          File.open(state_file, 'w'){|f| f.write(state)}
          exit 0
        end
        File.open(pid_file, 'w') {|f| f.write(pid)}
        Process.detach(pid)
        pid
      end
    end
  end
end
