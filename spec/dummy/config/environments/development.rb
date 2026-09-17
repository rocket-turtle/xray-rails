Dummy::Application.configure do
  config.cache_classes = false

  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  config.action_mailer.raise_delivery_errors = false

  config.active_support.deprecation = :log
  config.action_view.annotate_rendered_view_with_filenames = true

  config.assets.compress = false
  config.assets.debug = true

  config.eager_load = false
end
