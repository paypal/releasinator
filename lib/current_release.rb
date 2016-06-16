module Releasinator
  class CurrentRelease
    attr_reader :version, :changelog
    def initialize(version, changelog)
      @version = version
      @version.freeze
      @changelog = changelog
      @changelog.freeze
    end
  end
end
