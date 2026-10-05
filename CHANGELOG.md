# xray-rails Change Log

All notable changes to this project will be documented in this file.

xray-rails is in a pre-1.0 state. This means that its APIs and behavior are
subject to breaking changes without deprecation notices. Until 1.0, version
numbers will follow a [Semver][]-ish `0.y.z` format, where `y` is incremented
when new features or breaking changes are introduced, and `z` is incremented for
lesser changes or bug fixes.

## [Unreleased][]

* **Breaking:** Replace the `ActionView::Template#render` monkey patch with Rails' built-in
  `config.action_view.annotate_rendered_view_with_filenames`. Apps must enable that option in every
  environment where xray-rails is loaded; the engine raises at boot otherwise.
* **Breaking:** Remove `Xray.augment_template`, `Xray.next_id`, `Xray::Rendering`, and the
  `render partial: '...', locals: { xray: false }` opt-out. Disable Xray by not rendering the
  `xray_bar` partial instead.
* Parse Rails `BEGIN`/`END` filename comments in xray.js, matching nested ranges with a stack so
  partials inside partials resolve to the correct template.
* Drop the `ensure_asset_pipeline_enabled!` boot check. It read `app.assets`, which sprockets-rails
  only sets when `config.assets.compile` is true, so it raised on otherwise healthy configurations.
* Register `xray.js`/`xray.css` for precompilation only when the asset pipeline exposes a precompile
  list, so the engine no longer raises on Propshaft or on apps with no pipeline at all.
* Drive the browser specs with Cuprite instead of Selenium and Firefox, dropping the geckodriver
  dependency, and stop disabling the end-to-end specs under CI.
* **Breaking:** Require Rails 8.0. `activesupport` and `actionview` move from an unbounded `>= 7.2`
  to `~> 8.0`, and the suite now runs against 8.0 rather than 7.2, so support for 7.x is neither
  claimed nor tested any more.
* Stack overlay boxes by size instead of by position, so a nested template stays clickable when it
  shares a corner with the template that rendered it.
* Keep Rails' filename comments in the document instead of deleting them while scanning. Turbo caches
  its snapshot after the scan, so the stripped markup left the overlay permanently empty on every
  cache-restored page until a full reload; already-scanned comments are now tracked in a `WeakSet`.
* Reset the overlay on `turbo:render`. Turbo swaps `<body>`, so the boxes were gone while the state
  still claimed they were showing, and the next shortcut press hid an overlay nobody could see.
* Load `xray.css` with the CSP nonce and hide the bar with the `hidden` attribute instead of inline
  `style` attributes. Under a nonce-based `style-src` the stylesheet was refused and the inline styles
  were blocked, leaving an unstyled bar permanently on screen.
* Add fixture-driven specs that exercise xray.js against a static page, covering template parsing,
  nested ranges and overlay stacking without booting Rails.
* **Security:** Run the configured editor through an argv instead of a shell. `Xray.open_file` built
  a command string from the requested path and handed it to `Open3.capture3`, so a path containing
  shell metacharacters could append commands of its own.
* **Security:** Require a `POST` carrying an `X-Xray-Request` header on `/_xray/open` and
  `/_xray/config`. Both act on the developer's machine, and as plain `GET`s they could be triggered
  by any page visited while the development server was running.
* **Security:** Only answer `/_xray/open` and `/_xray/config` on `localhost`, `*.localhost`, IP
  addresses and the hosts listed in `config.hosts`. A DNS rebinding attack makes a page on the
  attacker's hostname same-origin with the app, so it could set the custom header, store any command
  as the editor and have it run; the host is read from `Host` rather than `X-Forwarded-Host`, which
  such a page may set itself. Apps relying on `config.hosts.clear` must now list their hostnames.
* **Security:** Expand the path `/_xray/open` receives to an absolute path and refuse it with a 404
  unless it names an existing file. The path is passed to the editor as an argument, where a value
  like `--flag` or vim's `+cmd` would have been read as an option.
* Report a failed open in the console instead of discarding the rejected promise, so a missing
  editor configuration is visible rather than silent.
* Report a misconfigured editor as a 500 rather than an unhandled exception, and refuse to persist an
  editor command that cannot be parsed. Exec'ing the editor directly surfaces a missing binary as
  `SystemCallError` and an unbalanced quote as `ArgumentError`, neither of which a shell used to raise.
* Stop hardcoding `$file` next to the `FILE_PLACEHOLDER` constant that defines it.
* Narrow the rescue around `.xrayconfig` parsing to `Errno::ENOENT` and `Psych::Exception`, and
  warn on a file Psych refuses to load rather than silently falling back to defaults. Accept a
  hand-written `editor:` key, and ignore an empty file or one holding no settings instead of crashing
  every `/_xray/open` with a `TypeError`.
