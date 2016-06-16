require "test/unit"
require_relative "../lib/config_hash"
 
class TestConfig < Test::Unit::TestCase
  include Releasinator
  def setup
    @config = ConfigHash.new(false, false)
  end

  def teardown
  end

  def test_validate_config
    assert_equal("releasinator", @config[:releasinator_name])
    assert_false(@config[:trace])
    assert_false(@config[:verbose])
  end
end
