require 'spec_helper'

describe Xray::Middleware, "in a middleware stack" do
  XRAY_HEADER = { 'HTTP_X_XRAY_REQUEST' => '1', 'HTTP_HOST' => 'localhost:3000' }.freeze

  let(:file) { Tempfile.create('xray').tap(&:close).path }
  after { File.delete(file) if File.exist?(file) }

  def app_response(status = 200, content_type = 'text/html', body = 'ignored', hosts: [])
    body = body.unindent
    app = Rack::Builder.new do
      use Xray::Middleware, hosts: hosts, root: File.dirname(__FILE__)
      run lambda { |env| [status, {'Content-Type' => content_type}, [body]] }
    end
    Rack::MockRequest.new(app)
  end

  def success_status(success)
    instance_double(Process::Status, success?: success)
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

  context "POST /_xray/open" do
    it "opens the requested file" do
      allow(Xray).to receive(:open_file).and_return(['', '', success_status(true)])

      response = app_response.post('/_xray/open', { params: { path: file } }.merge(XRAY_HEADER))

      expect(Xray).to have_received(:open_file).with(file)
      expect(response.status).to eq(200)
    end

    it "returns 500 when opening the file fails" do
      allow(Xray).to receive(:open_file).and_return(['error', '', success_status(false)])

      response = app_response.post('/_xray/open', { params: { path: file } }.merge(XRAY_HEADER))

      expect(response.status).to eq(500)
      expect(response.body).to include('error')
    end

    it "reports the reason when no editor is configured" do
      allow(Xray).to receive(:open_file).and_raise(RuntimeError, 'No editor configured for xray-rails.')

      response = app_response.post('/_xray/open', { params: { path: file } }.merge(XRAY_HEADER))

      expect(response.status).to eq(500)
      expect(response.body).to include('No editor configured')
    end

    it "reports the reason when the editor command does not exist" do
      allow(Xray).to receive(:open_file).and_raise(Errno::ENOENT, 'nonexistent_editor')

      response = app_response.post('/_xray/open', { params: { path: file } }.merge(XRAY_HEADER))

      expect(response.status).to eq(500)
      expect(response.body).to include('nonexistent_editor')
    end

    it "reports the reason when the configured editor cannot be parsed" do
      allow(Xray).to receive(:open_file).and_raise(ArgumentError, 'Unmatched quote')

      response = app_response.post('/_xray/open', { params: { path: file } }.merge(XRAY_HEADER))

      expect(response.status).to eq(500)
      expect(response.body).to include('Unmatched quote')
    end

    it "resolves a relative path against the app root" do
      allow(Xray).to receive(:open_file).and_return(['', '', success_status(true)])

      response = app_response.post('/_xray/open', { params: { path: File.basename(__FILE__) } }.merge(XRAY_HEADER))

      expect(response.status).to eq(200)
      expect(Xray).to have_received(:open_file).with(File.expand_path(__FILE__))
    end

    # The path is handed to the editor as an argument, where something like
    # vim's `+cmd` or a `--flag` would be read as an option instead of a file.
    it "refuses a path that names no existing file" do
      allow(Xray).to receive(:open_file)

      ['+!touch /tmp/pwned', '--help', File.dirname(file), '/nonexistent/file'].each do |path|
        response = app_response.post('/_xray/open', { params: { path: path } }.merge(XRAY_HEADER))
        expect(response.status).to eq(404), path
      end
      expect(Xray).not_to have_received(:open_file)
    end

    it "returns 400 without a path" do
      response = app_response.post('/_xray/open', { params: {} }.merge(XRAY_HEADER))
      expect(response.status).to eq(400)
    end
  end

  context "POST /_xray/config" do
    it "updates the editor config" do
      allow(Xray.config).to receive(:editor=)

      response = app_response.post('/_xray/config', { params: { editor: 'vim' } }.merge(XRAY_HEADER))

      expect(response.status).to eq(200)
      expect(Xray.config).to have_received(:editor=).with('vim')
    end

    it "rejects an editor command that cannot be parsed" do
      allow(Xray.config).to receive(:editor=)

      response = app_response.post('/_xray/config', { params: { editor: 'subl "' } }.merge(XRAY_HEADER))

      expect(response.status).to eq(400)
      expect(Xray.config).not_to have_received(:editor=)
    end

    it "returns 400 without an editor" do
      response = app_response.post('/_xray/config', { params: {} }.merge(XRAY_HEADER))
      expect(response.status).to eq(400)
    end
  end

  # These endpoints act on the developer's machine, so a page the developer
  # merely visits must not be able to reach them.
  context "requests a cross-origin page could forge" do
    it "rejects a GET to /_xray/open" do
      allow(Xray).to receive(:open_file)

      response = app_response.get('/_xray/open?path=/tmp/test')

      expect(response.status).to eq(405)
      expect(Xray).not_to have_received(:open_file)
    end

    it "rejects a POST to /_xray/open without the xray header" do
      allow(Xray).to receive(:open_file)

      response = app_response.post('/_xray/open', params: { path: '/tmp/test' })

      expect(response.status).to eq(403)
      expect(Xray).not_to have_received(:open_file)
    end

    it "rejects a GET to /_xray/config" do
      expect(app_response.get('/_xray/config').status).to eq(405)
    end

    it "rejects a POST to /_xray/config without the xray header" do
      allow(Xray.config).to receive(:editor=)

      response = app_response.post('/_xray/config', params: { editor: 'vim' })

      expect(response.status).to eq(403)
      expect(Xray.config).not_to have_received(:editor=)
    end

    # A DNS rebinding attack makes the attacker's page same-origin with the
    # app, so its requests may carry the header -- but they name its host.
    it "rejects a POST naming a host the app does not answer to" do
      allow(Xray.config).to receive(:editor=)

      response = app_response.post('/_xray/config', params: { editor: 'vim' }, 'HTTP_X_XRAY_REQUEST' => '1', 'HTTP_HOST' => 'evil.example:3000')

      expect(response.status).to eq(403)
      expect(Xray.config).not_to have_received(:editor=)
    end

    it "ignores X-Forwarded-Host, which any page can set" do
      response = app_response.post('/_xray/config', params: { editor: 'vim' }, 'HTTP_X_XRAY_REQUEST' => '1',
                                   'HTTP_HOST' => 'evil.example', 'HTTP_X_FORWARDED_HOST' => 'localhost')

      expect(response.status).to eq(403)
    end
  end

  context "hosts the endpoints answer on" do
    before { allow(Xray.config).to receive(:editor=) }

    def status_for(host, hosts: [])
      app_response(hosts: hosts).post('/_xray/config', params: { editor: 'vim' }, 'HTTP_X_XRAY_REQUEST' => '1', 'HTTP_HOST' => host).status
    end

    it "accepts localhost, .localhost names and IP addresses" do
      %w(localhost localhost:3000 app.localhost 127.0.0.1:3000 192.168.1.5 [::1]:3000).each do |host|
        expect(status_for(host)).to eq(200), host
      end
    end

    it "accepts hosts listed the way Rails' config.hosts lists them" do
      hosts = ['app.test', '.example.com', /.*\.ngrok\.io/]

      %w(app.test:3000 example.com dev.example.com abc.ngrok.io).each do |host|
        expect(status_for(host, hosts: hosts)).to eq(200), host
      end
      %w(other.test badexample.com ngrok.io.evil.example).each do |host|
        expect(status_for(host, hosts: hosts)).to eq(403), host
      end
    end
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
    it "uses Rails template annotations for mailer templates when enabled" do
      mail = TestMailer.hello
      expect(mail.body.raw_source).to include('<!-- BEGIN app/views/test_mailer/hello.html.erb -->')
      expect(mail.body.raw_source).to include('<!-- END app/views/test_mailer/hello.html.erb -->')
      expect(mail.body.raw_source).not_to include('<!--XRAY START')
    end
  end
end
