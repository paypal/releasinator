require_relative 'command_processor'
require_relative 'downstream_repo'
require_relative 'git_util'
require_relative 'printer'
require_relative 'publisher'

module Releasinator
  class Downstream

    def initialize(releasinator_config, validator, current_release)
      @releasinator_config = releasinator_config
      @validator = validator
      @current_release = current_release
    end

    def validate_github_permissions(args)
      if @releasinator_config.has_key?(:downstream_repos)
        get_downstream_repos(args[:downstream_repo_index]).each do |downstream_repo, index|
          @validator.validate_github_permissions(downstream_repo.url)
        end
      else
        Printer.success("Not validating permissions of downstream repos.  None found.")
      end
    end

    def reset(args)
      if @releasinator_config.has_key?(:downstream_repos)
        get_downstream_repos(args[:downstream_repo_index]).each do |downstream_repo, index|
          puts "resetting downstream_repo[#{index}]: #{downstream_repo.url}" if @releasinator_config[:verbose]
          Dir.mkdir(DOWNSTREAM_REPOS) unless File.exist?(DOWNSTREAM_REPOS)
          Dir.chdir(DOWNSTREAM_REPOS) do
            CommandProcessor.command("git clone --origin origin #{downstream_repo.url} #{downstream_repo.name}") unless File.exist?(downstream_repo.name)

            Dir.chdir(downstream_repo.name) do
              GitUtil.reset_repo(downstream_repo.branch)

              if downstream_repo.options.has_key? :new_branch_name
                new_branch_name = get_new_branch_name(downstream_repo.options[:new_branch_name], @current_release.version)
                GitUtil.delete_branch new_branch_name
              end
            end
          end
        end
        Printer.success("Done resetting downstream repos.")
      else
        Printer.success("Not resetting downstream repos.  None found.")
      end
    end

    def prepare(args)
      if @releasinator_config.has_key?(:downstream_repos)
        get_downstream_repos(args[:downstream_repo_index]).each do |downstream_repo, index|
          puts "preparing downstream_repo[#{index}]: #{downstream_repo.url}" if @releasinator_config[:verbose]

          root_dir = Dir.pwd.strip
          copy_from_dir = root_dir + "/" + @releasinator_config.base_dir

          Dir.chdir(DOWNSTREAM_REPOS) do
            Dir.chdir(downstream_repo.name) do

              if downstream_repo.options.has_key? :new_branch_name
                new_branch_name = get_new_branch_name(downstream_repo.options[:new_branch_name], @current_release.version)
                CommandProcessor.command("git checkout -b #{new_branch_name}")
              end

              if downstream_repo.full_file_sync
                # remove old everything
                CommandProcessor.command("rm -rf *")

                # update all distribution files
                CommandProcessor.command("rsync -av --exclude='#{DOWNSTREAM_REPOS}' --exclude='.git/' #{copy_from_dir}/* .")
                CommandProcessor.command("rsync -av --exclude='#{DOWNSTREAM_REPOS}' --exclude='.git/' #{copy_from_dir}/.[!.]* .")
              end

              # copy custom files
              if downstream_repo.options.has_key? :files_to_copy
                downstream_repo.options[:files_to_copy].each do |copy_file|
                  copy_the_file(root_dir, copy_file, @current_release.version)
                end
              end

              if downstream_repo.options.has_key? :post_copy_methods
                downstream_repo.options[:post_copy_methods].each do |method|
                  method.call(@current_release.version)
                end
              end

              if GitUtil.is_clean_git?
                Printer.fail("Nothing changed in #{downstream_repo.name}!")
                abort()
              end
              # add everything to git and commit
              CommandProcessor.command("git add .")
              CommandProcessor.command("git add -u .")
              if downstream_repo.options.has_key? :new_branch_name
                commit_message = "Update #{@releasinator_config[:product_name]} to #{@current_release.version}"
              else
                commit_message = "Release #{@current_release.version}"
              end
              CommandProcessor.command("git commit -am \"#{commit_message}\"")
            end
          end
        end
        Printer.success("Done preparing downstream repos.")
      else
        Printer.success("Not preparing downstream repos.  None found.")
      end
    end

    def build(args)
      if @releasinator_config.has_key?(:downstream_repos)
        get_downstream_repos(args[:downstream_repo_index]).each do |downstream_repo, index|
          puts "building downstream_repo[#{index}]: #{downstream_repo.url}" if @releasinator_config[:verbose]
          Dir.chdir(DOWNSTREAM_REPOS) do
            Dir.chdir(downstream_repo.name) do
              # build any files to verify release
              if downstream_repo.options.has_key? :build_methods
                downstream_repo.options[:build_methods].each do |method|
                  method.call
                end
              end
            end
          end
        end
        Printer.success("Done building downstream repos.")
      else
        Printer.success("Not building downstream repos.  None found.")
      end
    end

    def package(args)
      if @releasinator_config.has_key?(:downstream_repos)
        get_downstream_repos(args[:downstream_repo_index]).each do |downstream_repo, index|
          puts "packaging downstream_repo[#{index}]: #{downstream_repo.url}" if @releasinator_config[:verbose]
          Dir.chdir(DOWNSTREAM_REPOS) do
            Dir.chdir(downstream_repo.name) do
              # don't tag those where new branches are created
              GitUtil.tag(@current_release.version, @current_release.changelog) unless downstream_repo.options.has_key? :new_branch_name
            end
          end
        end
        Printer.success("Done packaging downstream repos.")
      else
        Printer.success("Not packaging downstream repos.  None found.")
      end
    end

    def push(args)
      if @releasinator_config.has_key?(:downstream_repos)
        get_downstream_repos(args[:downstream_repo_index]).each do |downstream_repo, index|
          puts "pushing downstream_repo[#{index}]: #{downstream_repo.url}" if @releasinator_config[:verbose]
          Dir.chdir(DOWNSTREAM_REPOS) do
            Dir.chdir(downstream_repo.name) do
              if downstream_repo.options.has_key? :new_branch_name
                new_branch_name = get_new_branch_name(downstream_repo.options[:new_branch_name], @current_release.version)
                CommandProcessor.command("git push -u origin #{new_branch_name}")
                # TODO - check that the branch exists
                CommandProcessor.command("sleep 5")
                Publisher.new(@releasinator_config).publish_pull_request(downstream_repo.url, @current_release, @releasinator_config[:product_name], downstream_repo.branch, new_branch_name)
              else
                GitUtil.push_branch("master")
                GitUtil.push_tag(@current_release.version)
                # TODO - check that the tag exists
                CommandProcessor.command("sleep 5")
                Publisher.new(@releasinator_config).publish(downstream_repo.url, @current_release) unless ! downstream_repo.release_to_github
              end
            end
          end
        end
        Printer.success("Done pushing downstream repos.")
      else
        Printer.success("Not pushing downstream repos.  None found.")
      end
    end

    private

    def get_downstream_repos(downstream_repo_index)
      repos_to_iterate_over = {}
      if downstream_repo_index
        index = Integer(downstream_repo_index) rescue false
        if !index
          Printer.fail("downstream_repo_index:#{downstream_repo_index} not a valid integer")
          abort()
        end
        downstream_repo_max_index = @releasinator_config[:downstream_repos].size - 1
        if index < 0
          Printer.fail("Index out of bounds downstream_repo_index: #{index} < 0")
          abort()
        end
        if index > downstream_repo_max_index
          Printer.fail("Index out of bounds downstream_repo_index: #{index} >= #{downstream_repo_max_index}")
          abort()
        end
        # keep original index for printing
        repos_to_iterate_over[@releasinator_config[:downstream_repos][index]] = index
      else
        @releasinator_config[:downstream_repos].each_with_index do |downstream_repo, index|
          repos_to_iterate_over[downstream_repo] = index
        end
      end
      repos_to_iterate_over
    end
  end
end
