require_relative "xray/version"
require_relative "xray/config"
require_relative "xray/current"
require_relative "xray/middleware"

if defined?(Rails) && Rails.env.development?
  require "xray/engine"
end

require "open3"
require "shellwords"

module Xray
  FILE_PLACEHOLDER = '$file'

  # Used to collect request information during each request cycle for use in
  # the Xray bar.
  def self.request_info
    Current.request_info
  end

  def self.open_file(file)
    argv = editor_argv(file)

    # The single-string form of capture3 hands the command to a shell, which
    # would let a file path or a configured editor smuggle in commands of its
    # own. The [command, argv0] first element forces an exec even when the
    # editor resolves to a single argument, where a bare string would still be
    # shelled out.
    Open3.capture3([argv.first, argv.first], *argv.drop(1))
  end

  # Splits the configured editor into an argv, substituting the file for
  # FILE_PLACEHOLDER, or appending it when the editor names no placeholder.
  def self.editor_argv(file)
    editor = Xray.config.editor
    raise "No editor configured for xray-rails. Set $GEM_EDITOR, $VISUAL, or $EDITOR, or configure one via the xray bar." if editor.nil?

    argv = Shellwords.split(editor)
    raise "The editor configured for xray-rails is blank." if argv.empty?

    if argv.any? { |arg| arg.include?(FILE_PLACEHOLDER) }
      argv.map { |arg| arg.gsub(FILE_PLACEHOLDER, file.to_s) }
    else
      argv + [file.to_s]
    end
  end
end