* Find the controller file with `Object.const_source_location` instead of the private
  `ActiveSupport::Dependencies.search_for_file`, which only searched the app's autoload paths and left
  the controller button of engine and gem controllers without a path.
* Keep the request info in an `ActiveSupport::CurrentAttributes` class instead of `Thread.current`.
  It was only cleared when the next controller started, so a pooled thread rendering outside a
  controller showed the previous request's controller and view.
* Leave out the layout button when the layout does not resolve from the bar partial instead of
  raising `ActionView::MissingTemplate` and failing the whole page.

## [0.6.0][] (2026-04-21)

* Add full Turbo/Hotwire compatibility: re-scan templates after `turbo:render` and `turbo:frame-render`, and handle Turbo Stream DOM mutations via a debounced `MutationObserver`.
* Fix overlay stacking after Turbo Drive navigation — guard the IIFE with `window._xrayLoaded` so only the first page load initializes Xray.
* Add error boundary around template parsing: failures now surface as a `console.warn` instead of silently breaking the overlay.
* Remove hardcoded `/usr/local/bin/subl` editor fallback; raise a clear `RuntimeError` when no editor is configured via `$GEM_EDITOR`, `$VISUAL`, or `$EDITOR`.
* Refactor JS internals: drop the `Xray` namespace object in favour of module-level variables; remove `getOverlay`, `Xray.initialized`, and `findTemplatesInner`.

## [0.5.0][] (2026-04-09)

* Update Rails support/development matrix through Rails 7.2, including dummy app config/defaults updates for Rails 7.x conventions.
* Update runtime dependency minimums to `activesupport >= 7.2` and `actionview >= 7.2`.
* Update development dependencies: `rspec-rails` to 8.x, `sqlite3` to 2.x, and `selenium-webdriver` to 4.41.
* Remove `webdrivers` development dependency and rely on modern Selenium driver management.
* Update local Ruby target to 3.4.9 (`.ruby-version`) and declare `required_ruby_version >= 3.3`.
* Add request-level rendering patch coverage to verify `Xray::Rendering` is prepended in an app render path.

## [0.4.0][] (2026-04-09)

* Remove jQuery from the frontend and migrate `xray.js` to native DOM APIs, `fetch`, and ES6 class-based components (`Bar`, `Overlay`, `Settings`, `Specimen`).
* Remove legacy frontend sources and dependencies, including `app/assets/javascripts/xray.js.coffee` and remaining jQuery references.
* Simplify Xray runtime wiring by removing response-body injection from middleware; render `<%= render partial: "/xray_bar" %>` in layout to include Xray assets/UI.
* Improve request handling by centralizing Xray network calls and treating non-2xx HTTP responses as failures.
* Improve keyboard handling by switching from deprecated `keyCode` to `KeyboardEvent.key` and tightening shortcut/macOS detection logic.
* Refactor template marker parsing/scanning to pure DOM traversal and simplify related utility code paths.
* Remove Haml support in rendering/tests (including Haml dummy fixtures and related branches).
* Clean up development packaging/docs by removing CI-specific dependency gating and outdated README badge/dependency references.

## [0.3.2.3][] (2023-12-15)
* update ruby 3.3
* Fix ActiveRecord load order issues using ActiveSupport.on_load
* update ruby 3.2.3
* remove xray.js autoinsert. You need to add xray.js to your template.
* remove version check for Rails 5.2
* remove Rails <= 4.2
* remove the support for skim and hamlc

## [0.3.2.2][] (2023-12-15)
* remove JavaServer Pages (JSP) support
* update ruby 3.2
* drop support for Ruby 1.9 - remove xray/aliasing
* use rspec-rails 6.1
* add byebug
* use and test rails 6.1
* fix spec for macs
* Convert specs to RSpec 3.9.3 syntax with Transpec
* FIX ArgumentError: wrong number of arguments (given 4, expected 3)
* remove non working capybara-screenshot
* add .ruby-gemset .ruby-version

