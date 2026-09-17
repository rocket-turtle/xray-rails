require_relative "xray/version"
require_relative "xray/config"
require_relative "xray/middleware"

if defined?(Rails) && Rails.env.development?
  require "xray/engine"
end

require "open3"

module Xray
  FILE_PLACEHOLDER = '$file'

  # Used to collect request information during each request cycle for use in
  # the Xray bar.
  def self.request_info
    Thread.current[:request_info] ||= {}
  end

  def self.open_file(file)
    editor = Xray.config.editor
    raise "No editor configured for xray-rails. Set $GEM_EDITOR, $VISUAL, or $EDITOR, or configure one via the xray bar." if editor.nil?
    cmd = if editor.include?('$file')
      editor.gsub '$file', file
    else
      "#{editor} \"#{file}\""
    end
    Open3.capture3(cmd)
  end
end
