require 'colorize'
require_relative 'printer'

module Releasinator
  class CommandProcessor
    def self.command(command, live_output=false)
      puts Time.now.utc.iso8601 + ": " + "#{Dir.pwd}".bold + " exec:" + " #{command}".bold
      if live_output 

        puts "...with live output (forked process)".bold

        return_code = nil
        r, io = IO.pipe
        pid = fork do
          return_code = system(command, :out => io, :err => io)
          if !return_code
            Printer.fail("Execution failure.")
            abort()
          end
        end
        io.close
        output = ""
        r.each_line do |line|
          puts line.strip.white
          output << line
        end

        Process.wait(pid)
        fork_exitstatus = $?.exitstatus
        if 0 != fork_exitstatus
          Printer.fail("Forked process failed with exitstatus:#{fork_exitstatus}")
          abort()
        end
      else
        output = `#{command}`
        exitstatus = $?.exitstatus
        if 0 != exitstatus
          Printer.fail("Process failed with exitstatus:#{exitstatus}")
          abort()
        end
      end
      output
    end

    # waits for the input command to return non-empty output.
    def self.wait_for(command_to_execute, wait_for_seconds=30)
      while "" == CommandProcessor.command(command_to_execute)
        puts "Returned empty output.  Sleeping #{wait_for_seconds} seconds."
        wait_for_seconds.times do
          print "."
          sleep 1
        end
        puts
      end

      Printer.success("Returned non-empty output.")
    end
  end
end
