require 'spec_helper'

describe Xray::Rendering do
  it 'ActionView::Template prepend' do
    expect(ActionView::Template.ancestors.first).to be(Xray::Rendering)
  end

  context '#render' do
    subject do
      Class.new(ActionView::Template) do
        prepend Xray::Rendering

        def render(...)
          '<html>Example</html>'
        end
      end.new(nil, nil, nil, locals: [], **{})
    end
    let(:xray_enabled_render_args) { ['template', { example_option: true }] }
    let(:xray_disabled_render_args) { ['template', { example_option: true, xray: false }] }
    let(:render_result) { '<html>Example</html>' }
    let(:plain_text_result) { 'Example' }
    let(:augmented_render_result) { '<html>Example<script>Example XRAY</script></html>' }
    let(:html_identifier) { 'template.html' }
    let(:txt_identifier) { 'template.txt' }

    it 'should render and augment valid HTML like files by default' do
      expect(subject).to receive(:identifier).and_return(html_identifier)
      expect(Xray).to receive(:augment_template).with(render_result, html_identifier).and_return(augmented_render_result)
      expect(subject.render(*xray_enabled_render_args)).to eql(augmented_render_result)
    end

    it 'should render but not augment HTML if :xray => false passed as an option' do
      expect(subject).to receive(:identifier).and_return(html_identifier)
      expect(Xray).not_to receive(:augment_template)
      expect(subject.render(*xray_disabled_render_args)).to eql(render_result)
    end

    it 'should render but not augment non HTML files' do
      expect(subject).to receive(:identifier).and_return(txt_identifier)
      expect(Xray).not_to receive(:augment_template)
      expect(subject.render(*xray_enabled_render_args)).to eql(render_result)
    end
  end
end

