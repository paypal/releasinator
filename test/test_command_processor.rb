require "test/unit"
require_relative "../lib/command_processor"
 
class TestCommandProcessor < Test::Unit::TestCase
  include Releasinator
  def setup
  end

  def teardown
  end

  def test_validate_methods_work
    assert_not_nil(CommandProcessor.command("ls -al"))
    assert_not_nil(CommandProcessor.command("ls -al", live_output=true))
  end
end
