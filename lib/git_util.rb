require_relative 'command_processor'

module Releasinator
  class GitUtil
    def self.reset_repo(branch_name)
      # resets the repo to a clean state
      checkout(branch_name)
      fetch()
      CommandProcessor.command("git reset --hard origin/#{branch_name}")
      CommandProcessor.command("git clean -x -d -f")
    end

    def self.fetch()
      CommandProcessor.command("git fetch origin --prune --recurse-submodules -j9")
    end

    def self.exist?(path)
      current_branch = get_current_branch()
      # grep is case sensitive, which is what we want.  Piped to cat so the grep error code is ignored.
      "" != CommandProcessor.command("git ls-tree --name-only -r #{current_branch} | grep ^#{path}$ | cat")
    end

    def self.all_files()
      current_branch = get_current_branch()
      CommandProcessor.command("git ls-tree --name-only -r #{current_branch}")
    end

    def self.move(old_path, new_path)
      puts "Renaming #{old_path} to #{new_path}".yellow
      CommandProcessor.command("git mv -f #{old_path} #{new_path}")
    end

    def self.push_branch(branch_name)
      checkout(branch_name)
      fetch()
      # always merge to include any extra commits added during release process
      CommandProcessor.command("git merge origin/#{branch_name} --no-edit")
      CommandProcessor.command("git push origin #{branch_name}")
    end

    def self.push_tag(tag_name)
      CommandProcessor.command("git push origin #{tag_name}")
    end

    def self.is_clean_git?
      any_changes = CommandProcessor.command("git status --porcelain")
      '' == any_changes
    end

    def self.get_current_branch
      CommandProcessor.command("git symbolic-ref --short HEAD").strip
    end

    def self.detached?
      "" == CommandProcessor.command("git symbolic-ref --short -q HEAD | cat").strip
    end

    def self.untracked_files
      CommandProcessor.command("git ls-files --others --exclude-standard")
    end

    def self.diff
      CommandProcessor.command("git diff")
    end

    def self.cached
      CommandProcessor.command("git diff --cached")
    end

    def self.repo_url
      CommandProcessor.command("git config --get remote.origin.url").strip
    end

    def self.delete_branch(branch_name)
      if has_branch? branch_name
        CommandProcessor.command("git branch -D #{branch_name}")
      end
    end

    def self.has_branch?(branch_name)
      "" != CommandProcessor.command("git branch --list #{branch_name}").strip
    end

    def self.has_remote_branch?(branch_name)
      "" != CommandProcessor.command("git branch --list -r #{branch_name}").strip
    end

    def self.checkout(branch_name)
      if get_current_branch != branch_name
        CommandProcessor.command("git checkout #{branch_name}")
      end
    end

    def self.confirm_tag_overwrite(new_tag)
      tag_results = CommandProcessor.command('git tag -l')
      tag_results.split.each do |existing_tag|
        if existing_tag == new_tag
          Printer.check_proceed("Tag #{existing_tag} already present. Overwrite tag #{existing_tag}?", "Tag #{existing_tag} not overwritten.")
        end
      end
    end

    def self.get_local_head_sha1
      rev_parse("head")
    end

    def self.get_local_branch_sha1(branch_name)
      rev_parse(branch_name)
    end

    def self.get_remote_branch_sha1(branch_name)
      rev_parse("origin/#{branch_name}")
    end

    def self.rev_parse(branch_name)
      output = CommandProcessor.command("git rev-parse --verify #{branch_name} 2>&1 | cat").strip
      if output.include? 'fatal: Needed a single revision'
        puts "error: branch or commit '#{branch_name}' does not exist. You may need to checkout this branch.".red
        abort()
      end
      output
    end

    def self.tag(new_tag, changelog)
      confirm_tag_overwrite(new_tag)
      puts "tagging with changelog: \n\n#{changelog}\n".yellow
      changelog_tempfile = Tempfile.new("#{new_tag}.changelog")
      changelog_tempfile.write(changelog)
      changelog_tempfile.close
      # include changelog in annotated tag
      CommandProcessor.command("git tag -a -f #{new_tag} -F #{changelog_tempfile.path}")
      changelog_tempfile.unlink
    end

    def self.init_gh_pages
      if !has_branch? "gh-pages"
        if has_remote_branch? "origin/gh-pages"
          checkout("gh-pages")
        else
          CommandProcessor.command("git checkout --orphan gh-pages")
          CommandProcessor.command("GLOBIGNORE='.git' git rm -rf *")
          #http://stackoverflow.com/questions/19363795/git-rm-doesnt-remove-all-files-in-one-go
          CommandProcessor.command("GLOBIGNORE='.git' git rm -rf *")
          CommandProcessor.command("touch README.md")
          CommandProcessor.command("git add .")
          CommandProcessor.command("git commit -am \"Initial gh-pages commit\"")
          CommandProcessor.command("git push -u origin gh-pages")
        end
      end
    end
  end
end
