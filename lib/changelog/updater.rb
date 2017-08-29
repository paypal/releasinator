require 'tmpdir'

require_relative '../command_processor'
require_relative '../printer'
require_relative '../git_util'

module Releasinator
  module Changelog
    class Updater

      def self.bump_version(version)
        loop do
          term = Printer.ask("What type of release is this? (major, minor, patch)")

          case term
          when "major", "minor", "patch"
            current_version = Semantic::Version.new(version).increment!(term.to_sym).to_s
            yield(current_version, term)

            return current_version
          else
            Printer.fail("release type must be one of: [major, minor, patch]")
          end
        end
      end

      def self.prompt_for_change_log(version, semver_type)
        new_changes = Dir.mktmpdir do |dir|
          tmp_cl = "#{dir}/tmp-changelog-release#{Time.now.to_i}.md"
          last_version = GitUtil.tags.last
          tmp_change_log = "\n\n# Please enter a bulleted CHANGELOG list summarizing the changes for #{semver_type} version #{version}."
          tmp_change_log += "\n# Lines starting with '# ' will be ignored."
          tmp_change_log += "\n#"
          tmp_change_log += "\n# Changes since #{last_version}:"
          tmp_change_log += "\n#"
          tmp_change_log += "\n# "
          tmp_change_log += GitUtil.commits(from_tag=last_version).reverse.join("\n# ")
          tmp_change_log += "\n#"
          tmp_change_log += "\n"
          File.foreach("CHANGELOG.md") do |line|
            tmp_change_log += "# #{line}"
          end
          File.open(tmp_cl, "w") {|file| file.puts tmp_change_log }

          editor = ENV["EDITOR"]
          if editor == nil
            Printer.fail("Value of $EDITOR environment variable must be set in order to edit CHANGELOG")
            abort()
          elsif "" == CommandProcessor.command("which #{editor} | cat")
            Printer.fail("Value of $EDITOR (#{editor}) not found on path")
            abort()
          end

          system("$EDITOR #{tmp_cl}")

          new_changes = ""
          File.foreach(tmp_cl) do |line|
            if !line.start_with?("# ") && !line.start_with?("#\n")
              new_changes += line
            end
          end

          new_changes
        end

        self.update_changelog(new_changes, version)
      end

      private
      def self.update_changelog(new_changes, version)
        changelog = "CHANGELOG.md"

        in_header = true
        header = ""
        old_changes = ""
        File.open(changelog, "r") do |file|
          file.each_line do |line|
            if in_header
              in_header = !/\d+\.\d+\.\d+$/.match(line)
            end

            if in_header
              header += line
            else
              old_changes += line
            end
          end
        end

        h2 = old_changes.start_with? "##"
        if h2
          new_changes = "## #{version}\n" + new_changes
        else
          new_changes = "#{version}\n-----\n" + new_changes
        end

        File.open(changelog, "w") {|file| file.puts(header + new_changes.chomp + "\n" + old_changes.chomp) }
      end
    end
  end
end
