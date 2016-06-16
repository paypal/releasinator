require 'colorize'
require 'octokit'
require_relative 'printer'

module Releasinator
  class GitHubRepo
    attr_reader :url, :org, :repo, :domain, :client

    def initialize(url)
      @url = url
      if url.start_with?("https")
        # https: "https://github.com/braebot/test.git"
        slash_split = url.split("/")
        @domain = slash_split[2]
        @repo = slash_split.last.split(".git").first
        slash_split.pop
        @org = slash_split.last
      else
        # ssh: git@github.com:braebot/test.git"
        colon_split = url.split(":")
        at_split = colon_split.first.split("@")
        @domain = at_split.last
        slash_split = colon_split.last.split("/")
        @org = slash_split.first
        @repo = slash_split.last.split(".git").first
      end

      @url.freeze
      @org.freeze
      @repo.freeze
      @domain.freeze

      if @domain == "github.com"
        check_token("GITHUB_TOKEN")
        @client = Octokit::Client.new(:access_token => ENV["GITHUB_TOKEN"])
      else
        env_key = "#{@domain.gsub(".", "_").upcase}_GITHUB_TOKEN"
        check_token(env_key)
        @client = Octokit::Client.new(:access_token => ENV[env_key], :api_endpoint => "https://#{@domain}/api/v3/")
      end
    end

    def check_token(token_param)
      if !ENV[token_param]
        Printer.fail("#{token_param} environment variable required.  Please set this to your personal access token.")
        abort()
      end 
    end
  end
end
