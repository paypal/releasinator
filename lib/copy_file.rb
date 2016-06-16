module Releasinator
  class CopyFile
    attr_reader :source_file, :target_name, :target_dir
    def initialize(source_file, target_name, target_dir)
      @source_file = source_file # The source file or directory name, including directory.
      @source_file.freeze
      @target_name = target_name # The target file or directory name, excluding directory.
      @target_name.freeze
      @target_dir = target_dir # The target directory name.
      @target_dir.freeze
    end
  end
end
