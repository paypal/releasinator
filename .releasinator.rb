require 'releasinator/version'

configatron.product_name = "Releasinator"

# List of items to confirm from the person releasing.  Required, but empty list is ok.
configatron.prerelease_checklist_items = [
]

def validate_version_match()
  spec_version = Releasinator::VERSION
  if spec_version != @current_release.version
    Printer.fail("Ruby gem spec version #{spec_version} does not match changelog version #{@current_release.version}.")
    abort()
  end

  Printer.success("Ruby gem spec version #{spec_version} matches latest changelog version.")
end

def validate_ruby_gem_credentials()
  file_path = Dir.home() + "/.gem/credentials"
  if !File.exist?(file_path)
    Printer.fail("Please create " + file_path.bold + " with the proper credentials.")
    abort()
  else
    Printer.success(file_path.bold + " found.")
  end
end

configatron.custom_validation_methods = [
  method(:validate_version_match),
  method(:validate_ruby_gem_credentials)
]


def build_method
  # run tests first
  # detect non-zero failures/errors, since ruby command won't exit properly if unit tests called exit/abort
  output = CommandProcessor.command("ruby test/ts_allTests.rb | cat", live_output=true)
  if !output.match /assertions, 0 failures, 0 errors, 0 pendings, 0 omissions, 0 notifications$/
    Printer.fail("There were unit test failures.")
    abort()
  end

  output_dir = "build"
  CommandProcessor.command("gem build releasinator.gemspec")
  Dir.mkdir(output_dir) unless File.exists?(output_dir)
  CommandProcessor.command("mv releasinator-*.gem #{output_dir}")
end

# The command that builds the project.  Required.
configatron.build_method = method(:build_method)

def update_version_method(version, semver_type)
  version_file = "lib/releasinator/version.rb"

  text = File.read(version_file)
  replace = text.gsub(Releasinator::VERSION, version)
  File.open(version_file, "w") {|file| file.puts replace}
end

# The command that populates a new version to all relevant files.  Required.
configatron.update_version_method = method(:update_version_method)

def publish_to_package_manager(version)
  output_dir = "build"
  Dir.chdir(output_dir) do
    CommandProcessor.command("gem push releasinator-#{version}.gem")
  end
end

# The method that publishes the project to the package manager.  Required.
configatron.publish_to_package_manager_method = method(:publish_to_package_manager)


def wait_for_package_manager(version)
  CommandProcessor.wait_for("wget -U \"non-empty-user-agent\" -qO- https://rubygems.org/gems/releasinator/versions/#{version} | cat")
end

# The method that waits for the package manager to be done.  Required
configatron.wait_for_package_manager_method = method(:wait_for_package_manager)

# Whether to publish the root repo to GitHub.  Required.
configatron.release_to_github = true
