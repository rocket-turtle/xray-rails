(function () {
  'use strict';

  const MAX_ZINDEX = 2147483647;
  const Xray = {};
  const requestOpenPath = (path) => fetch('/_xray/open?path=' + encodeURIComponent(path), {
    method: 'GET',
    credentials: 'same-origin'
  });
  const runWhenDomReady = (callback) => {
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
    let isMac;
    if (Xray.initialized) {
      return;
    }
    Xray.initialized = true;
    isMac = navigator.platform.toUpperCase().indexOf('MAC') !== -1;
    document.addEventListener('keydown', (e) => {
      if ((isMac && e.metaKey || !isMac && e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === 'x') {
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
    return runWhenDomReady(() => {
      new XrayOverlay();
      Xray.findTemplates();
      return typeof console !== 'undefined' && console !== null ? console.log('Ready to Xray. Press ' + (isMac ? 'cmd+shift+x' : 'ctrl+shift+x') + ' to scan your UI.') : void 0;
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
      const match = comment.data.match(/^XRAY START (\d+) (.*)$/);
      if (!match) return;

      const id = match[1];
      const path = match[2];
      const templateContents = [];
      let currentNode = comment.nextSibling;

      while (!(!currentNode || (currentNode.nodeType === Node.COMMENT_NODE && currentNode.data === ('XRAY END ' + id)))) {
        if (currentNode.nodeType === Node.ELEMENT_NODE && currentNode.tagName !== 'SCRIPT') {
          templateContents.push(currentNode);
        }
        currentNode = currentNode.nextSibling;
      }

      if (currentNode != null && currentNode.nodeType === Node.COMMENT_NODE) {
        currentNode.remove();
      }
      comment.remove();

      Specimen.add(templateContents, {
        name: path.split('/').slice(-1)[0],
        path
      });
    });
  };

  const computeBoundingBox = (contents) => {
    const elements = toElementArray(contents);
    if (elements.length === 1 && elements[0].getBoundingClientRect().height <= 0) {
      return computeBoundingBox(elements[0].children);
    }
    const aggregateBounds = {
      top: Number.POSITIVE_INFINITY,
      left: Number.POSITIVE_INFINITY,
      right: Number.NEGATIVE_INFINITY,
      bottom: Number.NEGATIVE_INFINITY
    };

    for (let i = 0; i < elements.length; i++) {
      const el = elements[i];
      if (!isElementVisible(el)) continue;
      const rect = el.getBoundingClientRect();
      const elementBounds = {
        top: rect.top + window.scrollY,
        left: rect.left + window.scrollX,
        right: rect.left + window.scrollX + rect.width,
        bottom: rect.top + window.scrollY + rect.height
      };

      if (elementBounds.top < aggregateBounds.top) aggregateBounds.top = elementBounds.top;
      if (elementBounds.left < aggregateBounds.left) aggregateBounds.left = elementBounds.left;
      if (elementBounds.right > aggregateBounds.right) aggregateBounds.right = elementBounds.right;
      if (elementBounds.bottom > aggregateBounds.bottom) aggregateBounds.bottom = elementBounds.bottom;
    }
    return {
      left: aggregateBounds.left,
      top: aggregateBounds.top,
      width: aggregateBounds.right - aggregateBounds.left,
      height: aggregateBounds.bottom - aggregateBounds.top
    };
  };

  class Specimen {
    static all = [];

    static add(contents, info = {}) {
      return this.all.push(new this(contents, info));
    }

    constructor(contents, info = {}) {
      this.contents = toElementArray(contents);
      this.firstEl = this.contents[0] || null;
      this.name = info.name;
      this.path = info.path;
    }

    isVisible() {
      return this.contents.length > 0 && this.contents.some((el) => isElementVisible(el));
    }

    makeBox() {
      this.bounds = computeBoundingBox(this.contents);

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

      box.addEventListener('click', () => { requestOpenPath(this.path); });
      return box;
    }
  }

  class XrayOverlay {
    static singletonInstance = null;

    static instance = () => {
      return this.singletonInstance || (this.singletonInstance = new XrayOverlay());
    };

    bar = new XrayBar('#xray-bar');
    settings = new XraySettings('#xray-settings');
    shownBoxes = [];
    overlayEl = document.createElement('div');

    constructor() {
      XrayOverlay.singletonInstance = this;
      this.overlayEl.id = 'xray-overlay';
      this.overlayEl.addEventListener('click', this.hide);
    }

    show = () => {
      this.reset();
      Xray.isShowing = true;

      if (!this.overlayEl.isConnected) {
        document.body.appendChild(this.overlayEl);
        this.bar.show();
      }

      Xray.findTemplates();
      const specimens = Specimen.all;

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
      if (this.overlayEl.isConnected) {
        this.overlayEl.remove();
      }
      this.reset();
      this.bar.hide();
    };
  }

  class XrayBar {
    bar;
    cachedEl = null;
    originalPadding = null;

    constructor(bar) {
      this.bar = bar;
    }

    getBarEl = () => {
      if (this.cachedEl && document.body.contains(this.cachedEl)) {
        return this.cachedEl;
      }

      this.cachedEl = document.querySelector(this.bar);
      if (!this.cachedEl) return null;

      this.cachedEl.style.zIndex = MAX_ZINDEX;

      const controllerBtns = this.cachedEl.querySelectorAll('#xray-bar-controller-path .xray-bar-btn');
      controllerBtns.forEach(btn => {
        btn.addEventListener('click', () => {
          const path = btn.getAttribute('data-path');
          if (path) {
            requestOpenPath(path);
          }
        });
      });

      const settingsBtn = this.cachedEl.querySelector('.xray-bar-settings-btn');
      if (settingsBtn) {
        settingsBtn.addEventListener('click', () => XrayOverlay.instance().settings.toggle());
      }

      return this.cachedEl;
    };

    show = () => {
      const el = this.getBarEl();
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
      const el = this.getBarEl();
      if (!el) return;

      el.style.display = 'none';
      if (this.originalPadding !== null) {
        document.documentElement.style.paddingBottom = `${this.originalPadding}px`;
      }
    };
  }

  class XraySettings {
    settings;
    cachedEl = null;

    constructor (settings) {
      this.settings = settings;
    }

    getSettingsEl = () => {
      if (this.cachedEl && document.body.contains(this.cachedEl)) {
        return this.cachedEl;
      }

      this.cachedEl = document.querySelector(this.settings);
      if (!this.cachedEl) return null;

      const form = this.cachedEl.querySelector('form');
      if (form) {
        form.addEventListener('submit', this.save);
      }

      return this.cachedEl;
    };

    toggle = () => {
      const el = this.getSettingsEl();
      if (el) {
        const current = window.getComputedStyle(el).display;
        el.style.display = current === 'none' ? 'block' : 'none';
      }
    };

    save = (e) => {
      e.preventDefault();
      const el = this.getSettingsEl();
      if (!el) return;

      const editorInput = el.querySelector('#xray-editor-input');
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
      const el = this.getSettingsEl();
      if (!el) return;

      const statusMessageEl = document.createElement('span');
      statusMessageEl.className = `xray-settings-${success ? 'success' : 'error'} xray-settings-update-msg`;
      statusMessageEl.textContent = success ? 'Success!' : 'Uh oh, something went wrong!';
      el.appendChild(statusMessageEl);

      setTimeout(() => {
        statusMessageEl.remove();
        this.toggle();
      }, 3000);
    }
  }
})();
