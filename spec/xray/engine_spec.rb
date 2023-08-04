require 'spec_helper'

describe Xray::Engine do
  context 'ActionView::Template monkeypatch #render' do
    subject { ActionView::Template.new(nil, nil, nil, *{}) }
    let(:xray_enabled_render_args) { ['template', { example_option: true }] }
    let(:xray_disabled_render_args) { ['template', { example_option: true, xray: false }] }
    let(:render_result) { '<html>Example</html>' }
    let(:plain_text_result) { 'Example' }
    let(:augmented_render_result) { '<html>Example<script>Example XRAY</script></html>' }
    let(:html_identifier) { 'template.html' }
    let(:txt_identifier) { 'template.txt' }

    it 'should render and augment valid HTML like files by default' do
      expect(subject).to receive(:render_without_xray).with(*xray_enabled_render_args).and_return(render_result)
      expect(subject).to receive(:identifier).and_return(html_identifier)
      expect(Xray).to receive(:augment_template).with(render_result, html_identifier).and_return(augmented_render_result)
      expect(subject.render(*xray_enabled_render_args)).to eql(augmented_render_result)
    end

    it 'should render and augment when template source is an empty string' do
      expect(subject).to receive(:render_without_xray).with(*xray_enabled_render_args).and_return('')
      expect(subject).to receive(:identifier).and_return(html_identifier)
      expect(Xray).to receive(:augment_template).with('', html_identifier).and_return(augmented_render_result)
      expect(subject.render(*xray_enabled_render_args)).to eql(augmented_render_result)
    end

    it 'should render but not augment HTML if :xray => false passed as an option' do
      expect(subject).to receive(:render_without_xray).with(*xray_enabled_render_args).and_return(render_result)
      expect(subject).to receive(:identifier).and_return(html_identifier)
      expect(Xray).to receive(:augment_template).with(render_result, html_identifier).and_return(augmented_render_result)
      expect(subject.render(*xray_enabled_render_args)).to eql(augmented_render_result)
    end

    it 'should render but not augment non HTML files' do
      expect(subject).to receive(:render_without_xray).with(*xray_disabled_render_args).and_return(plain_text_result)
      expect(subject).to receive(:identifier).and_return(txt_identifier)
      expect(Xray).not_to receive(:augment_template)
      expect(subject.render(*xray_disabled_render_args)).to eql(plain_text_result)
    end

    it 'should render but not augment when template source is nil' do
      expect(subject).to receive(:render_without_xray).with(*xray_enabled_render_args).and_return(nil)
      expect(subject).to receive(:identifier).and_return(html_identifier)
      expect(Xray).not_to receive(:augment_template)
      expect(subject.render(*xray_enabled_render_args)).to eql(nil)
    end
  end
end

