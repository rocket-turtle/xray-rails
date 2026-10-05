require "yaml"

module Xray

  def self.config
    @config ||= Config.new
  end

  class Config
    CONFIG_FILE = ".xrayconfig"

    def default_editor
      ENV['GEM_EDITOR'] ||
        ENV['VISUAL'] ||
        ENV['EDITOR']
    end

    def editor
      load_config[:editor]
    end

    def editor=(new_editor)
      if new_editor && new_editor != editor
        write_config(editor: new_editor)
        true
      else
        false
      end
    end

    def to_yaml
      {editor: editor}.to_yaml
    end

    def config_file
      if File.exist?("#{Dir.pwd}/#{CONFIG_FILE}")
        "#{Dir.pwd}/#{CONFIG_FILE}"
      else
        "#{Dir.home}/#{CONFIG_FILE}"
      end
    end

    private

    def write_config(new_config)
      config = load_config.merge(new_config)
      File.write(config_file, config.to_yaml)
    end

    def load_config
      default_config.merge(local_config)
    end

    # Symbolizing the keys accepts a hand-written `editor:` as well as the
    # `:editor:` Xray writes. An empty file loads as false and a bare scalar as
    # itself, neither of which carries any settings.
    def local_config
      config = YAML.load_file(config_file, symbolize_names: true)
      config.is_a?(Hash) ? config : {}
    rescue Errno::ENOENT
      {}
    rescue Psych::Exception => e
      warn "[xray] Ignoring #{config_file}: #{e.message}"
      {}
    end

    def default_config
      { editor: default_editor }
    end
  end
end
