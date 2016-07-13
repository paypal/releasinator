require 'octokit'
require 'colorize'
require_relative 'github_repo'
require_relative 'printer'

module Releasinator
  class Publisher
    def initialize(releasinator_config)
      @releasinator_config = releasinator_config
    end

    def publish(repo_url, release)
      github_repo = GitHubRepo.new(repo_url)

      begin
        # https://github.com/octokit/octokit.rb/blob/master/spec/octokit/client/releases_spec.rb#L18
        github_release = github_repo.client.create_release "#{github_repo.org}/#{github_repo.repo}",
          release.version,
          :name => release.version,
          :body => release.changelog
        puts github_release.inspect if @releasinator_config[:trace]
      rescue => error
        #This will fail if the user does not have push permissions.
        Printer.fail(error.inspect)
        abort()
      end
    end

    def upload_asset(repo_url, release, path_or_file, content_type)
      begin
        github_repo = GitHubRepo.new(repo_url)
        github_release = github_repo.client.release_for_tag "#{github_repo.org}/#{github_repo.repo}", release.version
        github_repo.client.upload_asset github_release.url, path_or_file, :content_type => content_type
      rescue => error
        #This will fail if it cannot upload the files
        Printer.fail(error.inspect)
        abort()
      end
    end

    def publish_pull_request(repo_url, release, product_name, base, head)
      begin
        github_repo = GitHubRepo.new(repo_url)
        github_pull_request = github_repo.client.create_pull_request "#{github_repo.org}/#{github_repo.repo}",
          base,
          head,
          "Update #{product_name} to #{release.version}",
          release.changelog
        puts github_pull_request.inspect if @releasinator_config[:trace]
      rescue => error
        #This will fail if there's already a pull request
        Printer.fail(error.inspect)
        abort()
      end
    end
  end
end
