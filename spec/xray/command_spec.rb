require 'spec_helper'

describe 'Xray.open_file' do
  let(:file) { '/path/to/file' }

  it "uses the configured editor" do
    allow(Xray.config).to receive_messages(editor: 'cool_editor')
    expect(Open3).to receive(:capture3).with("cool_editor \"#{file}\"")
    Xray.open_file(file)
  end

  it "replace $file in the editor command with the filename" do
    allow(Xray.config).to receive_messages(editor: 'cool_editor --open "$file"')
    expect(Open3).to receive(:capture3).with("cool_editor --open \"#{file}\"")
    Xray.open_file(file)
  end
end
