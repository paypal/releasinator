require_relative 'command_processor'

module Releasinator
  class Printer
    def self.success(msg)
      puts "\xE2\x9C\x94\xEF\xB8\x8E ".light_green + "SUCCESS: #{msg}".green
    end

    def self.fail(msg)
      puts "\xE2\x9C\x98 FAILURE: #{msg}".red
    end

    def self.check_proceed(warning_msg, abort_msg)
      puts "#{warning_msg}  Continue?  (Y/n)".yellow
      if 'n' == $stdin.gets.strip
        self.fail(abort_msg)
        abort()
      end
    end
  end
end
