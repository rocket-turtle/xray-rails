require "spec_helper"

RSpec.describe "Rails rendering annotations", type: :request do
  it "renders filename annotations for templates used by xray.js" do
    get "/"
    expect(response).to have_http_status(:ok)

    expect(response.body).to include("BEGIN app/views/application/root.html.erb")
    expect(response.body).to include("END app/views/application/root.html.erb")
  end
end
