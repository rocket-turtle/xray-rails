require 'ferrum'
require 'tmpdir'

# Drives xray.js against a static page, so the template parsing, nesting and
# stacking can be exercised without booting Rails or serving assets.
module OverlayHarness
  ASSET_ROOT = File.expand_path('../../app/assets', __dir__)

  class << self
    def browser
      @browser ||= Ferrum::Browser.new(headless: true, timeout: 20)
    end

    def quit!
      @browser&.quit
      @browser = nil
    end
  end

  # Loads body_html with xray.js active, reveals the overlay, and returns the
  # specimen boxes in DOM order -- which is also their stacking order.
  def specimens_for(body_html)
    load_page(body_html)
    reveal_overlay
    OverlayHarness.browser.evaluate(<<~JS)
      Array.from(document.querySelectorAll('.xray-specimen')).map(function (box) {
        var handle = box.querySelector('.xray-specimen-handle');
        return {
          label: handle ? handle.textContent : null,
          title: box.title,
          width: parseFloat(box.style.width) || 0,
          height: parseFloat(box.style.height) || 0,
          zIndex: box.style.zIndex
        };
      })
    JS
  end

  def load_page(body_html)
    path = File.join(Dir.mktmpdir('xray-fixture'), 'page.html')
    File.write(path, page_html(body_html))
    OverlayHarness.browser.goto("file://#{path}")
  end

  # Both modifiers are set so the shortcut matches whichever platform xray.js
  # detects for the host running the suite.
  def reveal_overlay
    OverlayHarness.browser.evaluate(<<~JS)
      document.dispatchEvent(new KeyboardEvent('keydown', {
        key: 'x', shiftKey: true, metaKey: true, ctrlKey: true, bubbles: true
      })) && null
    JS
  end

  # Models a Turbo Drive Back navigation: the snapshot is taken *after* xray has
  # scanned the page, then restored and announced with turbo:render.
  def restore_turbo_snapshot
    OverlayHarness.browser.evaluate(<<~JS)
      (function () {
        document.querySelectorAll('.xray-specimen, #xray-overlay').forEach(function (el) { el.remove(); });
        document.body.innerHTML = document.body.innerHTML;
        document.dispatchEvent(new CustomEvent('turbo:render', { bubbles: true }));
        return null;
      })()
    JS
  end

  def shown_specimen_labels
    OverlayHarness.browser.evaluate(<<~JS)
      Array.from(document.querySelectorAll('.xray-specimen-handle')).map(function (h) { return h.textContent; })
    JS
  end

  def remaining_annotation_comments
    OverlayHarness.browser.evaluate(<<~JS)
      (function () {
        var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_COMMENT);
        var found = [], node;
        while ((node = walker.nextNode())) {
          if (/^(BEGIN|END) /.test(node.data.trim())) found.push(node.data.trim());
        }
        return found;
      })()
    JS
  end

  private

  def page_html(body_html)
    <<~HTML
      <!DOCTYPE html>
      <html>
        <head><style>#{File.read(File.join(ASSET_ROOT, 'stylesheets/xray.css'))}</style></head>
        <body>
          #{body_html}
          <script>#{File.read(File.join(ASSET_ROOT, 'javascripts/xray.js'))}</script>
        </body>
      </html>
    HTML
  end
end

RSpec.configure do |config|
  config.include OverlayHarness, :overlay
  config.after(:suite) { OverlayHarness.quit! }
end
