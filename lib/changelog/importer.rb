require_relative '../git_util'
require_relative '../command_processor'


module Releasinator
  module Changelog
    class Importer
      def initialize(releasinator_config)
        @releasinator_config = releasinator_config
      end

      def import(repo_url)
        # create tempfile 
        File.open('CHANGELOG.md.tmp', 'w') do |f|
          title_string = "#{@releasinator_config[:product_name]} release notes"
          f.puts title_string

          # print ====== with the length of the previous line for prettiness
          title_string.length.times { f.print "=" }
          f.puts

          # read releases
          github_repo = GitHubRepo.new(repo_url)

          begin
            github_releases = github_repo.client.releases "#{github_repo.org}/#{github_repo.repo}"
            github_releases.each do |github_release|
              puts github_release.inspect if @releasinator_config[:trace]
              f.puts
              f.puts github_release.name
              f.puts "-----"
              f.puts github_release.body
            end
          rescue => error
            f.puts "<could not read releases from github>"
            Printer.fail(error.inspect)
            abort()
          end
        end
      end
    end
  end
end