## [0.3.2.1][] (2022-07-29)
* Fix "undefined method safe_append=" on Ruby 3.0.0
* Automatically add a nonce to script tag (#100)
* In CI, we can't open the .html files saved by capybara-screenshot, so puts page.html instead so we can figure out why it failed
* Fix test failures on Rails < 6 due to sprockets >= 4
* Fix test error with Rails 6:
* Locked rspec-rails to 3.x in the .gemspec
* Load gems from Gemfile.local too, if present, so that developers can use some optional debugging tools like byebug and pry
* Add capybara-screenshot so we can check out the .html document when a test fails
* Add end-to-end test that actually tests in a real browser that pressing Ctrl+Shift+X makes the Xray UI appear
* Update script_matcher to allow for .source and .debug suffixes that sometimes get added by Sprockets 4 pipelines
* Add www.example.com to config.hosts
* Don't test so many old versions
* Test on Rails 6
* follow Apple spelling conventions (#114)
* Adapt to Sprockets 4 (#103)

## [0.3.2][] (2019-03-16)

* Gracefully handle nil templates
  [#96](https://github.com/brentd/xray-rails/pull/96)

## [0.3.1][] (2017-06-16)

* Include xray.js when using jQuery3
  [#84](https://github.com/brentd/xray-rails/pull/84)

## [0.3.0][] (2017-04-28)

* Remove `alias_method_chain` and make xray-rails compatible with Rails 5.1.

## [0.2.0][] (2016-09-23)

* Removed support for Backbone-rendered templates. This feature was particularly
  complex and prone to failure. It will more than likely return in some form in
  the future - for now, if your workflow depends on it, don't upgrade to 0.2.0.
* Removed the dependency on coffee-rails.
* Fixed deprecation warnings from Sprockets 4.

## [0.1.23][] (2016-09-23)

* Add a post-install message regarding future removal of Backbone support.

## [0.1.22][] (2016-09-08)

* If you have not explicitly set an editor, xray-rails now chooses a default
  editor by using the following environment variables: `GEM_EDITOR`, `VISUAL`,
  and `EDITOR`. To explicitly set the editor, use `~/.xrayconfig` as explained
  in the [configuration section](https://github.com/brentd/xray-rails#configuration)
  of the README.

## [0.1.21][] (2016-05-21)

* Fix a regression in 0.1.20 that broke Rails 3.2 apps
  [#72](https://github.com/brentd/xray-rails/pull/72)

## [0.1.20][] (2016-05-18)

* Added support for Rails 5.0.0.rc1.
  [#70](https://github.com/brentd/xray-rails/pull/70)

## [0.1.19][] (2016-05-06)

* Previous releases of xray-rails had a file permissions issue that caused a
  "can't load lib/xray/middleware" error on some systems. This should now be
  fixed. [#59](https://github.com/brentd/xray-rails/pull/59)
* The xray-rails JavaScript is now properly injected after `jquery2`. This means
  that projects using jQuery2 should now work with xray-rails out of the box.
  [#64](https://github.com/brentd/xray-rails/pull/64) @nextekcarl

## [0.1.18][] (2016-01-11)

* xray-rails is now compatible with sprockets-rails 3.0
  [#62](https://github.com/brentd/xray-rails/pull/62) @mattbrictson

## [0.1.17][] (2015-10-18)

* Will no longer attempt to augment mailer templates
* Added hamlc as a supported template (hopefully; needs testing)
* Made the middleware smarter about when to inject xray.js and the bar partial

## [0.1.16][] (2015-05-09)

* Add support for sprockets 3.0
  [#56](https://github.com/brentd/xray-rails/pull/56) @mattbrictson


[Semver]: http://semver.org
[Unreleased]: https://github.com/brentd/xray-rails/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/brentd/xray-rails/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/brentd/xray-rails/compare/v0.3.2.3...v0.4.0
[0.3.2.3]: https://github.com/brentd/xray-rails/compare/v0.3.2.2...v0.3.2.3
[0.3.2.2]: https://github.com/brentd/xray-rails/compare/v0.3.2.1...v0.3.2.2
[0.3.2.1]: https://github.com/brentd/xray-rails/compare/v0.3.2...v0.3.2.1
[0.3.2]: https://github.com/brentd/xray-rails/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/brentd/xray-rails/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/brentd/xray-rails/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/brentd/xray-rails/compare/v0.1.23...v0.2.0
[0.1.23]: https://github.com/brentd/xray-rails/compare/v0.1.22...v0.1.23
[0.1.22]: https://github.com/brentd/xray-rails/compare/v0.1.21...v0.1.22
[0.1.21]: https://github.com/brentd/xray-rails/compare/v0.1.20...v0.1.21
[0.1.20]: https://github.com/brentd/xray-rails/compare/v0.1.19...v0.1.20
[0.1.19]: https://github.com/brentd/xray-rails/compare/v0.1.18...v0.1.19
[0.1.18]: https://github.com/brentd/xray-rails/compare/v0.1.17...v0.1.18
[0.1.17]: https://github.com/brentd/xray-rails/compare/v0.1.16...v0.1.17
[0.1.16]: https://github.com/brentd/xray-rails/compare/v0.1.15...v0.1.16
