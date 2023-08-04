require File.expand_path("../dummy/config/environment", __FILE__)
require 'rspec/rails'
require 'capybara/rspec'

class String
  def unindent
    gsub(/^#{scan(/^\s*/).min_by{|l|l.length}}/, "").chomp!
  end
end

RSpec.configure do |config|
  config.include Capybara::DSL
  config.include Capybara::RSpecMatchers

  # rspec-rails 3 will no longer automatically infer an example group's spec type
  # from the file location. You can explicitly opt-in to the feature using this
  # config option.
  # To explicitly tag specs without using automatic inference, set the `:type`
  # metadata manually:
  #
  #     describe ThingsController, :type => :controller do
  #       # Equivalent to being in spec/controllers
  #     end
  config.infer_spec_type_from_file_location!
end
Dir[Pathname.new(__dir__).join('support/**/*.rb')].each {|f| require f}

Capybara.configure do |config|
  config.ignore_hidden_elements = false
  config.javascript_driver = :selenium_headless
end
