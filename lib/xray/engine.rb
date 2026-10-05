module Xray
  # This is the main point of integration with Rails. This engine relies on
  # ActionView template annotations to surface filepath information that
  # xray.js can use in the browser. It also hooks in middleware for the
  # /_xray/open and /_xray/config endpoints.
  class Engine < ::Rails::Engine
    initializer "xray.initialize" do |app|
      app.middleware.use Xray::Middleware, hosts: app.config.hosts, root: app.root.to_s

      # Sprockets refuses to serve an engine asset that is absent from the
      # precompile list, even in development. Pipelines that resolve xray.js and
      # xray.css from the engine's asset paths expose no precompile list, and an
      # app without any pipeline does not respond to `assets` at all.
      if app.config.respond_to?(:assets) && app.config.assets.precompile
        app.config.assets.precompile += %w(xray.js xray.css)
      end
    end

    config.after_initialize do |app|
      ensure_action_view_annotations_enabled! app

      # This event is called near the beginning of a request cycle. We use it to
      # collect information about the controller and action that is responding, for
      # display in the Xray bar.
      ActiveSupport::Notifications.subscribe('start_processing.action_controller') do |event|
        controller_name = event.payload[:controller]
        action_name     = event.payload[:action]
        # Ruby knows where every loaded constant was defined, which also finds
        # controllers from engines and gems outside the app's autoload paths.
        # A constant still waiting on its autoload reports where the autoload
        # was set up instead, so it is loaded first.
        path            = controller_name.safe_constantize && Object.const_source_location(controller_name)&.first

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
      ActiveSupport::Notifications.subscribe('render_template.action_view') do |event|
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

    def ensure_action_view_annotations_enabled!(app)
      return if app.config.action_view.annotate_rendered_view_with_filenames

      raise "xray-rails requires ActionView filename annotations.
Set `config.action_view.annotate_rendered_view_with_filenames = true`
in your environment config."
    end
  end
end
