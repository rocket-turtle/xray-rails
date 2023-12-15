module Xray
  # This is the main point of integration with Rails. This engine hooks into
  # Sprockets and monkey patches ActionView in order to augment the app's JS
  # and HTML templates with filepath information that can be used by xray.js
  # in the browser. It also hooks in a middleware responsible for injecting
  # xray.js and the xray bar into the app's response bodies.
  class Engine < ::Rails::Engine
    initializer "xray.initialize" do |app|
      app.middleware.use Xray::Middleware

      # Required by Rails 4.1
      app.config.assets.precompile += %w(xray.js xray.css)
    end

    config.after_initialize do |app|
      ensure_asset_pipeline_enabled! app

      # This event is called near the beginning of a request cycle. We use it to
      # collect information about the controller and action that is responding, for
      # display in the Xray bar.
      ActiveSupport::Notifications.subscribe('start_processing.action_controller') do |*args|
        event           = ActiveSupport::Notifications::Event.new(*args)
        controller_name = event.payload[:controller]
        action_name     = event.payload[:action]
        path            = ActiveSupport::Dependencies.search_for_file(controller_name.underscore)

        Xray.request_info.clear

        Xray.request_info[:controller] = {
          :path   => path,
          :name   => controller_name,
          :action => action_name
        }
      end

      # This event is called each time during the request cycle that
      # ActionView renders a template. The first time it's called will most
      # likely be the view the controller is rendering, which is what we're
      # interested in.
      ActiveSupport::Notifications.subscribe('render_template.action_view') do |*args|
        event  = ActiveSupport::Notifications::Event.new(*args)
        layout = event.payload[:layout]
        path   = event.payload[:identifier]

        # We are only interested in the first notification that has a layout.
        if layout
          Xray.request_info[:view] ||= {
            :path   => path,
            :layout => layout
          }
        end
      end
    end

    def ensure_asset_pipeline_enabled!(app)
      unless app.assets
        raise "xray-rails requires the Rails asset pipeline.
The asset pipeline is currently disabled in this application.
Either convert your application to use the asset pipeline, or remove xray-rails from your Gemfile."
      end
    end
  end
end
