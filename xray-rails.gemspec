# -*- encoding: utf-8 -*-
require File.expand_path('../lib/xray/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "xray-rails"
  gem.authors       = ["Brent Dillingham"]
  gem.email         = ["brentdillingham@gmail.com"]
  gem.summary       = %q{Reveal the structure of your UI}
  gem.description   = %q{Provides a dev bar and an overlay in-browser to visualize your UI's rendered partials}
  gem.homepage      = "https://github.com/brentd/xray-rails"

  gem.files         = Dir['{app,lib}/**/*'] + ['LICENSE', 'README.md']
  gem.require_paths = ["lib"]
  gem.version       = Xray::VERSION
  gem.license       = 'MIT'

  gem.add_dependency 'rails', '>= 6.1'
  gem.add_development_dependency 'rails', '~> 6.1.0'

  gem.add_development_dependency 'rspec-rails', '~> 6.0'

  # Required for the dummy Rails app in spec/dummy
  gem.add_development_dependency 'sqlite3'
  gem.add_development_dependency 'jquery-rails'
  gem.add_development_dependency 'haml'
  gem.add_development_dependency 'capybara'
  gem.add_development_dependency 'byebug'

  unless ENV['CI'] == 'true'
    gem.add_development_dependency 'selenium-webdriver'
    gem.add_development_dependency 'puma'
    gem.add_development_dependency 'webdrivers'
  end
end
