require "test/unit"
require 'tempfile'
require 'open-uri'
require_relative "../lib/validator_changelog"
 
class TestValidatorChangelog < Test::Unit::TestCase
  include Releasinator
  
  def setup
    config = {:verbose => false}
    @validator_changelog = ValidatorChangelog.new(config)

    @temp_changelog = Tempfile.new("TestValidatorChangelog.changelog")
  end

  def teardown
    @temp_changelog.unlink
  end

  def test_validate_semver_success
    assert_nothing_raised do
      @validator_changelog.validate_semver({ "1.0.1" => "", "1.0.0" => "" })
      @validator_changelog.validate_semver({ "1.1.0" => "", "1.0.1" => "" })
      @validator_changelog.validate_semver({ "1.1.1" => "", "1.1.0" => "" })
      @validator_changelog.validate_semver({ "2.0.0" => "", "1.1.1" => "" })
      @validator_changelog.validate_semver({ "2.0.1" => "", "2.0.0" => "" })
      @validator_changelog.validate_semver({ "99.0.0" => "", "98.99.98" => "" })
      @validator_changelog.validate_semver({ "99.99.0" => "", "99.98.99" => "" })
      @validator_changelog.validate_semver({ "99.99.99" => "", "99.99.98" => "" })
      @validator_changelog.validate_semver({ "99.99.99" => "", "99.99.98" => "" })
    end 
  end

  def test_validate_semver_fail
    assert_raises(SystemExit) {@validator_changelog.validate_semver({ "1.0.0" => "", "1.0.1" => "" })}
    assert_raises(SystemExit) {@validator_changelog.validate_semver({ "1.0.0" => "", "1.1.0" => "" })}
    assert_raises(SystemExit) {@validator_changelog.validate_semver({ "1.0.0" => "", "2.0.0" => "" })}
    assert_raises(SystemExit) {@validator_changelog.validate_semver({ "1.0.2" => "", "1.0.0" => "" })}
    assert_raises(SystemExit) {@validator_changelog.validate_semver({ "1.2.0" => "", "1.0.0" => "" })}
    assert_raises(SystemExit) {@validator_changelog.validate_semver({ "2.0.2" => "", "1.0.0" => "" })}
    assert_raises(SystemExit) {@validator_changelog.validate_semver({ "0.0.2" => "", "0.0.0" => "" })}
    assert_raises(SystemExit) {@validator_changelog.validate_semver({ "99.99.99" => "", "1.0.0" => "" })}
  end

  def test_validate_bullets_success
    assert_nothing_raised do
      @validator_changelog.validate_single_changelog_entry("* contents.")
      @validator_changelog.validate_single_changelog_entry("* contents?")
      @validator_changelog.validate_single_changelog_entry("* contents:")
      @validator_changelog.validate_single_changelog_entry("* contents,")
      @validator_changelog.validate_single_changelog_entry("* contents!")
    end 
  end

  def test_validate_bullets_fail
    #assert_raises(SystemExit) {@validator_changelog.validate_single_changelog_entry("* contents")}
    #assert_raises(SystemExit) {@validator_changelog.validate_single_changelog_entry("* contents with extra space after period. ")}
    #assert_raises(SystemExit) {@validator_changelog.validate_single_changelog_entry("      * whitespace tabbed asterix contents")}
  end


  def test_validate_semver_w_prefix_success
    assert_nothing_raised do
      @validator_changelog.validate_semver({ "v1.0.1" => "", "v1.0.0" => "" })
      @validator_changelog.validate_semver({ "version1.1.0" => "", "version1.0.1" => "" })
      @validator_changelog.validate_semver({ "------------1.1.1" => "", "------------1.1.0" => "" })
      @validator_changelog.validate_semver({ "v1.1.1" => "", "v1.1.1-beta" => "" })
    end 
  end

  def test_validate_semver_w_prefix_fail
    assert_raises(SystemExit) {@validator_changelog.validate_semver("v1.0.1" => "", "1.0.0" => "" )}
    assert_raises(SystemExit) {@validator_changelog.validate_semver("1.0.1" => "", "v1.0.0" => "" )}
    assert_raises(SystemExit) {@validator_changelog.validate_semver("v1.0.1" => "", "version1.0.0" => "" )}
    assert_raises(SystemExit) {@validator_changelog.validate_semver("v1.1.1-beta" => "", "v1.1.1" => "" )}
  end

  def test_validate_changelog_contents_empty
    assert_raises(SystemExit) {@validator_changelog.validate_changelog_contents("")}
  end

  def test_validate_changelog_contents_one
    assert_nothing_raised do
      contents = "1.1.1\n----\ncontents"
      expected_current_release = CurrentRelease.new("1.1.1", "contents")
      actual_current_release = @validator_changelog.validate_changelog_contents(contents)
      assert_equal(expected_current_release.version, actual_current_release.version)
      assert_equal(expected_current_release.changelog, actual_current_release.changelog)
    end
  end

  def test_validate_changelog_contents_multi
    assert_nothing_raised do
      contents = "Project.name.with dot in HEADER\n==========\n\n"
      contents += "1.1.2\n----\ncontents"
      contents += "\n\n1.1.1\n----\ncontents"
      contents += "\n\n1.1.0\n----\ncontents"
      expected_current_release = CurrentRelease.new("1.1.2", "contents")
      actual_current_release = @validator_changelog.validate_changelog_contents(contents)
      assert_equal(expected_current_release.version, actual_current_release.version)
      assert_equal(expected_current_release.changelog, actual_current_release.changelog)
    end
  end
end
