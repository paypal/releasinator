require "test/unit"
require_relative "../lib/config_hash"
 
class TestConfig < Test::Unit::TestCase
  include Releasinator
  def setup
    @releasinator_config = ConfigHash.new(false, false)
  end

  def teardown
  end

  def test_validate_config
    assert_equal("releasinator", @releasinator_config[:releasinator_name])
    assert_false(@releasinator_config[:trace])
    assert_false(@releasinator_config[:verbose])
  end
end
