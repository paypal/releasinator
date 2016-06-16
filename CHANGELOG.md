Releasinator release notes
==========================

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
