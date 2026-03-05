Xray-rails
==========

### Reveal your UI's bones

The dev tools available to web developers in modern browsers are great. Many of us can't remember what life was like before "Inspect Element". But what we see in the compiled output sent to our browser is often the wrong level of detail - what about visualizing the higher level components of your UI? Controllers, view templates, partials, JS templates, etc.

Xray is the missing link between the browser and your app code. Press **command+shift+x** (Mac) or **ctrl+shift+x** to reveal an overlay of the files that rendered your UI, and click anything to open the file in your editor.

![Screenshot](example/screenshot.png)

## Current Support

Xray is intended for Rails 6.1+, Ruby 3.1+ and Sprockets 4.

It can reveal Rails views and partials

## Installation

This gem should only be present during development. Add it to your Gemfile:

```ruby
group :development do
  gem 'xray-rails'
end
```

Then bundle and delete your cached assets:

```
$ bundle && rm -rf tmp/cache/assets
```

Insert Xray's script in your template as its own script tag.

```
= javascript_include_tag 'xray', nonce: true if Rails.env.development?
```

Restart your app, visit it in your browser, and press **command+shift+x** (Mac) or **ctrl+shift+x** to reveal the overlay.

## Configuration

By default, Xray will check a few environment variables to determine
which editor to open files in: `$GEM_EDITOR`, `$VISUAL`, then
`$EDITOR` before falling back to `/usr/local/bin/subl`.

You can configure your editor of choice either by setting one of these
variables, or in Xray's UI, or in an `~/.xrayconfig` YAML file:

```yaml
:editor: '/usr/local/bin/mate'
```

For something more complex, use the `$file` placeholder.

```yaml
:editor: "/usr/local/bin/tmux new-window 'vim $file'"
```

## How this works

* At run time, HTML responses from Rails are wrapped with HTML comments containing filepath info.
* A middleware inserts `xray.css` and the Xray bar into all successful HTML response bodies.
* When the overlay is shown, `xray.js` examines the inserted filepath info to build the overlay.

## Disabling Xray

Xray augments HTML templates by wrapping their contents with HTML comments. For some environments such as [Angular.js](http://angularjs.org/), this can cause Angular templates to stop working because Angular expects only one root node in the template HTML. You can pass in the option `xray: false` to any partial render statements to ensure Xray does not augment that partial. Example:

```ruby
render partial: 'my_partial', locals: { xray: false }
```

Note that this disables Xray's HTML comment wrappers for `my_partial`, but not any sub-partials rendered within that template, if any. You must pass `xray: false` to each `render` call where you want Xray disabled.

Currently there is no way to disable Xray entirely for a given request. If this feature is important to you, please leave a comment on [issue #75](https://github.com/brentd/xray-rails/issues/75). PRs are appreciated!

## Contributing

If you have an idea, open an issue and let's talk about it, or fork away and send a pull request.

A laundry list of things to take on:

  * Reveal views from Ember, Knockout, Angular, etc.
  * Overlapping boxes are a problem - parent views in real applications will often be obscured by their children.
  * The current scheme for associating a JS constructor with a filepath is messy and can make stack traces ugly.

Worth noting is that I have plans to solidify xray.js into an API and specification that could be used to aid development in any framework - not just Rails and the asset pipeline.
