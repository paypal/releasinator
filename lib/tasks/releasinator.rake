require 'rubygems'
require 'bundler/setup'
require 'colorize'
require 'json'
require 'tempfile'
require_relative '../command_processor'
require_relative '../config_hash'
require_relative '../copy_file'
require_relative '../current_release'
require_relative '../downstream'
require_relative '../downstream_repo'
require_relative '../publisher'
require_relative '../validator'
require_relative '../changelog/importer'
require_relative '../changelog/updater'

include Releasinator

DOWNSTREAM_REPOS = "downstream_repos"

desc "read and validate the config, adding one if not found"
task :config do
  @releasinator_config = ConfigHash.new(verbose == true, Rake.application.options.trace == true)
  @releasinator_config.freeze
  @validator = Validator.new(@releasinator_config)
  @validator.freeze
  @validator.validate_config
end

namespace :validate do
  desc "validate the presence, formatting, and semver sequence of CHANGELOG.md"
  task :changelog => [:config, :git] do
    @current_release = @validator.validate_changelog(DOWNSTREAM_REPOS)
    @current_release.freeze
    @downstream = Downstream.new(@releasinator_config, @validator, @current_release)
    @downstream.freeze
  end

  desc "validate important text files end in a newline character"
  task :eof_newlines => :config do
    @validator.validate_eof_newlines
  end

  desc "validate releasinator is up to date"
  task :releasinator_version => :config do
    @validator.validate_releasinator_version
  end

  desc "validate your path has some useful tools"
  task :paths => :config do
    @validator.validate_in_path("wget")
    @validator.validate_in_path("git")
  end

  desc "validate git version is acceptable"
  task :git_version => :config do
    @validator.validate_git_version
  end

  desc "validate git reports no untracked, unstaged, or uncommitted changes"
  task :git => :config do
    @validator.validate_clean_git
  end

  desc "validate current branch matches the latest on the server and follows naming conventions"
  task :branch => [:config, :changelog] do
    @validator.validate_branches(@current_release.version)
  end

  desc "validate the presence of README.md, renaming a similar file if found"
  task :readme => :config do
    @validator.validate_exist('.', "README.md", DOWNSTREAM_REPOS)
    @validator.validate_exist(@releasinator_config.base_dir, "README.md", DOWNSTREAM_REPOS) if '.' != @releasinator_config.base_dir
  end

  desc "validate the presence of LICENSE, renaming a similar file if found - also validates that its referenced from README.md"
  task :license => :config do
    @validator.validate_exist(@releasinator_config.base_dir, "LICENSE", DOWNSTREAM_REPOS)
    @validator.validate_referenced_in_readme("LICENSE")
  end

  desc "validate the presence of CONTRIBUTING.md, renaming a similar file if found - also validates that its referenced from README.md"
  task :contributing => :config do
    @validator.validate_exist(@releasinator_config.base_dir, "CONTRIBUTING.md", DOWNSTREAM_REPOS)
    @validator.validate_referenced_in_readme("CONTRIBUTING.md")
  end

  desc "validate the presence of .github/ISSUE_TEMPLATE.md"
  task :issue_template => :config do
    @validator.validate_exist(@releasinator_config.base_dir, ".github/ISSUE_TEMPLATE.md", DOWNSTREAM_REPOS)
  end

  desc "validate the presence of .gitignore, adding any appropriate releasinator lines if necessary"
  task :gitignore => :config do
    @validator.validate_exist('.', ".gitignore", DOWNSTREAM_REPOS)
    @validator.validate_exist(@releasinator_config.base_dir, ".gitignore", DOWNSTREAM_REPOS) if '.' != @releasinator_config.base_dir
    @validator.validate_gitignore_contents(".DS_Store")
    if @releasinator_config.has_key?(:downstream_repos)
      @validator.validate_gitignore_contents("#{DOWNSTREAM_REPOS}/")
    end
  end

  desc "validate all submodules are on the latest origin/master versions"
  task :submodules => :config do
    @validator.validate_submodules
  end

  desc "validate the current user can push to local repo"
  task :github_permissions_local => [:config] do
    @validator.validate_github_permissions(GitUtil.repo_url)
  end

  desc "validate the current user can push to downstream repos"
  task :github_permissions_downstream, [:downstream_repo_index] => [:config] do |t, args|
    @downstream.validate_github_permissions(args)
  end

  desc "run any configatron.custom_validation_methods"
  task :custom => [:config, :changelog] do
    if @releasinator_config.has_key?(:custom_validation_methods)
      @releasinator_config[:custom_validation_methods].each do |validate_method|
        validate_method.call
      end
      Printer.success("All configatron.custom_validation_methods succeeded.")
    else
      Printer.success("No configatron.custom_validation_methods found.")
    end
  end

  desc "validate all"
  task :all =>
    [
      :paths,
      :eof_newlines,
      :git_version,
      :gitignore,
      :submodules,
      :readme,
      :changelog,
      :license,
      :contributing,
      :issue_template,
      :github_permissions_local,
      :github_permissions_downstream,
      :releasinator_version,
      :custom,
      :git,
      :branch
    ] do
    Printer.success("All validations passed.")
  end
