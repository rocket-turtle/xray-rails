require 'spec_helper'

describe "Xray Bar" do
  before { visit '/' }

  it "includes the controller and action" do
    expect(find('#xray-bar')).to have_text('ApplicationController#root')
  end

  it "includes the layout used" do
    expect(find('#xray-bar')).to have_text('application.html.erb')
  end

  it "includes the view rendered" do
    expect(find('#xray-bar')).to have_text('root.html.erb')
  end

  it "points each button at the file it names" do
    expect(find('.xray-bar-controller')['data-path']).to eq(Rails.root.join('app/controllers/application_controller.rb').to_s)
    expect(find('.xray-bar-layout')['data-path']).to eq(Rails.root.join('app/views/layouts/application.html.erb').to_s)
    expect(find('.xray-bar-view')['data-path']).to eq(Rails.root.join('app/views/application/root.html.erb').to_s)
  end
end

describe "Xray Bar with a layout that does not resolve" do
  around { |example| Rails.application.executor.wrap { example.run } }

  it "leaves out the layout button rather than failing the page" do
    Xray.request_info[:view] = { path: '/app/views/root.html.erb', layout: 'layouts/missing' }

    html = ApplicationController.render(partial: '/xray_bar')

    expect(html).to include('xray-bar-view')
    expect(html).not_to include('xray-bar-layout')
  end
end
