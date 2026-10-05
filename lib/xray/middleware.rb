require "ipaddr"

module Xray
  OPEN_PATH = '/_xray/open'
  UPDATE_CONFIG_PATH = '/_xray/config'
  REQUEST_HEADER = 'HTTP_X_XRAY_REQUEST'

  # This middleware listens for requests to open files with the user's editor
  # and to update xray config.
  class Middleware
    # +hosts+ takes entries in the shape of Rails' config.hosts, naming the
    # hosts beyond localhost and IP addresses the endpoints answer on. +root+
    # anchors the relative template paths ActionView annotations carry.
    def initialize(app, hosts: [], root: Dir.pwd)
      @app = app
      @hosts = hosts
      @root = root
    end

    def call(env)
      case env['PATH_INFO']
      when OPEN_PATH then authorized(env) { |req| open_file(req) }
      when UPDATE_CONFIG_PATH then authorized(env) { |req| update_config(req) }
      else @app.call(env)
      end
    end

    private

    # Both endpoints act on the developer's machine rather than on the
    # application, so no page the developer merely visits may reach them. A POST
    # carrying a custom header is a shape no cross-origin form, image or script
    # tag can produce: the header forces a preflight, which goes unanswered.
    #
    # A DNS rebinding attack sidesteps that by pointing a hostname the attacker
    # controls at the developer's machine, which makes their page same-origin.
    # Its requests still name the attacker's host, so only hosts the developer
    # chose are let through.
    def authorized(env)
      req = Rack::Request.new(env)
      return respond(405) unless req.post?
      return respond(403) unless env[REQUEST_HEADER] && permitted_host?(env['HTTP_HOST'])

      yield req
    end

    # Reads the Host header itself rather than Rack's host, which defers to
    # X-Forwarded-Host -- a header any page may set on its own requests.
    def permitted_host?(header)
      host = header.to_s.downcase
      host = host.start_with?('[') ? host[/\A\[(.*)\]/, 1].to_s : host.sub(/:\d+\z/, '')

      # No rebinding attack can make a browser send an IP address or a
      # .localhost name, which browsers resolve to loopback on their own.
      return true if host == 'localhost' || host.end_with?('.localhost') || ip_address?(host)

      @hosts.any? do |allowed|
        case allowed
        when Regexp then host.match?(/\A#{allowed}\z/)
        when String
          allowed = allowed.downcase
          allowed.start_with?('.') ? host == allowed[1..] || host.end_with?(allowed) : host == allowed
        end
      end
    end

    def ip_address?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::Error
      false
    end

    def open_file(req)
      path = req.POST['path']
      return respond(400) if path.nil? || path.empty?

      # The path ends up as an argument to the editor, where anything not
      # naming a file -- a leading `-` or vim's `+cmd` -- could be read as an
      # option. An absolute path to an existing file is never mistaken for one.
      path = File.expand_path(path, @root)
      return respond(404) unless File.file?(path)

      out, _err, status = Xray.open_file(path)
      status.success? ? respond(200) : respond(500, out)
    rescue RuntimeError, SystemCallError, ArgumentError => e
      # Exec'ing the editor directly means a misconfigured command raises rather
      # than coming back as a failed status the way a shell would have reported
      # it: a missing binary as SystemCallError, an unbalanced quote in the
      # configured command as ArgumentError out of Shellwords.
      respond(500, e.message)
    end

    def update_config(req)
      editor = req.POST['editor']
      return respond(400) if editor.nil? || editor.empty?

      # Reject a command that cannot be parsed rather than persisting it, which
      # would break every later open until .xrayconfig is edited by hand.
      begin
        Shellwords.split(editor)
      rescue ArgumentError => e
        return respond(400, e.message)
      end

      Xray.config.editor = editor
      respond(200)
    end

    def respond(status, body = nil)
      res = Rack::Response.new
      res.status = status
      res.write(body) if body
      res.finish
    end
  end
end
