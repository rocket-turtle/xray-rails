require "spec_helper"

RSpec.describe "ActionView template annotations", type: :request do
  it "includes BEGIN/END filename comments in rendered html" do
    get "/"
    expect(response).to have_http_status(:ok)
    expect(response.body).to match(/<!-- BEGIN .*root\.html\.erb -->/)
    expect(response.body).to match(/<!-- END .*root\.html\.erb -->/)
  end

  it "does not include legacy XRAY START/END markers" do
    get "/"
    expect(response.body).not_to include("XRAY START")
    expect(response.body).not_to include("XRAY END")
  end
end
