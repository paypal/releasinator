require 'colorize'
require 'vandamme'
require 'semantic'
require_relative "../current_release"
require_relative '../printer'

module Releasinator
  module Changelog
    class Validator
      RELEASE_REGEX = /\d+\.\d+\.\d+/

      def initialize(releasinator_config)
        @releasinator_config = releasinator_config
      end

      # assume changelog_hash is not empty
      def validate_semver(changelog_hash)
        latest_release, latest_release_changelog = changelog_hash.first
        # extract prefix from first release to use on all subsequent releases
        latest_release_prefix = latest_release.partition(RELEASE_REGEX)[0]

        newer_version = nil
        changelog_hash.each do |key,value|
          prefix, version, suffix = key.partition(RELEASE_REGEX)
          puts "Checking version with prefix:'#{prefix}', version:'#{version}', suffix:'#{suffix}'." if @releasinator_config[:verbose]
          if prefix != latest_release_prefix
            Printer.fail("version #{key} does not start with extracted prefix '#{latest_release_prefix}'.")
            abort()
          end
          older_version = Semantic::Version.new version

          if nil != newer_version
            version_comp = newer_version <=> older_version
            if version_comp < 0
              Printer.fail("Semver releases out of order: #{older_version} should be smaller than #{newer_version}")
              abort()
            elsif version_comp == 0
              # this case cannot be found with Vandamme library because 2 versions in a row get overwritten in the underlying hash
              if suffix.empty?
                Printer.fail("2 semver releases in a row without a suffix (like -beta, -rc1, etc...) is not allowed.")
                abort()
              end
            else
              error_suffix = "version increment error - comparing #{newer_version} to #{older_version} does not pass semver validation."
              # validate the next sequence in semver
              if newer_version.major == older_version.major
                if newer_version.minor == older_version.minor
                  check_semver_criteria(newer_version.patch == older_version.patch + 1, "patch #{error_suffix}")
                else
                  check_semver_criteria(newer_version.minor == older_version.minor + 1 && newer_version.patch == 0, "minor #{error_suffix}")
                end
              else
                check_semver_criteria(newer_version.major == older_version.major + 1 && newer_version.minor == 0 && newer_version.patch == 0, "major #{error_suffix}")
              end
            end
          end
          newer_version = older_version
        end
      end

      def check_semver_criteria(condition, message)
        if !condition
          Printer.fail(message)
          abort()
        end
      end

      def validate_changelog_contents(changelog_contents)
        version_header_regexes = [
          ## h2 using --- separator.  Example:
          #  1.0.0
          #  -----
          #  First release!
          '(^#{RELEASE_REGEX}).*\n----.*',

          # h1/h2 header retrieved from https://github.com/tech-angels/vandamme/#format and modified to skip headers with dots in the name
          '^#{0,3} ?([\w\d\.-]+\.[\d\.-]+[a-zA-Z0-9])(?: \W (\w+ \d{1,2}(?:st|nd|rd|th)?,\s\d{4}|\d{4}-\d{2}-\d{2}|\w+))?\n?[=-]*'
        ]

        changelog_hash = nil
        version_header_regexes.each do |version_header_regex|
          parser = Vandamme::Parser.new(changelog: changelog_contents, version_header_exp: version_header_regex, format: 'markdown')
          changelog_hash = parser.parse

          break if !changelog_hash.empty?
        end
        
        if changelog_hash.empty?
          Printer.fail("Unable to find any releases in the CHANGELOG.md.  Please check that the formatting is correct.")
          abort()
        end
        
        Printer.success("Found " + changelog_hash.count.to_s.bold + " release(s) in CHANGELOG.md.")

        validate_semver(changelog_hash)

        changelog_hash.each { |release, changelog| 
          validate_single_changelog_entry(changelog)
        }

        latest_release, latest_release_changelog = changelog_hash.first
        CurrentRelease.new(latest_release, latest_release_changelog)
      end

      def validate_single_changelog_entry(entry)
        previous_line_in_progress = nil

        lines = entry.chomp.split(/\r?\n/)
        lines.each{ |line|

          if starts_with_bullet? line
            if previous_line_in_progress
              fail_punctuation(previous_line_in_progress)
            elsif ends_with_punctuation? line
              # self-contained line is a-ok, and the usual use-case
              previous_line_in_progress = nil
            else
              # line starts with bullet, but did not end with punctuation
              previous_line_in_progress = line
            end
          elsif previous_line_in_progress
            # does not start with bullet, and is continuing from previous line
            if ends_with_punctuation? line
              # multi-line ending with punctuation is ok!
              previous_line_in_progress = nil
            else
              # middle of multi-line - neither starts with bullet, nor ends with punctuation.
              previous_line_in_progress = line
            end
          else
            # don't care about empty or code lines interspersed in a changelog entry
          end
        }

        # the last line may not be clean.  Handle it.
        if previous_line_in_progress
          fail_punctuation(previous_line_in_progress)

        end
      end

      def starts_with_bullet?(line)
        line.match /^\s*\*\s+.*$/
      end

      def ends_with_punctuation?(line)
        line.match /.*[\!,\?:\.]$/
      end

      def fail_punctuation(line)
        Printer.fail("'#{line}' is invalid.  Bulleted points should end in punctuation and no trailing line whitespace.")
        abort()
      end
    end
  end
end
