# Releasing

xray-rails is pre-1.0. Version numbers follow a [Semver][]-ish `0.y.z` format:

* **`y`** — breaking changes or new features
* **`z`** — bug fixes and other lesser changes

## Steps

1. Make sure the suite is green:

   ```bash
   bundle exec rspec
   ```

   `spec/xray/e2e_spec.rb` drives a real browser through Capybara and Selenium, so a
   working Firefox and geckodriver are needed. If the browser cannot start, rerun
   those examples on a machine where it can rather than releasing untested.

2. Bump `VERSION` in `lib/xray/version.rb`.

3. Roll up `CHANGELOG.md`: move the bullets under `## [Unreleased][]` into a new
   `## [x.y.z][] (YYYY-MM-DD)` heading, and leave `Unreleased` empty for the next
   cycle.

4. Commit both files together:

   ```bash
   git commit -m "release x.y.z" lib/xray/version.rb CHANGELOG.md
   ```

5. Tag the release and push:

   ```bash
   git tag vx.y.z
   git push && git push --tags
   ```

6. Build the gem:

   ```bash
   gem build xray-rails.gemspec
   ```

   This writes `xray-rails-x.y.z.gem` into the repository root. Built gems are
   gitignored (`*.gem`), so the file is not meant to be committed.

7. Publish that `.gem` to the gem host the consuming applications pull from, then
   raise the version constraint in those applications.

## A note on `rake release`

The Rakefile loads `bundler/gem_tasks`, which defines `rake build`, `rake install`
and `rake release`. `rake release` builds the gem, creates a git tag, and pushes the
gem to **rubygems.org**. Use it only if that is genuinely where this gem should go;
otherwise follow the steps above, which leave publishing as a deliberate step.

[Semver]: http://semver.org
