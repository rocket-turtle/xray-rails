(function () {
  'use strict';

  const $ = window.jQuery;
  const MAX_ZINDEX = 2147483647;
  const hasProp = Object.prototype.hasOwnProperty;

  let util;

  window.Xray = {};

  if (!($)) { return; }

  Xray.init = (function () {
    let is_mac;
    if (Xray.initialized) {
      return;
    }
    Xray.initialized = true;
    is_mac = navigator.platform.toUpperCase().indexOf('MAC') !== -1;
    $(document).keydown((e) => {
      if ((is_mac && e.metaKey || !is_mac && e.ctrlKey) && e.shiftKey && e.keyCode === 88) {
        if (Xray.isShowing) {
          Xray.hide();
        } else {
          Xray.show();
        }
      }
      if (Xray.isShowing && e.keyCode === 27) {
        return Xray.hide();
      }
    });
    return $(() => {
      new Xray.Overlay();
      Xray.findTemplates();
      return typeof console !== 'undefined' && console !== null ? console.log('Ready to Xray. Press ' + (is_mac ? 'cmd+shift+x' : 'ctrl+shift+x') + ' to scan your UI.') : void 0;
    });
  })();

  Xray.constructorInfo = function (constructor) {
    let func, info, ref;
    if (window.XrayPaths) {
      ref = window.XrayPaths;
      for (info in ref) {
        if (!hasProp.call(ref, info)) continue;
        func = ref[info];
        if (func === constructor) {
          return JSON.parse(info);
        }
      }
    }
    return null;
  };

  Xray.findTemplates = function () {
    let $templateContents, _, comment, comments, el, id, path;
    comments = $('*:not(iframe,script)').contents().filter(function () {
      return this.nodeType === 8 && this.data.startsWith('XRAY START');
    });
    comments.each((_, comment) => {
      let ref;
      ref = comment.data.match(/^XRAY START (\d+) (.*)$/);
      if (!ref) return;
      _ = ref[0], id = ref[1], path = ref[2];
      $templateContents = new jQuery;
      el = comment.nextSibling;
      while (!(!el || (el.nodeType === 8 && el.data === ('XRAY END ' + id)))) {
        if (el.nodeType === 1 && el.tagName !== 'SCRIPT') {
          $templateContents.push(el);
        }
        el = el.nextSibling;
      }
      if ((el != null ? el.nodeType : void 0) === 8) {
        el.parentNode.removeChild(el);
      }
      comment.parentNode.removeChild(comment);

      Xray.Specimen.add($templateContents, {
        name: path.split('/').slice(-1)[0],
        path: path
      });
    });
  };

  Xray.open = function (path) {
    return $.ajax({
      url: '/_xray/open?path=' + encodeURIComponent(path)
    });
  };

  Xray.show = function () {
    return Xray.Overlay.instance().show();
  };

  Xray.hide = function () {
    return Xray.Overlay.instance().hide();
  };

  Xray.toggleSettings = function () {
    return Xray.Overlay.instance().settings.toggle();
  };

  Xray.Specimen = (function () {
    Specimen.all = [];

    Specimen.add = function (el, info) {
      if (info == null) {
        info = {};
      }
      return this.all.push(new this(el, info));
    };

    Specimen.remove = function (el) {
      let ref;
      return (ref = this.find(el)) != null ? ref.remove() : void 0;
    };

    Specimen.find = function (el) {
      let i, len, ref, specimen;
      if (el instanceof jQuery) {
        el = el[0];
      }
      ref = this.all;
      for (i = 0, len = ref.length; i < len; i++) {
        specimen = ref[i];
        if (specimen.el === el) {
          return specimen;
        }
      }
      return null;
    };

    Specimen.reset = function () {
      return this.all = [];
    };

    function Specimen (contents, info) {
      if (info == null) {
        info = {};
      }
      this.makeLabel = this.makeLabel.bind(this);
      this.el = contents instanceof jQuery ? contents[0] : contents;
      this.$contents = $(contents);
      this.name = info.name;
      this.path = info.path;
    }

    Specimen.prototype.remove = function () {
      let idx;
      idx = this.constructor.all.indexOf(this);
      if (idx !== -1) {
        return this.constructor.all.splice(idx, 1);
      }
    };

    Specimen.prototype.isVisible = function () {
      return this.$contents.length && this.$contents.is(':visible');
    };

    Specimen.prototype.makeBox = function () {
      this.bounds = util.computeBoundingBox(this.$contents);
      this.$box = $('<div class="xray-specimen">').css(this.bounds).attr('title', this.path);
      if (this.$contents.css('position') === 'fixed') {
        this.$box.css({
          position: 'fixed',
          top: this.$contents.css('top'),
          left: this.$contents.css('left')
        });
      }
      this.$box.click((( _this ) => {
        return () => {
          return Xray.open(_this.path);
        };
      })(this));
      return this.$box.append(this.makeLabel());
    };

    Specimen.prototype.makeLabel = function () {
      return $('<div class="xray-specimen-handle">').append(this.name);
    };

    return Specimen;
  })();

  Xray.Overlay = (function () {
    Overlay.instance = function () {
      return this.singletonInstance || (this.singletonInstance = new this);
    };

    function Overlay () {
      Xray.Overlay.singletonInstance = this;
      this.bar = new XrayBar('#xray-bar');
      this.settings = new Xray.Settings('#xray-settings');
      this.shownBoxes = [];
      this.$overlay = $('<div id="xray-overlay">');
      this.$overlay.click((() => {
        return () => { return this.hide(); };
      })());
    }

    Overlay.prototype.show = function (type) {
      if (type == null) {
        type = null;
      }
      this.reset();
      Xray.isShowing = true;
      let element, i, len, results, specimens;
      if (!this.$overlay.is(':visible')) {
        $('body').append(this.$overlay);
        this.bar.show();
      }

      Xray.findTemplates();
      specimens = Xray.Specimen.all;

      results = [];
      for (i = 0, len = specimens.length; i < len; i++) {
        element = specimens[i];
        if (!element.isVisible()) {
          continue;
        }
        element.makeBox();
        element.$box.css({
          zIndex: Math.ceil(MAX_ZINDEX * 0.9 + element.bounds.top + element.bounds.left)
        });
        this.shownBoxes.push(element.$box);
        results.push($('body').append(element.$box));
      }
      return results;
    };

    Overlay.prototype.reset = function () {
      let $box, i, len, ref;
      ref = this.shownBoxes;
      for (i = 0, len = ref.length; i < len; i++) {
        $box = ref[i];
        $box.remove();
      }
      return this.shownBoxes = [];
    };

    Overlay.prototype.hide = function () {
      Xray.isShowing = false;
      this.$overlay.detach();
      this.reset();
      return this.bar.hide();
    };

    return Overlay;

  })();

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
          if (path) Xray.open(path);
        });
      });

      const $settingsBtn = this.$el_memo.querySelector('.xray-bar-settings-btn');
      if ($settingsBtn) {
        $settingsBtn.addEventListener('click', () => Xray.toggleSettings());
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

  Xray.Settings = (function () {
    function Settings (el) {
      this.displayUpdateMsg = this.displayUpdateMsg.bind(this);
      this.save = this.save.bind(this);
      this.toggle = this.toggle.bind(this);
      this.el = el;
    }

    Settings.prototype.$el = function () {
      if ((this.$el_memo != null) && $.contains(window.document, this.$el_memo[0])) {
        return this.$el_memo;
      }
      this.$el_memo = $(this.el);
      this.$el_memo.find('form').submit(this.save);
      return this.$el_memo;
    };

    Settings.prototype.toggle = function () {
      return this.$el().toggle();
    };

    Settings.prototype.save = function (e) {
      let editor;
      e.preventDefault();
      editor = this.$el().find('#xray-editor-input').val();
      return $.ajax({
        url: '/_xray/config',
        type: 'POST',
        data: {
          editor: editor
        },
        success: (( _this ) => {
          return () => {
            return _this.displayUpdateMsg(true);
          };
        })(this),
        error: (( _this ) => {
          return () => {
            return _this.displayUpdateMsg(false);
          };
        })(this)
      });
    };

    Settings.prototype.displayUpdateMsg = function (success) {
      let $msg;
      if (success) {
        $msg = $('<span class=\'xray-settings-success xray-settings-update-msg\'>Success!</span>');
      } else {
        $msg = $('<span class=\'xray-settings-error xray-settings-update-msg\'>Uh oh, something went wrong!</span>');
      }
      this.$el().append($msg);
      return $msg.delay(2000).fadeOut(500, (( _this ) => {
        return () => {
          $msg.remove();
          return _this.toggle();
        };
      })(this));
    };

    return Settings;

  })();

  util = {
    computeBoundingBox: function ($contents) {
      if ($contents.length === 1 && $contents.height() <= 0) {
        return util.computeBoundingBox($contents.children());
      }
      const boxFrame = {
        top: Number.POSITIVE_INFINITY,
        left: Number.POSITIVE_INFINITY,
        right: Number.NEGATIVE_INFINITY,
        bottom: Number.NEGATIVE_INFINITY
      };

      const visibleElements = $contents.filter(':visible');
      for (let i = 0; i < visibleElements.length; i++) {
        const el = visibleElements[i];
        const $el = $(el);
        const frame = $el.offset();
        frame.right = frame.left + $el.outerWidth();
        frame.bottom = frame.top + $el.outerHeight();
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
  };
})();
