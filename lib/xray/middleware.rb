module Xray
  OPEN_PATH = '/_xray/open'
  UPDATE_CONFIG_PATH = '/_xray/config'

  # This middleware listens for requests to open files with the user's editor
  # and to update xray config.
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

      else
        @app.call(env)
      end
    end
  end
end
