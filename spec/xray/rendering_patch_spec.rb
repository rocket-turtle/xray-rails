require "spec_helper"

RSpec.describe "Xray rendering patch", type: :request do
  it "prepends Xray::Rendering to ActionView::Template" do
    get "/"
    expect(response).to have_http_status(:ok)

    expect(ActionView::Template.ancestors.first).to be(Xray::Rendering)
  end
end
