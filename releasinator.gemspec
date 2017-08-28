# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'releasinator/version'

Gem::Specification.new do |spec|
  spec.name          = "releasinator"
  spec.version       = Releasinator::VERSION
  spec.authors       = ["PayPal"]
  spec.email         = ["DL-PP-RUBY-SDK@paypal.com"]
  spec.summary       = %q{The releasinator assists in building and releasing open source projects.}
  spec.description   = %q{The releasinator assists in building and releasing open source projects.}
  spec.homepage      = "https://developer.paypal.com"
  spec.license       = "Apache-2.0"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 11.1"
  spec.add_development_dependency "test-unit", "~> 3.1"
  spec.add_development_dependency "mocha", "~> 1.3.0"

  spec.add_dependency "configatron", "~> 4.5"
  spec.add_dependency "colorize", "~> 0.7"
  spec.add_dependency "vandamme", "~> 0.0.11"
  spec.add_dependency "semantic", "~> 1.4"
  spec.add_dependency "json", "~> 1.8"
  spec.add_dependency "octokit", "~> 4.0"

end
