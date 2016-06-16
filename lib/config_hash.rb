require 'configatron'
require_relative 'default_config'
require_relative 'command_processor'
require_relative 'git_util'

RELEASINATOR_NAME = "releasinator"
CONFIG_FILE_NAME = ".#{RELEASINATOR_NAME}.rb"

module Releasinator
  class ConfigHash < Hash
    def initialize(verbose, trace)
      update({:releasinator_name => RELEASINATOR_NAME})
      update({:verbose => verbose})
      update({:trace => trace})

      require_file_name = "./.#{RELEASINATOR_NAME}.rb"
      begin 
        require require_file_name
      rescue LoadError
        is_git_already_clean = GitUtil.is_clean_git?
        puts "It looks like this is your first time using #{RELEASINATOR_NAME} on this project.".yellow
        puts "A default '#{CONFIG_FILE_NAME}' file has been created for you.".yellow
        out_file = File.new("#{CONFIG_FILE_NAME}", "w")
        out_file.write(DEFAULT_CONFIG)
        out_file.close
        require require_file_name
        
        # dpn't want to commit other files
        if is_git_already_clean
          puts "adding default #{CONFIG_FILE_NAME} to git".yellow
          CommandProcessor.command("git add #{CONFIG_FILE_NAME}")
          CommandProcessor.command("git commit -m \"#{RELEASINATOR_NAME}: add default config\"")
        end
      end

      configatron.lock!
      loaded_config_hash = configatron.to_h

      update(loaded_config_hash)

      puts "loaded config:" + self.to_s if verbose
    end

    def use_git_flow()
      return self[:use_git_flow] if self.has_key? :use_git_flow
      false
    end

    def base_dir
      return self[:base_docs_dir] if self.has_key?(:base_docs_dir)
      '.'
    end

    def doc_target_dir 
      return self[:doc_target_dir] if self.has_key?(:doc_target_dir)
      '.'
    end
  end
end
