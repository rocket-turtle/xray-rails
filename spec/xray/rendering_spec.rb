require "spec_helper"

RSpec.describe "ActionView annotation config" do
  it "enables annotate_rendered_view_with_filenames in test" do
    expect(Rails.application.config.action_view.annotate_rendered_view_with_filenames).to be(true)
  end
end
