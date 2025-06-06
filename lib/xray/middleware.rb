module Xray
  OPEN_PATH = '/_xray/open'
  UPDATE_CONFIG_PATH = '/_xray/config'

  # This middleware is responsible for injecting xray.js and the Xray bar into
  # the app's pages. It also listens for requests to open files with the user's
  # editor.
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      # Request for opening a file path.
      if env['PATH_INFO'] == OPEN_PATH
        req, res = Rack::Request.new(env), Rack::Response.new
        out, _err, status = Xray.open_file(req.GET['path'])
        if status.success?
          res.status = 200
        else
          res.write out
          res.status = 500
        end
        res.finish
      elsif env['PATH_INFO'] == UPDATE_CONFIG_PATH
        req, res = Rack::Request.new(env), Rack::Response.new
        if req.post? && Xray.config.editor = req.POST['editor']
          res.status = 200
        else
          res.status = 400
        end
        res.finish

      # Inject xray.js and friends if this is a successful HTML response
      else
        status, headers, response = @app.call(env)

        if html_headers?(status, headers)
          body = response_body(response)
          if body && body =~ xray_script_matcher
            # Inject the xray bar if xray.js is already on the page
            inject_xray_bar!(body)

            content_length = body.bytesize.to_s

            # For rails v4.2.0+ compatibility
            if defined?(ActionDispatch::Response::RackBody) && ActionDispatch::Response::RackBody === response
              response = response.instance_variable_get(:@response)
            end

            # Modifying the original response obj maintains compatibility with other middlewares
            if ActionDispatch::Response === response
              response.body = [body]
              response.header['Content-Length'] = content_length unless committed?(response)
              response.to_a
            else
              headers['Content-Length'] = content_length
              [status, headers, [body]]
            end
          else
            [status, headers, response]
          end
        else
          [status, headers, response]
        end
      end
    end

    private

    def committed?(response)
      response.respond_to?(:committed?) && response.committed?
    end

    def inject_xray_bar!(html)
      xray_bar = ApplicationController.render(partial: "/xray_bar")
      html.sub!(/<body[^>]*>/) { "#{$~}\n#{xray_bar}" }
    end

    # Matches:
    #   <script src="/assets/xray.debug-1f24c4eb56c76ca56a881d5560552a44e98c0eeb30f47f8775a3d5557c7bffe3.js" nonce="UCCdiIBNaam7el9cVHptyA=="></script>
    def xray_script_matcher
      /
        <script[^>]+
        xray
        (\.(?:source|debug))?  # Sprockets 4 appends .source or .debug
        (-\h{32,64})?          # Fingerprint varies based on Sprockets version
        \.js                   # Must have .js extension
        [^>]+><\/script>
      /x
    end

    def html_headers?(status, headers)
      status == 200 &&
      headers['Content-Type'] &&
      headers['Content-Type'].include?('text/html') &&
      headers["Content-Transfer-Encoding"] != "binary"
    end

    def response_body(response)
      body = ''
      response.each { |s| body << s.to_s }
      body
    end
  end
end
