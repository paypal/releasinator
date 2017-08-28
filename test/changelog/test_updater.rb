require "test/unit"
require_relative "../../lib/changelog/updater"

class TestUpdater < Test::Unit::TestCase
  include Releasinator

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

  def test_bump_version_bumps_version
    VirtualInput.with_fake_input(["major"]) do
      Changelog::Updater.bump_version "2.1.0" do |nv|
        assert_true(nv == "3.0.0")
      end
    end

    VirtualInput.with_fake_input(["minor"]) do
      Changelog::Updater.bump_version "2.1.0" do |nv|
        assert_true(nv == "2.2.0")
      end
    end

    VirtualInput.with_fake_input(["patch"]) do
      Changelog::Updater.bump_version "2.1.0" do |nv|
        assert_true(nv == "2.1.1")
      end
    end
  end
end
