require "spec_helper"
require "xray/engine"

RSpec.describe Xray::Engine do
  let(:engine) { described_class.instance }

  describe "asset registration" do
    it "registers xray assets for precompilation under Sprockets" do
      expect(Rails.application.config.assets.precompile).to include("xray.js", "xray.css")
    end
  end

  describe "request info" do
    around { |example| Rails.application.executor.wrap { example.run } }

    def start_processing(controller)
      ActiveSupport::Notifications.instrument('start_processing.action_controller', controller: controller, action: 'index')
    end

    it "records where the controller is defined" do
      start_processing('ApplicationController')

      expect(Xray.request_info[:controller]).to eq(
        path: Rails.root.join('app/controllers/application_controller.rb').to_s,
        name: 'ApplicationController',
        action: 'index'
      )
    end

    it "finds controllers outside the app's autoload paths" do
      require 'rails/info_controller'
      start_processing('Rails::InfoController')

      expect(Xray.request_info[:controller][:path]).to end_with('rails/info_controller.rb')
    end

    it "records the first view rendered with a layout" do
      ActiveSupport::Notifications.instrument('render_template.action_view', identifier: '/app/views/partial.html.erb')
      ActiveSupport::Notifications.instrument('render_template.action_view', identifier: '/app/views/root.html.erb', layout: 'layouts/application')
      ActiveSupport::Notifications.instrument('render_template.action_view', identifier: '/app/views/other.html.erb', layout: 'layouts/other')

      expect(Xray.request_info[:view]).to eq(path: '/app/views/root.html.erb', layout: 'layouts/application')
    end
  end

  describe "request info between requests" do
    it "does not carry over into the next request" do
      Rails.application.executor.wrap do
        ActiveSupport::Notifications.instrument('start_processing.action_controller', controller: 'ApplicationController', action: 'index')
        expect(Xray.request_info).to include(:controller)
      end

      Rails.application.executor.wrap do
        expect(Xray.request_info).to eq({})
      end
    end
  end

  describe "#ensure_action_view_annotations_enabled!" do
    it "does not raise when annotate_rendered_view_with_filenames is enabled" do
      action_view_config = double("action_view_config", annotate_rendered_view_with_filenames: true)
      config = double("config", action_view: action_view_config)
      app = double("app", config: config)

      expect { engine.send(:ensure_action_view_annotations_enabled!, app) }.not_to raise_error
    end

    it "raises when annotate_rendered_view_with_filenames is disabled" do
      action_view_config = double("action_view_config", annotate_rendered_view_with_filenames: false)
      config = double("config", action_view: action_view_config)
      app = double("app", config: config)

      expect { engine.send(:ensure_action_view_annotations_enabled!, app) }
        .to raise_error(RuntimeError, /requires ActionView filename annotations/)
    end
  end
end
