require "test/unit"
require "mocha/test_unit"
require_relative "../lib/git_util"

class TestGitUtil < Test::Unit::TestCase
  include Releasinator
  def setup
  end

  def teardown
  end

  def test_all_methods_do_something
    assert_nothing_raised do
      GitUtil.is_clean_git?
      GitUtil.get_current_branch
      GitUtil.untracked_files
      GitUtil.diff
      GitUtil.cached
      GitUtil.repo_url
      GitUtil.delete_branch "blah"
      assert_false(GitUtil.has_branch? "blah")
      `git branch blah`
      assert_true(GitUtil.has_branch? "blah")
      GitUtil.delete_branch "blah"
      assert_false(GitUtil.has_branch? "blah")
      assert_true(GitUtil.exist? "CHANGELOG.md")
      assert_false(GitUtil.exist? "changelog.md")

      assert_true(GitUtil.is_ancestor? "master", "master")
      assert_false(GitUtil.is_ancestor? "master", "gh-pages")
    end
  end

  def test_tags_local
    assert_nothing_raised do
      tags = GitUtil.tags
      assert_true(tags.is_a? Array)
      assert_true(tags.length > 0)
    end
  end

  def test_tags_remote
    assert_nothing_raised do
      tags = GitUtil.tags(true)
      assert_true(tags.is_a? Array)
      assert_true(tags.length > 0)
      tags.each do |tag|
        assert_true(/^\d+\.\d+\.\d+$/.match(tag) != nil)
      end
    end
  end

  def test_tagged_versions
    fake_tags = <<-EOF
    abcd    refs/tags/1.2
    abcd    refs/tags/v1.3
    abcd    refs/tags/1.4.2-beta1
    abcd    refs/tags/1.6.7+pre1
    abcd    refs/tags/some_tag
    EOF

    CommandProcessor.expects(:command).with("git ls-remote --tags").returns(fake_tags)

    assert_nothing_raised do
      tagged_versions = GitUtil.tagged_versions(true)
      assert_true(tagged_versions.is_a? Array)
      assert_true(tagged_versions.length > 0)
      tagged_versions.each do |tag|
        assert_false tag.start_with? 'v'
      end
      assert_equal('1.6.7+pre1', tagged_versions.last)
    end

    CommandProcessor.unstub(:tags)
  end

  def test_tagged_versions_raw_values
    fake_tags = <<-EOF
    abcd    refs/tags/v1.2.0
    abcd    refs/tags/1.3.0
    abcd    refs/tags/1.4.2-beta1
    abcd    refs/tags/v1.6.7+pre1
    abcd    refs/tags/some_tag
    EOF

    CommandProcessor.expects(:command).with("git ls-remote --tags").returns(fake_tags)

    assert_nothing_raised do
      tagged_versions = GitUtil.tagged_versions(remote=true, raw_tags=true)
      assert_equal([
        "v1.2.0",
        "1.3.0",
        "1.4.2-beta1",
        "v1.6.7+pre1"
      ], tagged_versions)
    end

    CommandProcessor.unstub(:tags)
  end

  def test_last_commits
    commits = GitUtil.commits("0.5.0", "0.6.0")
    assert_equal(8, commits.size)
  end
end
