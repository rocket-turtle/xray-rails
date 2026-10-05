require 'spec_helper'

describe Xray::Config do
  context 'default_editor' do
    before do
      allow(Xray.config).to receive(:local_config).and_return({})
    end

    it 'should return nil when no editor env var is set' do
      allow(ENV).to receive(:[])
      expect(Xray.config.editor).to be_nil
    end

    it 'should use $GEM_EDITOR over $VISUAL and $EDITOR' do
      ENV['GEM_EDITOR'] = 'vim'
      ENV['VISUAL'] = 'emacs'
      ENV['EDITOR'] = 'emacs'
      expect(Xray.config.editor).to eq('vim')
    end

    it 'should use $VISUAL over $EDITOR' do
      ENV['GEM_EDITOR'] = nil
      ENV['VISUAL'] = 'vim'
      ENV['EDITOR'] = 'emacs'
      expect(Xray.config.editor).to eq('vim')
    end

    it 'should use $HOME/.xrayconfig over env variables' do
      ENV['GEM_EDITOR'] = 'vim'
      allow(Xray.config).to receive(:local_config).and_return(editor: 'emacs')
      expect(Xray.config.editor).to eq('emacs')
    end
  end

  context "a hand-edited config file" do
    let(:dir) { Dir.mktmpdir }
    let(:file) { File.join(dir, '.xrayconfig') }
    let(:config) { Xray::Config.new }

    before do
      allow(config).to receive(:config_file).and_return(file)
      allow(config).to receive(:default_editor).and_return('vim')
    end
    after { FileUtils.remove_entry(dir) }

    it "accepts string keys" do
      File.write(file, "editor: code\n")
      expect(config.editor).to eq('code')
    end

    it "accepts the symbol keys Xray writes" do
      config.editor = 'emacs'
      expect(Xray::Config.new.tap { |c| allow(c).to receive(:config_file).and_return(file) }.editor).to eq('emacs')
    end

    it "falls back to the default when the file is empty or holds no settings" do
      ["", "just a string\n", "- a\n- list\n"].each do |content|
        File.write(file, content)
        expect(config.editor).to eq('vim'), content.inspect
      end
    end

    it "warns and falls back to the default when the file cannot be loaded" do
      ["editor: [unclosed\n", "editor: !ruby/object:Object {}\n"].each do |content|
        File.write(file, content)
        expect { expect(config.editor).to eq('vim') }.to output(/\[xray\] Ignoring/).to_stderr
      end
    end
  end

  context ".config_file" do
    it "should use $HOME/.xrayconfig as default config file" do
      allow(Dir).to receive(:home).and_return('/home')
      expect(Xray.config.config_file).to eq('/home/.xrayconfig')
    end

    it "should use $PROJECT/.xrayconfig if it exists" do
      allow(File).to receive(:exist?).and_return(true)
      allow(Dir).to receive(:pwd).and_return('/project')
      expect(Xray.config.config_file).to eq("/project/.xrayconfig")
    end
  end
end
