require "spec_helper"
require "xray/engine"

RSpec.describe Xray::Engine do
  let(:engine) { described_class.instance }

  describe "asset registration" do
    it "registers xray assets for precompilation under Sprockets" do
      expect(Rails.application.config.assets.precompile).to include("xray.js", "xray.css")
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
