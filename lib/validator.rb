require 'colorize'
require 'net/http'
require 'json'
require_relative 'command_processor'
require_relative 'downstream_repo'
require_relative 'github_repo'
require_relative 'printer'
require_relative 'changelog/validator'
require_relative 'releasinator/version'

TEXT_FILE_EXTENSIONS = [
  ".md",
  ".txt",
  ".ini",
  ".in",
  ".xml",
  ".gitignore",
  ".npmignore",
  ".html",
  ".css",
  ".h",
  "Gemfile",
  "Gemfile.lock",
  ".rspec",
  ".gemspec",
  ".podspec",
  ".rb",
  ".java",
  ".php",
  ".py",
  ".js",
  ".yaml",
  ".json",
  ".sh",
  ".groovy",
  ".gemspec",
  ".gradle",
  ".settings",
  ".properties",
  "LICENSE",
  "Rakefile",
  "Dockerfile"
  # TODO include C# file types
]

module Releasinator
  class Validator

    def initialize(releasinator_config)
      @releasinator_config = releasinator_config
    end

    def validate_releasinator_version
      uri = URI('https://rubygems.org/api/v1/gems/releasinator.json')
      latest_version = JSON.parse(Net::HTTP.get(uri))["version"]
      current_version = Releasinator::VERSION

      if Gem::Version.new(latest_version) > Gem::Version.new(current_version)
        Printer.fail("Please upgrade to the latest releasinator version:" + latest_version.bold + ".  Current version:" + current_version.bold)
        abort()
      elsif Gem::Version.new(latest_version) < Gem::Version.new(current_version)
        Printer.success("Releasinator version: " + current_version.bold + " is newer than one from rubygems.org: " + latest_version.bold + ".  You're probably testing a development version.")
      else
        Printer.success("Releasinator version: " + latest_version.bold + " is the latest from rubygems.org.")
      end
    end

    def validate_eof_newlines
      all_git_files = GitUtil.all_files.split

      important_git_text_files = all_git_files.select{ |filename|
        TEXT_FILE_EXTENSIONS.any? { |extension|
          filename.end_with?(extension)
        }
      }

      important_git_text_files.each do |filename|
        CommandProcessor.command("tail -c1 #{filename} | read -r _ || echo >> #{filename}")
      end
    end

    def validate_in_path(executable)
      if "" == CommandProcessor.command("which #{executable} | cat")
        Printer.fail(executable.bold + " not found on path.")
        abort()
      else
        Printer.success(executable.bold + " found on path.")
      end
    end

    def validate_git_version
      version_output = CommandProcessor.command("git version")
      # version where the parallel git fetch features were added
      expected_git_version = "2.8.0"
      actual_git_version = version_output.split[2]

      if Gem::Version.new(expected_git_version) > Gem::Version.new(actual_git_version)
        Printer.fail("Actual git version " + actual_git_version.bold + " is smaller than expected git version " + expected_git_version.bold)
        abort()
      else
        Printer.success("Git version " + actual_git_version.bold + " found, and is higher than or equal to expected git version " + expected_git_version.bold)
      end
    end

    def validate_changelog(search_ignore_path=nil)
      validate_base_dir
      validate_exist(@releasinator_config.base_dir, "CHANGELOG.md", search_ignore_path, ["release_notes.md"])

      changelog_contents = get_changelog_contents
      Changelog::Validator.new(@releasinator_config).validate_changelog_contents(changelog_contents)
    end

    def validate_is_type(obj, type)
      if !obj.is_a? type
        Printer.fail("#{obj} is not a #{type}.")
        abort()
      end 
    end

    def validate_method_convention(hash)
      hash.each do |key, value|
        if key.to_s.end_with? "_methods" 
          # validate that anything ending in _methods is a list of methods
          if !value.respond_to? :each
            Printer.fail("#{key} is not a list.")
            abort()
          end
          value.each do |list_item|
            validate_is_type list_item, Method
          end
        elsif key.to_s.end_with? "_method"
          # anything ending in _method is a method
          validate_is_type value, Method
        else
          # ignore everything else
        end
      end
    end

    def validate_required_configatron_key(key)
      if !@releasinator_config.has_key?(key)
        Printer.fail("No #{key} found in configatron.")
        abort()
      end
    end

    def validate_config()
      validate_required_configatron_key(:product_name)
      validate_required_configatron_key(:prerelease_checklist_items)
      validate_required_configatron_key(:build_method)
      validate_required_configatron_key(:publish_to_package_manager_method)
      validate_required_configatron_key(:wait_for_package_manager_method)
      validate_required_configatron_key(:release_to_github)

      validate_method_convention(@releasinator_config)

      if @releasinator_config.has_key? :downstream_repos
        @releasinator_config[:downstream_repos].each do |downsteam_repo|
          validate_is_type downsteam_repo, DownstreamRepo

          validate_method_convention(downsteam_repo.options)
        end
      end
    end

    def validate_github_permissions(repo_url)
      github_repo = GitHubRepo.new(repo_url)
      github_client = github_repo.client

      begin
        # get the list of collaborators.
        puts "Checking collaborators on #{repo_url}." if @releasinator_config[:verbose]
        github_collaborators = github_client.collaborators "#{github_repo.org}/#{github_repo.repo}"
        if ! github_collaborators
          Printer.fail("request failed with code:#{res.code}\nbody:#{res.body}")
          abort()
        end
        puts github_collaborators.inspect if @releasinator_config[:trace]
        Printer.success("User has push permissions on #{repo_url}.")
      rescue => error
        #This will fail if the user does not have push permissions.
        Printer.fail(error.inspect)
        abort()
      end
    end

    def validate_gitignore_contents(line)
      if !line_match_in_file?(line, ".gitignore")
        is_git_already_clean = GitUtil.is_clean_git?
        File.open('.gitignore', 'a') do |f|
          f.puts line
        end

        Printer.success("Added missing line '#{line}' to .gitignore.")

        if is_git_already_clean
          CommandProcessor.command("git add . && git commit -m \"#{@releasinator_config[:releasinator_name]}: add missing line to .gitignore\"")
        end
      end
    end

    def line_match_in_file?(contains_string, filename)
      File.open("#{filename}", "r") do |f|
        f.each_line do |line|
          if line.match /^#{Regexp.escape(contains_string)}$/
            Printer.success("#{filename} contains #{contains_string}")
            return true
          end
        end
      end
      false
    end

    def validate_referenced_in_readme(filename)
      validate_base_dir
      Dir.chdir(@releasinator_config.base_dir) do
        File.open("README.md", "r") do |f|
          f.each_line do |line|
            if line.include? "(#{filename})"
              Printer.success("#{filename} referenced in #{@releasinator_config.base_dir}/README.md")
              return
            end
          end
        end
      end
      Printer.fail("Please link to the #{filename} file somewhere in #{@releasinator_config.base_dir}/README.md.")
      abort()
    end

    def validate_exist(dir, expected_file_name, search_ignore_path=nil, alternate_names=[])
      if !File.exist? dir
        Printer.fail("Directory #{dir} not found.")
        abort()
      end
      
      Dir.chdir(dir) do
        if !GitUtil.exist?(expected_file_name)
          puts "#{dir}/#{expected_file_name} not found using a case sensitive search within git, searching for similar files...".yellow
        
          # search for files that are somewhat similar to the file being searched, ignoring case
          filename_prefix = expected_file_name[0,5]
          similar_files = CommandProcessor.command("find . -type f -not -path \"./#{search_ignore_path}/*\" -iname '#{filename_prefix}*'| sed 's|./||'").strip
          num_similar_files = similar_files.split.count
          puts similar_files
          if num_similar_files == 1
            Printer.check_proceed("Found a single similar file: #{similar_files}.  Do you want to rename this to the expected #{expected_file_name}?","Please commit #{dir}/#{expected_file_name}")
            rename_file(similar_files, expected_file_name)
          elsif num_similar_files > 1
            Printer.fail("Found more than 1 file similar to #{expected_file_name}.  Please rename one, and optionally remove the others to not confuse users.")
            abort()
          elsif !rename_alternate_name(expected_file_name, alternate_names)
            Printer.fail("Please commit #{dir}/#{expected_file_name}.")
            abort()
          end
        end
        Printer.success("#{dir}/#{expected_file_name} found.")
      end
    end

    def validate_base_dir()
      if !File.exist? @releasinator_config.base_dir
        Printer.fail("Directory specified by base_docs_dir '#{@releasinator_config.base_dir}' not found.  Please fix the config, or add this directory.")
        abort()
      end
    end

    def validate_clean_git
      untracked_files = GitUtil.untracked_files
      diff = GitUtil.diff
      diff_cached = GitUtil.cached

      if '' != untracked_files
        puts untracked_files.red if @releasinator_config[:verbose]
        error = true
        Printer.fail("Untracked files found.")
      else
        Printer.success("No untracked files found.")
      end

      if '' != diff
        puts diff.red if @releasinator_config[:verbose]
        error = true
        Printer.fail("Unstaged changes found.")
      else
        Printer.success("No unstaged changes found.")
      end

      if '' != diff_cached
        puts diff_cached.red if @releasinator_config[:verbose]
        error = true
        Printer.fail("Uncommitted changes found.")
      else
        Printer.success("No uncommitted changes found.")
      end

      abort() if error
    end


    def validate_submodules
      if File.exist?(".gitmodules")
        submodules = Array.new

        current_name = nil
        current_path = nil
        current_url = nil
        File.open(".gitmodules", "r") do |f|
          f.each_line do |line|

            if line.include? "\""
              current_name = line.strip.split(' ').last.to_s.split("\"").at(1)
            elsif line.include? "path = "
              current_path = line.strip.split(' ').last.to_s
            elsif line.include? "url = "
              current_url = line.strip.split(' ').last.to_s
              submodules << Submodule.new(current_name, current_path, current_url)
            end
          end
        end

        Printer.success("Found " + submodules.count.to_s.bold + " submodules in .gitmodules.")
        submodules.each do |submodule|
          Dir.chdir(submodule.path) do
            if GitUtil.detached?
              local_sha1 = GitUtil.get_local_head_sha1()
            else
              local_branch_name = GitUtil.get_current_branch
              local_sha1 = GitUtil.get_local_branch_sha1(local_branch_name)
            end

            origin_master_sha1 = GitUtil.get_remote_branch_sha1("master")

            if local_sha1 != origin_master_sha1
              abort_string = "Submodule #{Dir.pwd} not on latest master.  Currently at #{local_sha1}, but origin/master is at #{origin_master_sha1}."\
              "\nYou should update this submodule to the latest in origin/master."
              Printer.fail(abort_string)
              abort()
            else
              Printer.success("Submodule #{Dir.pwd} matches origin/master.")
            end
            validate_clean_git()
          end
        end
      else
        Printer.success("No submodules found.")
      end
    end

    def validate_branches(version)
      GitUtil.fetch()
      current_branch = GitUtil.get_current_branch()

      if @releasinator_config.use_git_flow()
        expected_release_branch = "release/#{version}"

        unless current_branch == expected_release_branch || current_branch == "develop"
          Printer.fail("git flow expects the current branch to be either 'develop' or 'release/#{version}'.  Current branch is '#{current_branch}'")
          abort()
        end

        # validate that develop is an ancestor of release branch.  Warn if not, but allow user to proceed, as this may be desired for maintenance releases.
        if current_branch == expected_release_branch
          root_branch = "develop"
          if !GitUtil.is_ancestor?(root_branch, current_branch)
            Printer.check_proceed("#{current_branch} is missing commits from #{root_branch}.  Are you sure you want to continue?", "Please rebase #{current_branch} to include the latest from #{root_branch}.")
          end
        end

        # validate that master is up to date, because git flow requires this.
        validate_local_matches_remote("master")
      else
        unless current_branch == "master"
          Printer.fail("non-git flow expects releases to come from the master branch.  Current branch is '#{current_branch}'")
          abort()
        end
      end

      validate_local_matches_remote(current_branch)
    end

    private

    def validate_local_matches_remote(branch_name)
      local_branch_sha1 = GitUtil.get_local_branch_sha1(branch_name)
      origin_branch_sha1 = GitUtil.get_remote_branch_sha1(branch_name)
      if local_branch_sha1 != origin_branch_sha1
        abort_string = "Branches not in sync: #{Dir.pwd} branch:#{branch_name} at #{local_branch_sha1}, but origin/#{branch_name} is at #{origin_branch_sha1}."\
        "\nIf you received this error on the root project, you may need to:"\
        "\n  1. pull the latest changes from the remote,"\
        "\n  2. push changes up to the remote,"\
        "\n  3. back out a current release in progress."
        Printer.fail(abort_string)
        abort()
      else
        Printer.success("Repo #{Dir.pwd} matches origin/#{branch_name}.")
      end
    end

    class Submodule
      attr_reader :name, :path, :url
      def initialize(name, path, url)
        @name=name
        @path=path
        @url=url
      end
    end

    def rename_file(old_name, new_name)
      is_git_already_clean = GitUtil.is_clean_git?

      GitUtil.move(old_name, new_name)
      # fix any references to file in readme
      replace_string("README.md", "(#{old_name})", "(#{new_name})")
      if is_git_already_clean
        CommandProcessor.command("git add . && git commit -m \"#{@releasinator_config[:releasinator_name]}: rename #{old_name} to #{new_name}\"")
      end
    end

    def rename_alternate_name(expected_file_name, alternate_names)
      alternate_names.each do |name|
        Dir.glob(name) do |entry|
          puts "Found similar file: #{name}."
          rename_file(name, expected_file_name)
          return true
        end
      end
      false
    end

    def get_changelog_contents()
      validate_base_dir
      Dir.chdir(@releasinator_config.base_dir) do
        open('CHANGELOG.md').read
      end
    end
  end
end
