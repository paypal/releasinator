module Releasinator
  class DownstreamRepo
    attr_reader :name, :url, :branch, :options
    def initialize(name, url, branch, options={})
      @name = name # The desired name of the repo. This is only used for the directory in the `downstream_repos` folder.
      @name.freeze
      @url = url # The GitHub repo location.
      @url.freeze
      @branch = branch # The git branch on which to base new changes.
      @branch.freeze
      @options = options # hash of any of the following options:
      @options.freeze
      #  :new_branch_name  # The name of the new branch to create.  If this is set, :release_to_github is ignored.
      #  :release_to_github  # True if publishing the root repo to GitHub.
      #  :files_to_copy # List of CopyFile objects for copying files into downstream.  Please see documentation on the `CopyFile` class.
      #  :full_file_sync # True if the downstream repo should just be a straight copy of source.  Setting this to true removes all files before replacing them all with those specified in base_docs_dir.
      #  :post_copy_methods # List of methods to run immediately after copying all files.
      #  :build_methods # List of methods to run immediately after copying files.  Useful to test whether the new downstream changes now compile.
    end

    def full_file_sync
      return @options[:full_file_sync] if @options.has_key? :full_file_sync
      false
    end

    def release_to_github
      return @options[:release_to_github] if @options.has_key? :release_to_github
      false
    end
  end
end
