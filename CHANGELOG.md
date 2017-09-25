Releasinator release notes
==========================

0.7.4
-----
* Fix tagged version parsing to support getting the raw tag value.

0.7.3
-----
* Fix changelog parsing regex to support "vX.Y.Z" version names.

0.7.2
-----
* Fix changelog parsing regex to support beta/prerelease tags.

0.7.1
-----
* Prompt user on first release.

0.7.0
-----
* Optionally update version and CHANGELOG.md inline.

0.6.4
-----
* Remove unused 'fileutils' dependency.
* Allow LICENSE links in README.md to be relative.

0.6.3
-----
* When using git flow, validate the release branch is an ancestor of the develop branch.  User must confirm a warning if is not.
* Update some error messages.

0.6.2
-----
* Re-enable bullet punctuation detection, now handling multi-line comments correctly!
* Add new utility task, `import:changelog` for creating a changelog from a GitHub repo using the contents of existing GitHub releases.

0.6.1
-----
* Improve some error messages.
* Add more filetypes to `validate:eof_newlines`.
* Disable bullet punctuation detection until multi-line comments can be addressed.

0.6.0
-----
* Validate all bulleted items in `CHANGELOG.md` end in punctuation.
* Add new task, `validate:eof_newlines` which validates text files matching a few known extensions end in a newline character.  The validation adds the newline character if not present.
* Validate files are in git with the proper name, case sensitive.  Previously, the releasinator would allow files detected by the filesystem.  Since Macs are case in-sensitive, incorrect cases for expected filenames were allowed.

0.5.0
-----
* The releasinator is now Open Source!
* Validate `.gitignore` includes `.DS_Store`.

0.4.1
-----
* `release_to_github` will now create a new release (instead of a draft).
* Freeze some options after loading to avoid accidental overwrite.

0.4.0
-----
* Add new `configatron.post_push_methods` param.

0.3.4
-----
* Validate paths in separate `validate:paths` task.
* Add a missing task description.

0.3.3
-----
* Add a git cleanliness check.
* Change default config to abort until filled in.
* Reorder validations so that git/branch checks are last.  This was done to give the developer opportunity to fix other validations without having to push a bunch of times.

0.3.2
-----
* Fix issue where dot in changelog header turns a title into a release.

0.3.1
-----
* Fix regressed submodule origin/master validation to work properly with detached branches.

0.3.0
-----
* Add new `validate:releasinator_version` task.
* Add new `@validator.validate_in_path(executable)` function for use by any config.
* Fix version validation to be more permissive when a suffix is provided.
* Add missing dependencies on `validate:changelog`.
* Remove default rake task, so that releasing is explicit with the `release` task.
* Clean up and correct some file validations.
* Fix some bugs.

0.2.1
-----
* Fix current_release renaming bug.

0.2.0
-----
* Rename some fields.

0.1.1
-----
* Fix `validate:gitignore` to print more and dirty git.

0.1.0
-----
* First release as a gemfile!
