# Releasinator

[![Gem Version](https://badge.fury.io/rb/releasinator.svg)](https://badge.fury.io/rb/releasinator)

## Problem

When automating a release process for libraries, SDKs, apps, or other open source projects, many teams have different ideas.  This is on top of the fact that each language has its own conventions and repositories for distributing packages.  The release process is a hurdle that makes it hard for new project members to ramp up.  One should not have to read a `release_process.md` to release an open source project.

## Solution

The releasinator corrects this by enforcing standard must-have release files, being configurable where necessary, and reducing the ramp-up hurdle.

## Getting started

### Usage

1. Install ruby & rubygems.
1. Add releasinator dependency to `Gemfile` or `.gemspec`.
2. Add or append a `Rakefile` with the following contents:

    ```ruby
    spec = Gem::Specification.find_by_name 'releasinator'
    load "#{spec.gem_dir}/lib/tasks/releasinator.rake"
    ```

3. Run `rake <command>` to use the newly added rake tasks

### Tasks

```
release

--> config

--> validate:all
    --> validate:paths
    --> validate:eof_newlines
    --> validate:git_version
    --> validate:gitignore
    --> validate:submodules
    --> validate:readme
    --> validate:changelog
    --> validate:license
    --> validate:contributing
    --> validate:issue_template
    --> validate:github_permissions_local
    --> validate:github_permissions_downstream[downstream_repo_index]
    --> validate:releasinator_version
    --> validate:custom
    --> validate:git
    --> validate:branch

--> local:build
    --> local:checklist
    --> local:confirm
    --> local:prepare
    --> local:tag

--> pm:all
    --> pm:publish
    --> pm:wait

--> downstream:all
    --> downstream:reset[downstream_repo_index]
    --> downstream:prepare[downstream_repo_index]
    --> downstream:build[downstream_repo_index]
    --> downstream:package[downstream_repo_index]
    --> downstream:push[downstream_repo_index]

--> local:push

--> docs:all
    --> docs:build
    --> docs:package
    --> docs:push

import:changelog (utility that creates a CHANGELOG.md.tmp from existing GitHub releases)

```

### Config

A [default config file](lib/default_config.rb) is created when running any releasinator rake task for the first time.  This file includes placeholders for all the mandatory config items.  Below is the full list of config options.

#### Required `.releasinator.rb` config options:

1. `configatron.product_name`: The name of the project for usage in various commit statements.
2. `configatron.prerelease_checklist_items`: List of items to confirm from the person releasing.
3. `configatron.build_method`: The command that builds the project.
4. `configatron.publish_to_package_manager_method`: The method that publishes the project to the package manager.
5. `configatron.wait_for_package_manager_method`: The method that waits for the package manager to be done.
6. `configatron.release_to_github`: True if publishing the root repo to GitHub.

#### Optional `.releasinator.rb` config options:

1. `configatron.use_git_flow`: True if the root repo's git branching strategy follows git flow (develop/release/master).
2. `configatron.base_docs_dir`: The directory where all distributed docs are found.  If not specified, the default is `.`.
3. `configatron.custom_validation_methods`: List of methods that are run as a step within `validate:all`.
4. `configatron.downstream_repos`: List of downstream repos to push updates to.  Please see documentation on the `DownstreamRepo` class.
5. `configatron.doc_build_method`: The method that builds the docs.
6. `configatron.doc_target_dir`: The directory where to run all git commands when publishing the docs.  If not specified, the default is `.`.  Generally useful if the docs are only applicable on a downstream release, rather than on the source itself.
7. `configatron.doc_files_to_copy`: List of CopyFile objects for copying built docs into a targeted location.  Please see documentation on the `CopyFile` class.

#### Appending existing tasks in the releasinator lifecycle:

In some cases, releasing a project may require a deviation from the task lifecycle. To deal with this without requiring an update to the releasinator, you may just append an existing task in your project's config file.  For example:

```
task :"validate:changelog" do
  puts "validating changelog complete, let's dance!".red
end
```
This will append the task `validate:changelog`, running the code block after the official releasinator task contents have run.  See [this blog post](http://www.dan-manges.com/blog/modifying-rake-tasks) for a detailed description of how this mechanism works.  You may append a task more than once.

## Conventions

The releasinator enforces certain conventions.  If a filename closely matches the convention, it is renamed and automatically committed.  The conventions are documented below:

1. `README.md`
2. `LICENSE`: See [here](http://stackoverflow.com/questions/5678462/should-i-provide-a-license-txt-or-copying-txt-file-in-my-project) for a relevant StackOverflow post on this discussion.  The authors of this project have chosen to exclude the `.txt` extension to match other popular projects, and GitHub defaults.
3. `CONTRIBUTING.md`: See [a relevant GitHub blog post](https://github.com/blog/1184-contributing-guidelines) for relevant information.  The authors of this project have have chosen to include the `.md` extension, as these files can get a bit unwieldy without formatting.
4. `CHANGELOG.md` - This file is the source of truth for the releasinator.  The file should be organized with the most recent release on top, and formatted correctly.  The latest release is the one used when the releasinator executes, so it is a precondition that the `CHANGELOG.md` has been edited and committed **prior to releasing**.
  1. Releases either are contained within an Alt-H2 (`------`) or `##H2` format.  Any other format will be rejected.
  2. Each release MUST start with the release version, and may contain any following text, such as the date, and/or any release summary.
5. `.gitignore` and `.DS_store`: While this file is Mac-specific, many repos contain this entry in their `.gitignore` files because it is quite common for developers to have their global `.gitignore` configured incorrectly. Therefore, the authors of this project have made the decision to force this entry in all `.gitignore` files as a gesture of goodwill to all these new git users.

## Behind the Scenes

#### Validations (in no particular order)

1. ✓ Validate releasinator version.
1. ✓ Validate git version.
1. ✓ Validate text files end in newline characters.
1. ✓ Validate git's cleanliness (no untracked, unstaged, or uncommitted files).
1. ✓ Validate current git branch is up to date with the latest version on server.
1. ✓ Validate current git branch is `master` (if no git flow), or `develop` or `release/<Release number>` if using git flow.
1. ✓ Validate the presence of`.gitignore`, adding it if needed, and adding any needed lines.
1. ✓ Validate the presence of the `README.md` file.
1. ✓ Validate the presence of the `CHANGELOG.md` file.
1. ✓ Validate the `CHANGELOG.md` file is properly formatted.
1. ✓ Validate semver release number sequence in `CHANGELOG.md`.  (Note: cannot detect duplicate versions, due to the underlying Hash implementation of the parsing library.)
1. ✓ Validate the presence of `LICENSE`.
1. ✓ Validate the presence of `CONTRIBUTING.md`.
1. ✓ Validate the presence of `.github/ISSUE_TEMPLATE.md`.
1. ✓ Validate `LICENSE` and `CONTRIBUTING.md` are referenced in `README.md`.
1. ✓ Validate all submodules are up to date with the latest master version.
1. ✓ Validate all files are committed to git (`git ls-files --others --exclude-standard`).
1. ✓ Validate user has valid access_tokens as environment variables for all repos (public & enterprise).  Public github requires `GITHUB_TOKEN`, while enterprise tokens add a modified version of their domain as a prefix.  For example, github.example.com requires `GITHUB_EXAMPLE_COM_GITHUB_TOKEN`.
1. ✓ Validate user has permissions to push to repo, and downstream repos. 
1. ✓ Validate anything as defined by the config.  Examples:
    * Compiling with the right version of the platform.
    * Upstream library dependencies are the latest available.

#### Performs internal-only tasks:

1. ✓ Confirm user has completed all manual tasks (aka pre-release checklist).
1. ✓ Confirm overwrite of local tags already matching version.
1. ✓ Create local tag.
1. ✓ Run build command, as specified in the config file.

#### Performs external-facing tasks:

1. ✓ Clone/reset any downstream external distribution repos.
2. ✓ Copy to destination repo:

    * `README.md`
    * `CHANGELOG.md`
    * `LICENSE`
    * `CONTRIBUTING.md`
    * `.github/ISSUE_TEMPLATE.md`
    * Any other distribution files.  This will be configured.

3. ✓ Modify any dependency/versions in `README.md`, source, or sample apps to the latest version.  The location and regex of these will be configured.
4. ✓ Build code and/or Sample apps.
    * TODO If build fails, pause build and give developer a chance to fix the downstream build and retry without completely starting over.

5. ✓ Push to appropriate package manager (nexus/cocoapods/composer/npm/nuget/rubygem/pypi).
6. ✓ Confirm overwrite of remote tags already matching version.
7. ✓ Create root and downstream repo tag and GitHub release.  The name of the release is the tag, and the annotated description and GitHub release is the relevant section of the `CHANGELOG.md`.
8. ✓ Create downstream GitHub branch.
9. ✓ Correctly handle git flow branches and merging.
9. ✓ Push to external repo (once live in external package manager).
10. ✓ Create PRs into any downstream dependencies, including the release notes in the PR.  Examples:
    
    * Create a PR into Cordova when there is an Android or iOS release.
    * Create a PR into any other framework that has a direct dependency on this repo.

11. Using the downstream methods, one can add those same release notes within the release notes of the downstream repo.
12. TODO Assemble a draft of news, and publish (where possible, i.e. send email, tweet, whatever).

#### Package manager credential management (TODO)
1. Validate permissions to publish to package manager
2. If permissions are needed, retrieve them from the secret credential repo, and run any subsequent repo steps.

## Contributing

Please read our [contributing guidelines](CONTRIBUTING.md) prior to submitting a Pull Request.

## License

Please refer to this repo's [license file](LICENSE).