end

desc "Update release version and CHANGELOG"
task :update_version_and_changelog do
  begin
    Changelog::Updater.bump_version(@current_release.version) do |version, semver_type|
      @releasinator_config[:update_version_method].call(version, semver_type)
      Changelog::Updater.prompt_for_change_log(version, semver_type)

      GitUtil.stage
      if @releasinator_config.has_key? :update_version_commit_message
        GitUtil.commit(@releasinator_config[:update_version_commit_message])
      else
        GitUtil.commit("Update version and CHANGELOG.md for #{version}")
      end
    end
  rescue Exception => e
    GitUtil.reset_head(true)
    Printer.fail("Failed to update version: #{e}")
    abort()
  end
end

desc "release all"
task :release => [:"validate:all"] do
  last_tag = GitUtil.tagged_versions(true).last

  if !last_tag.nil? # If last tag is nil, at this point, there must be changelog entry, but this is the first releasinator release, proceed.
    last_tag = Semantic::Version.new(last_tag)
    commits_since_tag = GitUtil.commits(last_tag)
    if commits_since_tag.size > 0 # There are new commits to be released
      if @current_release.version > last_tag # CHANGELOG.md version is ahead of last tag. The releaser has already updated the changelog, and we've valdidated it
        if !Printer.ask_binary("The version from CHANGELOG.md '#{@current_release.version}' is greater than the last tagged version '#{last_tag}'. Have you already updated your version and CHANGELOG.md?")
          Printer.fail("Update your version and CHANGELOG.md and re-run rake release.")
          abort()
        end
      elsif @releasinator_config.has_key? :update_version_method
        if Printer.ask_binary("It doesn't look like your CHANGELOG.md has been updated. HEAD is #{commits_since_tag.size} commits ahead of tag #{last_tag}. Do you want to update CHANGELOG.md and version now?")
          Rake::Task[:update_version_and_changelog].invoke
          Rake::Task[:"validate:changelog"].reenable
          Rake::Task[:"validate:changelog"].invoke
        else
          Printer.fail("Update your version and CHANGELOG.md and re-run rake release.")
          abort()
        end
      else
        Printer.fail("It doesn't look like your CHANGELOG.md has been updated. HEAD is #{commits_since_tag.size} commits ahead of last tagged version '#{last_tag}'. Please update CHANGELOG.md or implement update_version_method in .releasinator.rb to allow releasinator to perform this step on your behalf. See https://github.com/paypal/releasinator for more details.")
        abort()
      end
    elsif !Printer.ask_binary("There are no new commits since last tagged version '#{last_tag}'. Are you sure you want to release?")
      abort()
    end
  elsif !Printer.ask_binary("This release (#{@current_release.version}) is the first release. Do you want to continue?")
    abort()
  end

  [:"local:build",:"pm:all",:"downstream:all",:"local:push",:"docs:all"].each do |task|
    Rake::Task[task].invoke
  end

  Printer.success("Done releasing #{@current_release.version}")
end

namespace :import do
  desc "import a changelog from release notes contained within GitHub releases"
  task :changelog => [:config] do
    Changelog::Importer.new(@releasinator_config).import(GitUtil.repo_url)
  end
end

namespace :local do
  desc "ask user whether to proceed with release"
  task :confirm => [:config, :"validate:changelog"] do
    Printer.check_proceed("You're about to release #{@current_release.version}!", "Then no release for you!")
  end

  desc "change branch for git flow, if using git flow"
  task :prepare => [:config, :"validate:changelog"] do
    if @releasinator_config.use_git_flow()
      CommandProcessor.command("git checkout -b release/#{@current_release.version} develop") unless GitUtil.get_current_branch() != "develop"
    end
  end

  desc "tag the local repo"
  task :tag => [:config, :"validate:changelog"] do
    GitUtil.tag(@current_release.version, @current_release.changelog)
  end

  desc "iterate over the prerelease_checklist_items, asking the user if each is done"
  task :checklist => [:config] do
    @releasinator_config[:prerelease_checklist_items].each do |prerelease_item|
      Printer.check_proceed("#{prerelease_item}", "Then no release for you!")
    end
  end

  desc "build the local repo"
  task :build => [:config, :"validate:changelog", :checklist, :confirm, :prepare, :tag] do
    puts "building #{@current_release.version}" if @releasinator_config[:verbose]
    @releasinator_config[:build_method].call
    if @releasinator_config.has_key? :post_build_methods
      @releasinator_config[:post_build_methods].each do |post_build_method|
        post_build_method.call(@current_release.version)
      end
    end
  end

  desc "run the git flow branch magic (if configured) and push local to remote"
  task :push => [:config, :"validate:changelog"] do
    if @releasinator_config.use_git_flow()
      CommandProcessor.command("git checkout master")
      CommandProcessor.command("git merge --no-ff release/#{@current_release.version}")
      GitUtil.delete_branch "release/#{@current_release.version}"
      # still on master, so let's push it
    end

    GitUtil.push_branch("master")

    if @releasinator_config.use_git_flow()
      # switch back to develop to merge and continue development
      GitUtil.checkout("develop")
      CommandProcessor.command("git merge master")
      GitUtil.push_branch("develop")
    end
    GitUtil.push_tag(@current_release.version)
    if @releasinator_config[:release_to_github]
      # TODO - check that the tag exists
      CommandProcessor.command("sleep 5")
      Publisher.new(@releasinator_config).publish(GitUtil.repo_url, @current_release)
    end

    if @releasinator_config.has_key? :post_push_methods
      @releasinator_config[:post_push_methods].each do |post_push_method|
        post_push_method.call(@current_release.version)
      end
    end
  end
