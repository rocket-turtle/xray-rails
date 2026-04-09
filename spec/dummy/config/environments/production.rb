Dummy::Application.configure do
  config.cache_classes = true

  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  config.assets.compress = true
  config.assets.compile = false
  config.i18n.fallbacks = true

  config.active_support.deprecation = :notify
end
