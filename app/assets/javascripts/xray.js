(function () {
  'use strict';

  const MAX_ZINDEX = 2147483647;
  const Xray = {};
  const ensureResponseOk = (response) => {
    if (response.ok) return response;
    throw new Error(`Request failed with status ${response.status}`);
  };
  const requestXray = (url, options = {}) => fetch(url, {
    credentials: 'same-origin',
    ...options
  }).then(ensureResponseOk);
  const requestOpenPath = (path) => requestXray('/_xray/open?path=' + encodeURIComponent(path), {
    method: 'GET'
  });
  const requestConfigUpdate = (editor) => requestXray('/_xray/config', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ editor })
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
  const isToggleShortcut = (event, isMac) => {
    const modifierPressed = (isMac && event.metaKey) || (!isMac && event.ctrlKey);
    return modifierPressed && event.shiftKey && event.key.toLowerCase() === 'x';
  };
  const isMacOS = () => {
    if (navigator.userAgentData && navigator.userAgentData.platform) {
      return navigator.userAgentData.platform.toLowerCase().includes('mac');
    }
    return /Mac/.test(navigator.userAgent);
  };
  const getOverlay = () => {
    if (!Xray.overlay) {
      Xray.overlay = new XrayOverlay();
    }
    return Xray.overlay;
  };

  Xray.init = () => {
    if (Xray.initialized) {
      return;
    }
    Xray.initialized = true;
    const isMac = isMacOS();
    document.addEventListener('keydown', (e) => {
      if (isToggleShortcut(e, isMac)) {
        if (Xray.isShowing) {
          getOverlay().hide();
        } else {
          getOverlay().show();
        }
      }
      else if (Xray.isShowing && e.key === 'Escape') {
        getOverlay().hide();
      }
    });
    runWhenDomReady(() => {
      getOverlay();
      findTemplates();
      if (typeof console !== 'undefined' && console !== null) {
        console.log('Ready to Xray. Press ' + (isMac ? 'cmd+shift+x' : 'ctrl+shift+x') + ' to scan your UI.');
      }
    });
  };

  const XRAY_START_COMMENT_REGEX = /^XRAY START (\d+) (.*)$/;
  const findTemplates = () => {
    const root = document.body || document.documentElement;
    if (!root) return;

    const walker = document.createTreeWalker(root, NodeFilter.SHOW_COMMENT);
    const startComments = [];
    let commentNode = walker.nextNode();

    while (commentNode) {
      const inIgnoredContainer = commentNode.parentElement && commentNode.parentElement.closest('script, iframe');
      if (inIgnoredContainer) {
        commentNode = walker.nextNode();
        continue;
      }

      const match = commentNode.data.match(XRAY_START_COMMENT_REGEX);
      if (match) {
        startComments.push({
          comment: commentNode,
          id: match[1],
          path: match[2]
        });
      }
      commentNode = walker.nextNode();
    }

    startComments.forEach(({ comment, id, path }) => {
      const templateContents = [];
      let currentNode = comment.nextSibling;

      while (currentNode && !(currentNode.nodeType === Node.COMMENT_NODE && currentNode.data === ('XRAY END ' + id))) {
        if (currentNode.nodeType === Node.ELEMENT_NODE && currentNode.tagName !== 'SCRIPT') {
          templateContents.push(currentNode);
        }
        currentNode = currentNode.nextSibling;
      }

      const endComment = currentNode && currentNode.nodeType === Node.COMMENT_NODE ? currentNode : null;
      if (endComment) {
        endComment.remove();
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

      box.addEventListener('click', () => {
        requestOpenPath(this.path).catch(() => {});
      });
      return box;
    }
  }

  class XrayOverlay {
    bar = new XrayBar('#xray-bar', () => this.settings.toggle());
    settings = new XraySettings('#xray-settings');
    shownBoxes = [];
    overlayEl = document.createElement('div');

    constructor() {
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

      findTemplates();
      const specimens = Specimen.all;

      specimens.forEach((specimen) => {
        if (!specimen.isVisible()) return;

        const box = specimen.makeBox();
        box.style.zIndex = Math.ceil(MAX_ZINDEX * 0.9 + specimen.bounds.top + specimen.bounds.left);
        this.shownBoxes.push(box);
        document.body.appendChild(box);
      });
    };

    reset = () => {
      this.shownBoxes.forEach((box) => box.remove());
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
    onSettingsToggle;
    cachedEl = null;
    originalPadding = null;

    constructor(bar, onSettingsToggle = null) {
      this.bar = bar;
      this.onSettingsToggle = onSettingsToggle;
    }

    getBarEl = () => {
      if (this.cachedEl && document.body.contains(this.cachedEl)) {
        return this.cachedEl;
      }

      this.cachedEl = document.querySelector(this.bar);
      if (!this.cachedEl) return null;

      this.cachedEl.style.zIndex = MAX_ZINDEX;

      const controllerBtns = this.cachedEl.querySelectorAll('#xray-bar-controller-path .xray-bar-btn');
      controllerBtns.forEach((button) => {
        button.addEventListener('click', () => {
          const path = button.getAttribute('data-path');
          if (path) {
            requestOpenPath(path).catch(() => {});
          }
        });
      });

      const settingsBtn = this.cachedEl.querySelector('.xray-bar-settings-btn');
      if (settingsBtn && this.onSettingsToggle) {
        settingsBtn.addEventListener('click', this.onSettingsToggle);
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

    constructor(settings) {
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

      requestConfigUpdate(editor)
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
    };
  }
  Xray.init();
})();
