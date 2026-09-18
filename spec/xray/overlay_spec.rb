require 'spec_helper'

describe 'xray.js overlay', :overlay do
  def annotated(path, inner)
    "<!-- BEGIN #{path} -->#{inner}<!-- END #{path} -->"
  end

  context 'template parsing' do
    it 'creates one specimen per annotated template' do
      specimens = specimens_for(annotated('app/views/shared/_card.slim', '<div style="height:40px">card</div>'))

      expect(specimens.map { |s| s['label'] }).to eq(['_card.slim'])
      expect(specimens.first['title']).to eq('app/views/shared/_card.slim')
    end

    it 'matches nested ranges so each template gets its own specimen' do
      inner = annotated('app/views/shared/_inner.slim', '<div style="height:20px">inner</div>')
      specimens = specimens_for(
        annotated('app/views/shared/_outer.slim', "<div style='height:80px'>outer#{inner}</div>")
      )

      expect(specimens.map { |s| s['label'] }).to contain_exactly('_outer.slim', '_inner.slim')
    end

    it 'ignores an END without a matching BEGIN' do
      specimens = specimens_for("<!-- END app/views/shared/_ghost.slim --><div>content</div>")

      expect(specimens).to be_empty
    end

    it 'skips the xray bar partial' do
      specimens = specimens_for(annotated('app/views/_xray_bar.html.erb', '<div style="height:20px">bar</div>'))

      expect(specimens).to be_empty
    end

    it 'does not treat an unannotated comment as a template' do
      specimens = specimens_for('<!-- just a comment --><div style="height:20px">content</div>')

      expect(specimens).to be_empty
    end
  end

  context 'stacking order' do
    # Boxes are appended in paint order, so the last element is the topmost one.
    it 'places a smaller nested template above the template that rendered it' do
      inner = annotated('app/views/shared/_inner.slim', '<div style="height:20px">inner</div>')
      specimens = specimens_for(
        annotated('app/views/shared/_outer.slim', "<div style='height:200px'>outer#{inner}</div>")
      )

      expect(specimens.last['label']).to eq('_inner.slim')
      expect(specimens.first['label']).to eq('_outer.slim')
    end

    it 'gives every specimen the same z-index so DOM order decides' do
      inner = annotated('app/views/shared/_inner.slim', '<div style="height:20px">inner</div>')
      specimens = specimens_for(
        annotated('app/views/shared/_outer.slim', "<div style='height:200px'>outer#{inner}</div>")
      )

      expect(specimens.map { |s| s['zIndex'] }.uniq.size).to eq(1)
    end

    it 'places a nested template above its parent when both cover the same area' do
      pending 'known defect: equal areas fall back to insertion order, which is inner-first'

      inner = annotated('app/views/shared/_inner.slim', '<div style="height:50px">inner</div>')
      specimens = specimens_for(annotated('app/views/shared/_outer.slim', inner))

      expect(specimens.last['label']).to eq('_inner.slim')
    end
  end

  context 'the annotations in the document' do
    let(:card) { annotated('app/views/shared/_card.slim', '<div style="height:40px">card</div>') }

    it 'leaves them in place so a restored Turbo snapshot can be re-scanned' do
      specimens_for(card)

      expect(remaining_annotation_comments).to eq(
        ['BEGIN app/views/shared/_card.slim', 'END app/views/shared/_card.slim']
      )
    end

    it 'does not build a second specimen for a template it already scanned' do
      specimens_for(card)
      reveal_overlay # toggles off
      reveal_overlay # and on again, re-running findTemplates

      expect(shown_specimen_labels).to eq(['_card.slim'])
    end

    it 'still finds templates after a Turbo snapshot is restored' do
      specimens_for(card)
      restore_turbo_snapshot
      reveal_overlay

      expect(shown_specimen_labels).to eq(['_card.slim'])
    end
  end
end
