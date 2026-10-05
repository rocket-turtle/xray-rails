require 'spec_helper'

describe 'Xray.open_file' do
  let(:file) { '/path/to/file' }

  def expect_argv(*argv)
    expect(Open3).to receive(:capture3).with([argv.first, argv.first], *argv.drop(1))
  end

  it "uses the configured editor" do
    allow(Xray.config).to receive_messages(editor: 'cool_editor')
    expect_argv('cool_editor', file)
    Xray.open_file(file)
  end

  it "replaces $file in the editor command with the filename" do
    allow(Xray.config).to receive_messages(editor: 'cool_editor --open "$file"')
    expect_argv('cool_editor', '--open', file)
    Xray.open_file(file)
  end

  it "raises when no editor is configured" do
    allow(Xray.config).to receive_messages(editor: nil)
    expect { Xray.open_file(file) }.to raise_error(RuntimeError, /No editor configured/)
  end

  it "raises when the configured editor is blank" do
    allow(Xray.config).to receive_messages(editor: '   ')
    expect { Xray.open_file(file) }.to raise_error(RuntimeError, /blank/)
  end

  context "when a path carries shell metacharacters" do
    let(:file) { '/tmp/file"; touch /tmp/xray_injected; echo "' }

    it "passes the path as a single argument" do
      allow(Xray.config).to receive_messages(editor: 'cool_editor')
      expect_argv('cool_editor', file)
      Xray.open_file(file)
    end

    it "does not execute the smuggled command" do
      FileUtils.rm_f('/tmp/xray_injected')
      allow(Xray.config).to receive_messages(editor: '/bin/echo')
      Xray.open_file(file)
      expect(File.exist?('/tmp/xray_injected')).to be(false)
    end
  end

  context "when the configured editor carries shell metacharacters" do
    it "treats them as arguments rather than as a command sequence" do
      FileUtils.rm_f('/tmp/xray_injected_editor')
      allow(Xray.config).to receive_messages(editor: '/bin/echo hi; touch /tmp/xray_injected_editor')
      Xray.open_file(file)
      expect(File.exist?('/tmp/xray_injected_editor')).to be(false)
    end
  end
end
