(function () {
  'use strict';

  const MAX_ZINDEX = 2147483647;
  const Xray = {};
  const openPath = (path) => fetch('/_xray/open?path=' + encodeURIComponent(path), {
    method: 'GET',
    credentials: 'same-origin'
  });
  const onReady = (callback) => {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', callback, { once: true });
      return;
    }
    callback();
  };
  const toElementArray = (value) => {
    if (!value) return [];
    if (value instanceof Element) return [value];
    return Array.from(value).filter((el) => el instanceof Element);
  };
  const isElementVisible = (el) => {
    if (!(el instanceof Element)) return false;
    if (el.getClientRects().length === 0) return false;
    const style = window.getComputedStyle(el);
    return style.display !== 'none' && style.visibility !== 'hidden';
  };

  Xray.init = (function () {
    let is_mac;
    if (Xray.initialized) {
      return;
    }
    Xray.initialized = true;
    is_mac = navigator.platform.toUpperCase().indexOf('MAC') !== -1;
    document.addEventListener('keydown', (e) => {
      if ((is_mac && e.metaKey || !is_mac && e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === 'x') {
        if (Xray.isShowing) {
          XrayOverlay.instance().hide();
        } else {
          XrayOverlay.instance().show();
        }
      }
      if (Xray.isShowing && e.key === 'Escape') {
        XrayOverlay.instance().hide();
      }
    });
    return onReady(() => {
      new XrayOverlay();
      Xray.findTemplates();
      return typeof console !== 'undefined' && console !== null ? console.log('Ready to Xray. Press ' + (is_mac ? 'cmd+shift+x' : 'ctrl+shift+x') + ' to scan your UI.') : void 0;
    });
  })();

  Xray.findTemplates = function () {
    const comments = [];
    const elements = document.querySelectorAll('*:not(iframe,script)');
    elements.forEach((element) => {
      element.childNodes.forEach((node) => {
        if (node.nodeType === Node.COMMENT_NODE && node.data.startsWith('XRAY START')) {
          comments.push(node);
        }
      });
    });

    comments.forEach((comment) => {
      const ref = comment.data.match(/^XRAY START (\d+) (.*)$/);
      if (!ref) return;

      const id = ref[1];
      const path = ref[2];
      const templateContents = [];
      let el = comment.nextSibling;

      while (!(!el || (el.nodeType === Node.COMMENT_NODE && el.data === ('XRAY END ' + id)))) {
        if (el.nodeType === Node.ELEMENT_NODE && el.tagName !== 'SCRIPT') {
          templateContents.push(el);
        }
        el = el.nextSibling;
      }

      if (el != null && el.nodeType === Node.COMMENT_NODE) {
        el.remove();
      }
      comment.remove();

      Xray.Specimen.add(templateContents, {
        name: path.split('/').slice(-1)[0],
        path
      });
    });
  };

  Xray.computeBoundingBox = function (contents) {
    const elements = toElementArray(contents);
    if (elements.length === 1 && elements[0].getBoundingClientRect().height <= 0) {
      return Xray.computeBoundingBox(elements[0].children);
    }
    const boxFrame = {
      top: Number.POSITIVE_INFINITY,
      left: Number.POSITIVE_INFINITY,
      right: Number.NEGATIVE_INFINITY,
      bottom: Number.NEGATIVE_INFINITY
    };

    for (let i = 0; i < elements.length; i++) {
      const el = elements[i];
      if (!isElementVisible(el)) continue;
      const rect = el.getBoundingClientRect();
      const frame = {
        top: rect.top + window.scrollY,
        left: rect.left + window.scrollX,
        right: rect.left + window.scrollX + rect.width,
        bottom: rect.top + window.scrollY + rect.height
      };

      if (frame.top < boxFrame.top) boxFrame.top = frame.top;
      if (frame.left < boxFrame.left) boxFrame.left = frame.left;
      if (frame.right > boxFrame.right) boxFrame.right = frame.right;
      if (frame.bottom > boxFrame.bottom) boxFrame.bottom = frame.bottom;
    }
    return {
      left: boxFrame.left,
      top: boxFrame.top,
      width: boxFrame.right - boxFrame.left,
      height: boxFrame.bottom - boxFrame.top
    };
  }

  Xray.Specimen = (function () {
    Specimen.all = [];

    Specimen.add = function (el, info) {
      if (info == null) {
        info = {};
      }
      return this.all.push(new this(el, info));
    };

    function Specimen (contents, info) {
      if (info == null) {
        info = {};
      }
      this.contents = toElementArray(contents);
      this.el = this.contents[0] || null;
      this.name = info.name;
      this.path = info.path;
    }

    Specimen.prototype.isVisible = function () {
      return this.contents.length > 0 && this.contents.some((el) => isElementVisible(el));
    };

    Specimen.prototype.makeBox = function () {
      this.bounds = Xray.computeBoundingBox(this.contents);

      const box = document.createElement('div');
      box.className = 'xray-specimen';
      box.title = this.path;

      const label = document.createElement('div');
      label.className = 'xray-specimen-handle';
      label.textContent = this.name;
      box.appendChild(label);

      box.style.left = isFinite(this.bounds.left) ? `${this.bounds.left}px` : '0px';
      box.style.top = isFinite(this.bounds.top) ? `${this.bounds.top}px` : '0px';
      box.style.width = isFinite(this.bounds.width) ? `${this.bounds.width}px` : '0px';
      box.style.height = isFinite(this.bounds.height) ? `${this.bounds.height}px` : '0px';

      const firstContent = this.contents[0];
      if (firstContent && window.getComputedStyle(firstContent).position === 'fixed') {
        const style = window.getComputedStyle(firstContent);
        box.style.position = 'fixed';
        box.style.top = style.top;
        box.style.left = style.left;
      }

      box.addEventListener('click', () => { openPath(this.path); });
      return box;
    };

    return Specimen;
  })();

  class XrayOverlay {
    static singletonInstance = null;

    static instance = () => {
      return this.singletonInstance || (this.singletonInstance = new XrayOverlay());
    };

    bar = new XrayBar('#xray-bar');
    settings = new XraySettings('#xray-settings');
    shownBoxes = [];
    $overlay = document.createElement('div');

    constructor() {
      XrayOverlay.singletonInstance = this;
      this.$overlay.id = 'xray-overlay';
      this.$overlay.addEventListener('click', this.hide);
    }

    show = () => {
      this.reset();
      Xray.isShowing = true;

      if (!this.$overlay.isConnected) {
        document.body.appendChild(this.$overlay);
        this.bar.show();
      }

      Xray.findTemplates();
      const specimens = Xray.Specimen.all;

      specimens.forEach(element => {
        if (!element.isVisible()) return;

        const box = element.makeBox();
        box.style.zIndex = Math.ceil(MAX_ZINDEX * 0.9 + element.bounds.top + element.bounds.left);
        this.shownBoxes.push(box);
        document.body.appendChild(box);
      });
    };

    reset = () => {
      this.shownBoxes.forEach(box => box.remove());
      this.shownBoxes = [];
    };

    hide = () => {
      Xray.isShowing = false;
      if (this.$overlay.isConnected) {
        this.$overlay.remove();
      }
      this.reset();
      this.bar.hide();
    };
  }

  class XrayBar {
    bar;
    $el_memo = null;
    originalPadding = null;

    constructor(bar) {
      this.bar = bar;
    }

    $el = () => {
      if (this.$el_memo && document.body.contains(this.$el_memo)) {
        return this.$el_memo;
      }

      this.$el_memo = document.querySelector(this.bar);
      if (!this.$el_memo) return null;

      this.$el_memo.style.zIndex = MAX_ZINDEX;

      const $controllerBtns = this.$el_memo.querySelectorAll('#xray-bar-controller-path .xray-bar-btn');
      $controllerBtns.forEach(btn => {
        btn.addEventListener('click', () => {
          const path = btn.getAttribute('data-path');
          if (path) {
            openPath(path);
          }
        });
      });

      const $settingsBtn = this.$el_memo.querySelector('.xray-bar-settings-btn');
      if ($settingsBtn) {
        $settingsBtn.addEventListener('click', () => XrayOverlay.instance().settings.toggle());
      }

      return this.$el_memo;
    };

    show = () => {
      const el = this.$el();
      if (!el) return;

      el.style.display = 'block';

      const html = document.documentElement;
      const computedStyle = window.getComputedStyle(html);
      const padding = parseInt(computedStyle.paddingBottom, 10);
      this.originalPadding = isNaN(padding) ? 0 : padding;

      if (this.originalPadding < 40) {
        html.style.paddingBottom = '40px';
      }
    };

    hide = () => {
      const el = this.$el();
      if (!el) return;

      el.style.display = 'none';
      if (this.originalPadding !== null) {
        document.documentElement.style.paddingBottom = `${this.originalPadding}px`;
      }
    };
  }

  class XraySettings {
    settings;
    $el_memo = null;

    constructor (settings) {
      this.settings = settings;
    }

    $el = () => {
      if (this.$el_memo && document.body.contains(this.$el_memo)) {
        return this.$el_memo;
      }

      this.$el_memo = document.querySelector(this.settings);
      if (!this.$el_memo) return null;

      const form = this.$el_memo.querySelector('form');
      if (form) {
        form.addEventListener('submit', this.save);
      }

      return this.$el_memo;
    };

    toggle = () => {
      const $el = this.$el();
      if ($el) {
        const current = window.getComputedStyle($el).display;
        $el.style.display = current === 'none' ? 'block' : 'none';
      }
    };

    save = (e) => {
      e.preventDefault();
      const $el = this.$el();
      if (!$el) return;

      const editorInput = $el.querySelector('#xray-editor-input');
      const editor = editorInput ? editorInput.value : '';

      fetch('/_xray/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ editor })
      })
        .then(() => this.displayUpdateMsg(true))
        .catch(() => this.displayUpdateMsg(false));
    };

    displayUpdateMsg = (success) => {
      const $el = this.$el();
      if (!$el) return;

      const msg = document.createElement('span');
      msg.className = `xray-settings-${success ? 'success' : 'error'} xray-settings-update-msg`;
      msg.textContent = success ? 'Success!' : 'Uh oh, something went wrong!';
      $el.appendChild(msg);

      setTimeout(() => {
        msg.remove();
        this.toggle();
      }, 3000);
    }
  }
})();
