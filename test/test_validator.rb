require "test/unit"
require 'tempfile'
require_relative "../lib/validator"
require_relative '../lib/downstream_repo'
 
class TestValidator < Test::Unit::TestCase
  include Releasinator
  
  def setup
    @releasinator_config = ConfigHash.new(true, true)
    @validator = Validator.new(@releasinator_config)
    @validator.freeze
    @temp_gitignore = Tempfile.new("TestValidator.gitignore")
  end

  def teardown
    @temp_gitignore.unlink
  end

  # shamelessly copied from https://rubyplus.com/articles/2541-TDD-Beyond-Basics-How-to-Fake-User-Input
  class VirtualInput
    def initialize(strings)
      @strings = strings
    end

    def gets
      next_string = @strings.shift
      # Uncomment the following line if you'd like to see the faked $stdin#gets
      puts "(DEBUG) Faking #gets with: #{next_string}"
      next_string
    end

    def self.with_fake_input(strings)
      $stdin = VirtualInput.new(strings)
      yield
    ensure
      $stdin = STDIN
    end
  end

  def test_validate_exists_success
    assert_nothing_raised do
      @validator.validate_exist(".", "CHANGELOG.md")
      @validator.validate_exist(".", "README.md")
    end
  end

  def test_validate_exists_fail
    assert_raises(SystemExit) {
      VirtualInput.with_fake_input(["n"]) do
        @validator.validate_exist(".", "changelog.md")
      end
    }

    assert_raises(SystemExit) {
      VirtualInput.with_fake_input(["n"]) do
        @validator.validate_exist(".", "readme.md")
      end
    }

    assert_raises(SystemExit) {
      VirtualInput.with_fake_input(["n"]) do
        @validator.validate_exist(".", "asdfasdfa")
      end
    }
  end

  def test_validate_in_path
    assert_nothing_raised do
      @validator.validate_in_path("ls")
      @validator.validate_in_path("which")
    end

    assert_raises(SystemExit) { @validator.validate_in_path("blahblahyeehaw") }
  end

  def test_validate_git_version
    assert_nothing_raised do
      @validator.validate_git_version
    end
  end

  def test_validate_is_type_success
    assert_nothing_raised do
      @validator.validate_is_type(method(:setup), Method)
      @validator.validate_is_type(DownstreamRepo.new("", "", ""), DownstreamRepo)
      @validator.validate_is_type("blah", String)
    end 
  end

  def test_validate_is_type_fail
    assert_raises(SystemExit) { @validator.validate_is_type("blah_string", Method) }
    assert_raises(SystemExit) { @validator.validate_is_type(method(:setup), DownstreamRepo) }
    assert_raises(SystemExit) { @validator.validate_is_type(DownstreamRepo.new("", "", ""), String) }
  end

  def test_validate_method_convention_success
    assert_nothing_raised do
      @validator.validate_method_convention({ "a" => 1, "c" => 2 })
      @validator.validate_method_convention({ "blah_method" => method(:setup) })
      @validator.validate_method_convention({ "multi_methods" => [method(:setup), method(:teardown)] })
    end 
  end

  def test_validate_method_convention_fail
    assert_raises(SystemExit) { @validator.validate_method_convention({ "blah_method" => 1}) }
    assert_raises(SystemExit) { @validator.validate_method_convention({ "blah_methods" => 1}) }
  end

  def test_line_match_in_file_present
    @temp_gitignore.puts("blah/")
    @temp_gitignore.puts("stuff")
    @temp_gitignore.puts("   ")
    @temp_gitignore.close
    assert_true(@validator.line_match_in_file?("blah/", @temp_gitignore.path))
    assert_true(@validator.line_match_in_file?("stuff", @temp_gitignore.path))
    assert_true(@validator.line_match_in_file?("   ", @temp_gitignore.path))
  end

  def test_line_match_in_file_absent
    @temp_gitignore.puts("    blah/")
    @temp_gitignore.puts("blah/    ")
    @temp_gitignore.puts("bl    ah/")
    @temp_gitignore.close
    assert_false(@validator.line_match_in_file?("blah/", @temp_gitignore.path))
  end

  def test_validate_referenced_in_readme_missing_directory
    assert_raises(SystemExit) { @validator.validate_referenced_in_readme("blah") }
  end
end
