Xray-rails
==========

### Reveal your UI's bones

The dev tools available to web developers in modern browsers are great. Many of us can't remember what life was like before "Inspect Element". But what we see in the compiled output sent to our browser is often the wrong level of detail - what about visualizing the higher level components of your UI? Controllers, view templates, partials, JS templates, etc.

Xray is the missing link between the browser and your app code. Press **command+shift+x** (Mac) or **ctrl+shift+x** to reveal an overlay of the files that rendered your UI, and click anything to open the file in your editor.

![Screenshot](example/screenshot.png)

## Current Support

Xray is intended for Rails 7.2+ and Ruby 3.3+. Any asset pipeline works; on Sprockets 4 the engine registers its own assets for you.

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

Render Xray's bar partial in your layout (for example right after `<body>`):

```erb
<%= render partial: "/xray_bar" if Rails.env.development? %>
```

Enable Rails filename annotations so Xray can map DOM regions to view files:

```ruby
# config/environments/development.rb
config.action_view.annotate_rendered_view_with_filenames = true
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

* Rails emits HTML comments with template filepaths when `annotate_rendered_view_with_filenames` is enabled.
* Rendering the `xray_bar` partial adds `xray.js`, `xray.css`, and the Xray UI bar.
* When the overlay is shown, `xray.js` examines those filename annotations to build the overlay.

## Disabling Xray

To disable the overlay UI, stop rendering the `xray_bar` partial in your layout.

If you keep xray-rails enabled, filename annotations must stay enabled:

```ruby
config.action_view.annotate_rendered_view_with_filenames = true
```

If you want annotations off, remove xray-rails from the environment where you disable them.

## Contributing

If you have an idea, open an issue and let's talk about it, or fork away and send a pull request.

A laundry list of things to take on:

  * Reveal views from Ember, Knockout, Angular, etc.
  * Overlapping boxes are a problem - parent views in real applications will often be obscured by their children.
  * The current scheme for associating a JS constructor with a filepath is messy and can make stack traces ugly.

Worth noting is that I have plans to solidify xray.js into an API and specification that could be used to aid development in any framework - not just Rails and the asset pipeline.
