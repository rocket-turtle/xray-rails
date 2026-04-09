require_relative 'boot'

require 'logger'

# Pick the frameworks you want:
# require "active_record/railtie"
require "action_view/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "active_resource/railtie"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

Bundler.require(:default, Rails.env)
require 'xray-rails'

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.1
    config.filter_parameters += [:password]

    if config.respond_to?(:hosts)
      config.hosts << "www.example.com"
    end
  end
end