end

namespace :pm do
  desc "publish and wait for package manager"
  task :all => [:publish, :wait]

  desc "call configured publish_to_package_manager_method"
  task :publish => [:config, :"validate:changelog"] do
    @releasinator_config[:publish_to_package_manager_method].call(@current_release.version)
  end

  desc "call configured wait_for_package_manager_method"
  task :wait => [:config, :"validate:changelog"] do
    @releasinator_config[:wait_for_package_manager_method].call(@current_release.version)
  end
end

def copy_the_file(root_dir, copy_file, version=nil)
  Dir.mkdir(copy_file.target_dir) unless File.exist?(copy_file.target_dir)
  # use __VERSION__ to auto-substitute the version in any input param
  source_file_name = copy_file.source_file.gsub("__VERSION__", "#{version}")
  target_dir_name = copy_file.target_dir.gsub("__VERSION__", "#{version}")
  destination_file_name = copy_file.target_name.gsub("__VERSION__", "#{version}")
  CommandProcessor.command("cp -R #{root_dir}/#{source_file_name} #{target_dir_name}/#{destination_file_name}")
end

def get_new_branch_name(new_branch_name, version)
  new_branch_name.gsub("__VERSION__", "#{version}")
end

namespace :downstream do
  desc "build, package, and push all downstream repos"
  task :all => [:reset,:prepare,:build,:package,:push] do
    Printer.success("Done with all downstream tasks.")
  end

  desc "reset the downstream repos to their starting state"
  task :reset, [:downstream_repo_index] => [:config, :"validate:changelog"] do |t, args|
    @downstream.reset(args)
  end

  desc "prepare downstream release, copying files from base_docs_dir and any other configured files"
  task :prepare, [:downstream_repo_index] => [:config, :"validate:changelog", :reset] do |t, args|
    @downstream.prepare(args)
  end

  desc "call all build_methods for each downstream repo"
  task :build, [:downstream_repo_index] => [:config,:"validate:changelog"] do |t, args|
    @downstream.build(args)
  end

  desc "tag all non-branch downstream repos"
  task :package, [:downstream_repo_index] => [:config,:"validate:changelog"] do |t, args|
    @downstream.package(args)
  end

  desc "push tags and creates draft release, or pushes branch and creates pull request, depending on the presence of new_branch_name"
  task :push, [:downstream_repo_index] => [:config,:"validate:changelog"] do |t, args|
    @downstream.push(args)
  end
end

namespace :docs do
  desc "build, copy, and push docs to gh-pages branch"
  task :all => [:build, :package, :push]

  desc "build docs"
  task :build => [:config] do
    if @releasinator_config.has_key?(:doc_build_method)
      @releasinator_config[:doc_build_method].call
      Printer.success("doc_build_method done.")
    else
      Printer.success("No doc_build_method found.")
    end
  end

  desc "copy and commit docs to gh-pages branch"
  task :package => [:config,:"validate:changelog"] do
    if @releasinator_config.has_key?(:doc_files_to_copy)
      root_dir = Dir.pwd.strip

      Dir.chdir(@releasinator_config.doc_target_dir) do
        current_branch = GitUtil.get_current_branch()

        GitUtil.init_gh_pages()
        GitUtil.reset_repo("gh-pages")
        @releasinator_config[:doc_files_to_copy].each do |copy_file|
          copy_the_file(root_dir, copy_file)
        end

        CommandProcessor.command("git add .")
        CommandProcessor.command("git commit -m \"Update docs for release #{@current_release.version}\"")

        # switch back to previous branch
        CommandProcessor.command("git checkout #{current_branch}")
      end
      Printer.success("Doc files copied.")
    else
      Printer.success("No doc_files_to_copy found.")
    end
  end

  desc "push gh-pages branch"
  task :push => [:config] do
    if @releasinator_config.has_key?(:doc_build_method)
      Dir.chdir(@releasinator_config.doc_target_dir) do
        current_branch = GitUtil.get_current_branch()
        CommandProcessor.command("git checkout gh-pages")
        GitUtil.push_branch("gh-pages")
        # switch back to previous branch
        CommandProcessor.command("git checkout #{current_branch}")
      end
      Printer.success("Docs pushed.")
    else
      Printer.success("No docs pushed.")
    end
  end
end

def replace_string(filepath, string_to_replace, new_string)
  text = File.read(filepath)
  new_contents = text.gsub(string_to_replace, new_string)

  File.open(filepath, "w") {|file| file.puts new_contents }
end
