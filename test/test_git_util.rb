require "test/unit"
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
    end 
  end
end
