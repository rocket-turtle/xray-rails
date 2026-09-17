Dummy::Application.configure do
  config.cache_classes = true

  config.public_file_server.enabled = true
  config.public_file_server.headers = { "Cache-Control" => "public, max-age=3600" }

  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  config.action_dispatch.show_exceptions = false

  config.action_controller.allow_forgery_protection = false
  config.action_mailer.delivery_method = :test
  config.action_view.annotate_rendered_view_with_filenames = true

  config.active_support.deprecation = :stderr
end
