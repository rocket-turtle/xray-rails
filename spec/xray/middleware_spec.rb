require 'spec_helper'

describe Xray::Middleware, "in a middleware stack" do
  def app_response(status, content_type, body)
    body = body.unindent
    app = Rack::Builder.new do
      use Xray::Middleware
      run lambda { |env| [status, {'Content-Type' => content_type}, [body]] }
    end
    Rack::MockRequest.new(app)
  end

  it "passes normal app responses through unchanged" do
    html = <<-HTML
      <html>
        <head></head>
        <body><div>Hello</div></body>
      </html>
    HTML

    response = app_response(200, 'text/html', html).get('/')

    expect(response.status).to eq(200)
    expect(response.body).to eq(html.unindent)
  end

  it "opens files for /_xray/open requests" do
    allow(Xray).to receive(:open_file).and_return(['', '', instance_double(Process::Status, success?: true)])

    response = app_response(200, 'text/html', 'ignored').get('/_xray/open?path=/tmp/test')

    expect(Xray).to have_received(:open_file).with('/tmp/test')
    expect(response.status).to eq(200)
  end

  it "returns 500 when opening file fails" do
    allow(Xray).to receive(:open_file).and_return(['error', '', instance_double(Process::Status, success?: false)])

    response = app_response(200, 'text/html', 'ignored').get('/_xray/open?path=/tmp/test')

    expect(response.status).to eq(500)
    expect(response.body).to include('error')
  end

  it "updates editor config for POST /_xray/config" do
    allow(Xray.config).to receive(:editor=) { |value| value }
    response = app_response(200, 'text/html', 'ignored').post('/_xray/config', params: { editor: 'vim' })
    expect(response.status).to eq(200)
    expect(Xray.config).to have_received(:editor=).with('vim')
  end

  it "returns 400 for non-POST /_xray/config requests" do
    response = app_response(200, 'text/html', 'ignored').get('/_xray/config')
    expect(response.status).to eq(400)
  end

  it "returns 400 for invalid /_xray/config payloads" do
    allow(Xray.config).to receive(:editor=) { |value| value }
    response = app_response(200, 'text/html', 'ignored').post('/_xray/config', params: {})
    expect(response.status).to eq(400)
  end
end

describe Xray::Middleware, "in a Rails app" do
  it "includes xray.js from the rendered xray bar partial" do
    visit '/'
    expect(page).to have_selector('script[src^="/assets/xray"]')
  end

  it "adds nonce to the xray.js script tag" do
    visit '/'
    expect(page).to have_selector('script[src^="/assets/xray"][nonce]')
    expect(page.find('script[src^="/assets/xray"]')[:nonce]).to eq page.find('meta[name="csp-nonce"]')[:content]
  end

  it "renders the xray bar partial" do
    visit '/'
    expect(page).to have_selector('#xray-bar')
  end

  it "doesn't mess with non-html requests" do
    visit '/non_html'
    expect(page.html).not_to include('xray')
    expect(page).not_to have_selector('#xray-bar')
  end

  context "edge cases" do
    it "does not add html comments to mailer templates" do
      mail = TestMailer.hello
      expect(mail.body.raw_source).not_to include('<!--XRAY START')
    end
  end
end
