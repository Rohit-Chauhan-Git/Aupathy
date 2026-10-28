/// LNReader-compatible JavaScript runtime prelude.
///
/// Official LNReader plugin bundles are compiled CommonJS modules. The host
/// app provides the module table, web-platform primitives, and networking
/// bridge that the bundles expect. This prelude deliberately does not emulate
/// plugin results; every search result comes from the plugin's own code and a
/// real HTTP response.
const String lnReaderRuntimePrelude = r'''
(function () {
  if (globalThis.__lnreaderRuntimeInstalled) {
    return 'lnreader-runtime-already-installed';
  }
  globalThis.__lnreaderRuntimeInstalled = true;

  globalThis.__lnreaderErrorText = function (error) {
    if (!error) return 'Unknown error';
    if (typeof error === 'string') return error;
    var message = '';
    if (error.name) message += String(error.name);
    if (error.message) {
      message += (message ? ': ' : '') + String(error.message);
    }
    if (!message) {
      try {
        message = String(error);
      } catch (renderError) {
        message = '';
      }
    }
    if (error.stack) {
      var stack = String(error.stack);
      if (stack && stack.indexOf(message) === -1) {
        message += (message ? '\n' : '') + stack;
      }
    }
    return message || 'Unknown error';
  };

  if (typeof globalThis.URLSearchParams === 'undefined') {
    var URLSearchParamsPolyfill = function (init) {
      this._entries = [];
      if (typeof init === 'string') {
        var parts = init.replace(/^\?/, '').split('&');
        for (var i = 0; i < parts.length; i++) {
          if (!parts[i]) continue;
          var pair = parts[i].split('=');
          this._entries.push([
            decodeURIComponent(pair[0] || ''),
            decodeURIComponent(pair[1] || '')
          ]);
        }
      } else if (init && typeof init === 'object') {
        for (var key in init) {
          if (Object.prototype.hasOwnProperty.call(init, key)) {
            this._entries.push([String(key), String(init[key])]);
          }
        }
      }
    };
    URLSearchParamsPolyfill.prototype.append = function (key, value) {
      this._entries.push([String(key), String(value)]);
    };
    URLSearchParamsPolyfill.prototype.set = function (key, value) {
      var stringKey = String(key);
      for (var i = 0; i < this._entries.length; i++) {
        if (this._entries[i][0] === stringKey) {
          this._entries[i][1] = String(value);
          return;
        }
      }
      this.append(stringKey, value);
    };
    URLSearchParamsPolyfill.prototype.get = function (key) {
      var stringKey = String(key);
      for (var i = 0; i < this._entries.length; i++) {
        if (this._entries[i][0] === stringKey) return this._entries[i][1];
      }
      return null;
    };
    URLSearchParamsPolyfill.prototype.getAll = function (key) {
      var stringKey = String(key);
      var values = [];
      for (var i = 0; i < this._entries.length; i++) {
        if (this._entries[i][0] === stringKey) values.push(this._entries[i][1]);
      }
      return values;
    };
    URLSearchParamsPolyfill.prototype.toString = function () {
      return this._entries.map(function (entry) {
        return encodeURIComponent(entry[0]) + '=' + encodeURIComponent(entry[1]);
      }).join('&');
    };
    globalThis.URLSearchParams = URLSearchParamsPolyfill;
  }

  if (typeof globalThis.TextEncoder === 'undefined') {
    var TextEncoderPolyfill = function () {};
    TextEncoderPolyfill.prototype.encode = function (value) {
      var text = String(value);
      var bytes = [];
      for (var i = 0; i < text.length; i++) {
        var code = text.charCodeAt(i);
        if (code < 0x80) {
          bytes.push(code);
        } else if (code < 0x800) {
          bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
        } else if (code < 0xd800 || code >= 0xe000) {
          bytes.push(
            0xe0 | (code >> 12),
            0x80 | ((code >> 6) & 0x3f),
            0x80 | (code & 0x3f)
          );
        } else {
          var next = text.charCodeAt(i + 1) || 0;
          var point = 0x10000 + ((code & 0x3ff) << 10) + (next & 0x3ff);
          i++;
          bytes.push(
            0xf0 | (point >> 18),
            0x80 | ((point >> 12) & 0x3f),
            0x80 | ((point >> 6) & 0x3f),
            0x80 | (point & 0x3f)
          );
        }
      }
      return new Uint8Array(bytes);
    };
    globalThis.TextEncoder = TextEncoderPolyfill;
  }

  var Headers = function (init) {
    this._values = {};
    if (init) {
      if (Array.isArray(init)) {
        for (var i = 0; i < init.length; i++) {
          this.append(init[i][0], init[i][1]);
        }
      } else if (typeof init.forEach === 'function') {
        var self = this;
        init.forEach(function (value, key) {
          self.append(key, value);
        });
      } else {
        for (var key in init) {
          if (Object.prototype.hasOwnProperty.call(init, key)) {
            this.append(key, init[key]);
          }
        }
      }
    }
  };
  Headers.prototype.append = function (key, value) {
    var normalized = String(key).toLowerCase();
    var stringValue = String(value);
    if (this._values[normalized] === undefined) {
      this._values[normalized] = stringValue;
    } else {
      this._values[normalized] += ', ' + stringValue;
    }
  };
  Headers.prototype.set = function (key, value) {
    this._values[String(key).toLowerCase()] = String(value);
  };
  Headers.prototype.get = function (key) {
    var value = this._values[String(key).toLowerCase()];
    return value === undefined ? null : value;
  };
  Headers.prototype.has = function (key) {
    return this._values[String(key).toLowerCase()] !== undefined;
  };
  Headers.prototype.forEach = function (callback, thisArg) {
    for (var key in this._values) {
      if (Object.prototype.hasOwnProperty.call(this._values, key)) {
        callback.call(thisArg, this._values[key], key, this);
      }
    }
  };
  Headers.prototype.entries = function () {
    var entries = [];
    this.forEach(function (value, key) {
      entries.push([key, value]);
    });
    return entries;
  };
  globalThis.Headers = Headers;

  function textBytes(value) {
    return new globalThis.TextEncoder().encode(String(value));
  }

  function makeBlob(body, type) {
    return {
      type: type || 'text/plain',
      size: String(body).length,
      text: function () {
        return Promise.resolve(String(body));
      },
      arrayBuffer: function () {
        return Promise.resolve(textBytes(body).buffer);
      }
    };
  }

  function makeResponse(data) {
    var body = typeof data.body === 'string' ? data.body : '';
    var headers = new Headers(data.headers || {});
    var status = Number(data.status || 0);
    return {
      ok: status >= 200 && status < 300,
      status: status,
      statusText: data.statusText || '',
      url: data.url || '',
      redirected: !!data.redirected,
      headers: headers,
      text: function () {
        return Promise.resolve(body);
      },
      json: function () {
        return Promise.resolve(body).then(function (text) {
          return JSON.parse(text);
        });
      },
      arrayBuffer: function () {
        return Promise.resolve(textBytes(body).buffer);
      },
      blob: function () {
        return Promise.resolve(
          makeBlob(body, headers.get('content-type') || 'text/plain')
        );
      },
      clone: function () {
        return makeResponse(data);
      }
    };
  }

  globalThis.fetch = function (input, init) {
    var url = typeof input === 'string'
      ? input
      : (input && input.url ? input.url : String(input));
    init = init || {};
    var headers = {};
    if (init.headers) {
      if (typeof init.headers.forEach === 'function') {
        init.headers.forEach(function (value, key) {
          headers[key] = value;
        });
      } else if (Array.isArray(init.headers)) {
        for (var i = 0; i < init.headers.length; i++) {
          headers[init.headers[i][0]] = init.headers[i][1];
        }
      } else {
        for (var key in init.headers) {
          if (Object.prototype.hasOwnProperty.call(init.headers, key)) {
            headers[key] = init.headers[key];
          }
        }
      }
    }
    var body = init.body;
    if (body !== undefined && body !== null) body = String(body);
    return sendMessage(
      'LnReaderHttp',
      JSON.stringify({
        url: String(url),
        method: String(init.method || 'GET').toUpperCase(),
        headers: headers,
        body: body === undefined ? null : body
      })
    ).then(makeResponse);
  };

  var defaultHeaders = {
    'Connection': 'keep-alive',
    'Accept': '*/*',
    'Accept-Language': '*',
    'Sec-Fetch-Mode': 'cors',
    'Accept-Encoding': 'gzip, deflate',
    'Cache-Control': 'max-age=0',
    'User-Agent':
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 ' +
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36'
  };

  function makeFetchInit(init) {
    init = init || {};
    if (init.headers) {
      if (typeof init.headers.forEach === 'function') {
        if (!init.headers.get('User-Agent')) {
          init.headers.set('User-Agent', defaultHeaders['User-Agent']);
        }
      } else {
        init.headers = Object.assign({}, defaultHeaders, init.headers);
      }
    } else {
      init.headers = Object.assign({}, defaultHeaders);
    }
    return init;
  }

  function fetchApi(url, init) {
    return globalThis.fetch(url, makeFetchInit(init));
  }

  function fetchText(url, init) {
    return fetchApi(url, init).then(function (response) {
      if (!response.ok) throw new Error('HTTP ' + response.status);
      return response.text();
    }).catch(function () {
      return '';
    });
  }

  function fetchJson(url, init) {
    return fetchApi(url, init).then(function (response) {
      if (!response.ok) throw new Error('HTTP ' + response.status);
      return response.json();
    });
  }

  var storageValues = {};
  var Storage = function (pluginId) {
    this.pluginId = pluginId;
  };
  Storage.prototype.set = function (key, value, expires) {
    storageValues[this.pluginId + '::' + key] = {
      created: new Date(),
      value: value,
      expires: expires instanceof Date ? expires.getTime() : expires
    };
  };
  Storage.prototype.get = function (key, raw) {
    var item = storageValues[this.pluginId + '::' + key];
    if (!item) return undefined;
    if (item.expires && Date.now() > item.expires) {
      delete storageValues[this.pluginId + '::' + key];
      return undefined;
    }
    return raw ? item : item.value;
  };
  Storage.prototype.delete = function (key) {
    delete storageValues[this.pluginId + '::' + key];
  };
  Storage.prototype.clearAll = function () {
    var prefix = this.pluginId + '::';
    for (var key in storageValues) {
      if (key.indexOf(prefix) === 0) delete storageValues[key];
    }
  };

  var voidElements = {
    area: true, base: true, br: true, col: true, embed: true, hr: true,
    img: true, input: true, link: true, meta: true, param: true,
    source: true, track: true, wbr: true
  };

  var entityMap = {
    amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: '\u00a0',
    copy: '\u00a9', reg: '\u00ae', hellip: '\u2026', mdash: '\u2014',
    ndash: '\u2013', rsquo: '\u2019', lsquo: '\u2018', rdquo: '\u201d',
    ldquo: '\u201c'
  };

  function decodeEntities(value) {
    return String(value).replace(
      /&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g,
      function (match, entity) {
        if (entity.charAt(0) === '#') {
          var code;
          if (entity.charAt(1).toLowerCase() === 'x') {
            code = parseInt(entity.slice(2), 16);
          } else {
            code = parseInt(entity.slice(1), 10);
          }
          if (isNaN(code)) return match;
          try {
            return String.fromCodePoint(code);
          } catch (error) {
            return match;
          }
        }
        return Object.prototype.hasOwnProperty.call(entityMap, entity)
          ? entityMap[entity]
          : match;
      }
    );
  }

  function parseAttributes(text) {
    var attributes = {};
    var i = 0;
    while (i < text.length) {
      while (i < text.length && /\s/.test(text.charAt(i))) i++;
      if (i >= text.length || text.charAt(i) === '/') break;
      var nameStart = i;
      while (i < text.length && !/[\s=/>]/.test(text.charAt(i))) i++;
      var name = text.slice(nameStart, i).toLowerCase();
      while (i < text.length && /\s/.test(text.charAt(i))) i++;
      var value = '';
      if (text.charAt(i) === '=') {
        i++;
        while (i < text.length && /\s/.test(text.charAt(i))) i++;
        var quote = text.charAt(i);
        if (quote === '"' || quote === "'") {
          i++;
          var valueStart = i;
          while (i < text.length && text.charAt(i) !== quote) i++;
          value = text.slice(valueStart, i);
          i++;
        } else {
          var unquotedStart = i;
          while (i < text.length && !/[\s/>]/.test(text.charAt(i))) i++;
          value = text.slice(unquotedStart, i);
        }
      }
      if (name) attributes[name] = decodeEntities(value);
    }
    return attributes;
  }

  var HtmlParser = function (handler) {
    this.handler = handler || {};
    this._buffer = '';
  };
  HtmlParser.prototype.write = function (chunk) {
    this._buffer += chunk === undefined || chunk === null ? '' : String(chunk);
    this._parse(false);
    return this;
  };
  HtmlParser.prototype.end = function (chunk) {
    if (chunk !== undefined && chunk !== null) this._buffer += String(chunk);
    this._parse(true);
    if (this.handler.onend) this.handler.onend();
    return this;
  };
  HtmlParser.prototype._open = function (name, attributes) {
    if (this.handler.onopentag) this.handler.onopentag(name, attributes);
  };
  HtmlParser.prototype._close = function (name) {
    if (this.handler.onclosetag) this.handler.onclosetag(name);
  };
  HtmlParser.prototype._text = function (text) {
    if (text && this.handler.ontext) this.handler.ontext(decodeEntities(text));
  };
  HtmlParser.prototype._parse = function (final) {
    var html = this._buffer;
    var i = 0;
    while (i < html.length) {
      var lt = html.indexOf('<', i);
      if (lt === -1) {
        if (final) {
          this._text(html.slice(i));
          i = html.length;
        }
        break;
      }
      if (lt > i) this._text(html.slice(i, lt));
      if (html.indexOf('<!--', lt) === lt) {
        var commentEnd = html.indexOf('-->', lt + 4);
        if (commentEnd < 0) {
          if (!final) break;
          i = html.length;
          break;
        }
        i = commentEnd + 3;
        continue;
      }
      if (html.indexOf('<![CDATA[', lt) === lt) {
        var cdataEnd = html.indexOf(']]>', lt + 9);
        if (cdataEnd < 0) {
          if (!final) break;
          i = html.length;
          break;
        }
        this._text(html.slice(lt + 9, cdataEnd));
        i = cdataEnd + 3;
        continue;
      }
      var next = html.charAt(lt + 1);
      if (next === '!' || next === '?') {
        var declarationEnd = html.indexOf('>', lt + 2);
        if (declarationEnd < 0) {
          if (!final) break;
          i = html.length;
          break;
        }
        i = declarationEnd + 1;
        continue;
      }

      var closing = next === '/';
      var nameStart = lt + (closing ? 2 : 1);
      var nameEnd = nameStart;
      while (
        nameEnd < html.length &&
        !/[\s/>]/.test(html.charAt(nameEnd))
      ) {
        nameEnd++;
      }
      if (nameEnd >= html.length) {
        if (!final) break;
        this._text(html.slice(lt));
        i = html.length;
        break;
      }
      var tagName = html.slice(nameStart, nameEnd).toLowerCase();
      if (closing) {
        var closeEnd = html.indexOf('>', nameEnd);
        if (closeEnd < 0) {
          if (!final) break;
          i = html.length;
          break;
        }
        this._close(tagName);
        i = closeEnd + 1;
        continue;
      }

      var quote = null;
      var tagEnd = -1;
      for (var cursor = nameEnd; cursor < html.length; cursor++) {
        var character = html.charAt(cursor);
        if (quote) {
          if (character === quote) quote = null;
        } else if (character === '"' || character === "'") {
          quote = character;
        } else if (character === '>') {
          tagEnd = cursor;
          break;
        }
      }
      if (tagEnd < 0) {
        if (!final) break;
        this._text(html.slice(lt));
        i = html.length;
        break;
      }

      var attributeText = html.slice(nameEnd, tagEnd);
      var attributes = parseAttributes(attributeText);
      var selfClosing = /\/\s*$/.test(attributeText);
      this._open(tagName, attributes);
      if (selfClosing || voidElements[tagName]) {
        this._close(tagName);
        i = tagEnd + 1;
        continue;
      }

      if (tagName === 'script' || tagName === 'style') {
        var closingStart = html.toLowerCase().indexOf(
          '</' + tagName,
          tagEnd + 1
        );
        if (closingStart < 0) {
          if (!final) break;
          this._text(html.slice(tagEnd + 1));
          i = html.length;
          break;
        }
        this._text(html.slice(tagEnd + 1, closingStart));
        var rawCloseEnd = html.indexOf('>', closingStart);
        if (rawCloseEnd < 0) {
          if (!final) break;
          i = html.length;
          break;
        }
        this._close(tagName);
        i = rawCloseEnd + 1;
        continue;
      }

      i = tagEnd + 1;
    }
    this._buffer = i >= html.length ? '' : html.slice(i);
  };

  var novelStatus = {
    Unknown: 'Unknown',
    Ongoing: 'Ongoing',
    Completed: 'Completed',
    Licensed: 'Licensed',
    PublishingFinished: 'Publishing Finished',
    Cancelled: 'Cancelled',
    OnHiatus: 'On Hiatus',
    STUB: 'STUB',
    Inactive: 'Inactive'
  };

  var filterTypes = {
    TextInput: 'Text',
    Picker: 'Picker',
    CheckboxGroup: 'Checkbox',
    Switch: 'Switch',
    ExcludableCheckboxGroup: 'XCheckbox'
  };

  function isUrlAbsolute(url) {
    if (!url) return false;
    if (url.indexOf('//') === 0) return true;
    if (url.indexOf('://') === -1) return false;
    if (url.indexOf('.') === -1) return false;
    if (url.indexOf('/') === -1) return false;
    if (url.indexOf(':') > url.indexOf('/')) return false;
    if (url.indexOf('://') < url.indexOf('.')) return true;
    return false;
  }

  var modules = {
    'htmlparser2': { Parser: HtmlParser },
    '@libs/fetch': {
      fetchApi: fetchApi,
      fetchText: fetchText,
      fetchJson: fetchJson
    },
    '@libs/isAbsoluteUrl': { isUrlAbsolute: isUrlAbsolute },
    '@libs/filterInputs': { FilterTypes: filterTypes },
    '@libs/novelStatus': { NovelStatus: novelStatus },
    '@libs/defaultCover': { defaultCover: '' }
  };

  globalThis.__lnreaderMissingModules = [];
  globalThis.__lnreaderRequire = function (name) {
    if (name === '@libs/storage') {
      return {
        storage: new Storage(globalThis.__lnreaderPluginId || ''),
        localStorage: new Storage(globalThis.__lnreaderPluginId || ''),
        sessionStorage: new Storage(globalThis.__lnreaderPluginId || '')
      };
    }
    if (Object.prototype.hasOwnProperty.call(modules, name)) {
      return modules[name];
    }
    globalThis.__lnreaderMissingModules.push(name);
    throw new Error('LNREADER_MISSING_MODULE:' + name);
  };

  globalThis.__lnreaderLoadPlugin = function (source) {
    var module = { exports: {} };
    try {
      var factory = new Function(
        'require',
        'module',
        'const exports = module.exports = {};\n' + source +
          '\n;return exports.default;'
      );
      var exported = factory(globalThis.__lnreaderRequire, module);
      var candidate = exported ||
        (module.exports ? (module.exports.default || module.exports) : null);
      globalThis.__lnreaderPlugin = candidate || null;
      var methods = {};
      var methodNames = [
        'searchNovels',
        'parseNovel',
        'parseChapter',
        'popularNovels'
      ];
      for (var i = 0; i < methodNames.length; i++) {
        var methodName = methodNames[i];
        methods[methodName] = candidate
          ? typeof candidate[methodName]
          : 'missing';
      }
      return JSON.stringify({
        ok: true,
        keys: Object.keys(module.exports || {}),
        methods: methods,
        id: candidate ? candidate.id : null,
        name: candidate ? candidate.name : null,
        site: candidate ? candidate.site : null,
        version: candidate ? candidate.version : null,
        hasCandidate: !!candidate,
        missingModules: globalThis.__lnreaderMissingModules.slice(0)
      });
    } catch (error) {
      globalThis.__lnreaderPlugin = null;
      return JSON.stringify({
        ok: false,
        error: globalThis.__lnreaderErrorText(error),
        missingModules: globalThis.__lnreaderMissingModules.slice(0)
      });
    }
  };

  return 'lnreader-runtime-ready';
})();
''';
