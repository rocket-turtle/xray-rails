require 'spec_helper'

describe Xray, "in a Rails app (end-to-end)", :js do
  it "works" do
    visit '/'
    expect_to_work
  end

  it "works when using a strict CSP" do
    visit '/strict_csp'
    expect_to_work
  end

  def expect_to_work
    expect(page).to have_selector('script[src^="/assets/xray"][nonce]')
    expect(page.find('script[src^="/assets/xray"]')[:nonce]).to eq page.find('meta[name="csp-nonce"]')[:content]
    expect(page).to have_selector('#xray-bar')

    expect(page).to have_no_selector('.xray-specimen-handle', text: 'root.html.erb')

    if RUBY_PLATFORM.include?('darwin')
      find('body').send_keys [:command, :shift, 'x']
    else
      find('body').send_keys [:control, :shift, 'x']
    end

    expect(page).to have_selector('.xray-specimen-handle', text: 'root.html.erb')
  end
end unless ENV['CI'] == 'true'
