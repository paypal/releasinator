require_relative "../lib/github_repo"
require "test/unit"
 
class TestGitHubRepo < Test::Unit::TestCase
  include Releasinator
  
  def test_ssh
    ENV["GITHUB_TOKEN"] = "mock"
  	github_repo = GitHubRepo.new("git@github.com:braebot/test.git")
    assert_equal("braebot", github_repo.org)
    assert_equal("test", github_repo.repo)
    assert_equal("github.com", github_repo.domain)
  end

  def test_https
    ENV["GITHUB_TOKEN"] = "mock"
    github_repo = GitHubRepo.new("https://github.com/braebot/test.git")
    assert_equal("braebot", github_repo.org)
    assert_equal("test", github_repo.repo)
    assert_equal("github.com", github_repo.domain)
  end

  def test_enterprise
    ENV["GITHUB_EXAMPLE_COM_GITHUB_TOKEN"] = "mock"
    github_repo = GitHubRepo.new("git@github.example.com:org-name/repo-name.git")
    assert_equal("org-name", github_repo.org)
    assert_equal("repo-name", github_repo.repo)
    assert_equal("github.example.com", github_repo.domain)
  end
end
