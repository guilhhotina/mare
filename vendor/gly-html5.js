(function(){function r(e,n,t){function o(i,f){if(!n[i]){if(!e[i]){var c="function"==typeof require&&require;if(!f&&c)return c(i,!0);if(u)return u(i,!0);var a=new Error("Cannot find module '"+i+"'");throw a.code="MODULE_NOT_FOUND",a}var p=n[i]={exports:{}};e[i][0].call(p.exports,function(r){var n=e[i][1][r];return o(n||r)},p,p.exports,r,e,n,t)}return n[i].exports}for(var u="function"==typeof require&&require,i=0;i<t.length;i++)o(t[i]);return o}return r})()({1:[function(require,module,exports){
"use strict";

function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: !0, configurable: !0, writable: !0 }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == typeof i ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != typeof t || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r || "default"); if ("object" != typeof i) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }

function is_paused(pause_reasons) {
  for (var key in pause_reasons) {
    if (pause_reasons[key]) return true;
  }
  return false;
}
function _pause(pause_reasons) {
  let motive = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : "pause";
  pause_reasons[motive] = true;
}
function _resume(pause_reasons, motive) {
  if (motive && motive.length > 0) {
    pause_reasons[motive] = false;
    return;
  }
  for (var key in pause_reasons) {
    pause_reasons[key] = false;
  }
}
function unpaused_call(pause_reasons, fn) {
  let checkPaused;
  return function () {
    for (var _len = arguments.length, args = new Array(_len), _key = 0; _key < _len; _key++) {
      args[_key] = arguments[_key];
    }
    clearInterval(checkPaused);
    if (!is_paused(pause_reasons)) {
      fn(...args);
    } else {
      checkPaused = setInterval(() => {
        if (!is_paused(pause_reasons)) {
          fn(...args);
          clearInterval(checkPaused);
        }
      }, 100);
    }
  };
}


async function create_engine(hv, canvas, ctx, shutdown) {
  const methods = () => ({
    frontend: hv.frontend,
    backend: hv.backend,
    pause: motive => {
      _pause(hv.pause_reasons, motive);
      return methods();
    },
    resume: motive => {
      _resume(hv.pause_reasons, motive);
      return methods();
    },
    paused: () => {
      return is_paused(hv.pause_reasons);
    },
    getImageData: () => {
      return ctx.getImageData(0, 0, canvas.width, canvas.height);
    },
    stroke: size => {
      ctx.lineWidth = size;
      return methods();
    },
    on: (key, func) => {
      hv.frontbus.on(key, func);
      return methods();
    },
    destroy: async () => {
      hv.backend.native_image_clear_all();
      hv.frontbus.shutdown();
      await shutdown();
    }
  });
  return methods();
}


class EventEmitter {
  constructor() {
    _defineProperty(this, "events", {});
  }
  on(event, listener) {
    if (!this.events[event]) {
      this.events[event] = [];
    }
    this.events[event].push(listener);
  }
  shutdown() {
    this.events = {};
  }
  off(event, listener) {
    if (!this.events[event]) return;
    const index = this.events[event].indexOf(listener);
    if (index !== -1) {
      this.events[event].splice(index, 1);
    }
  }
  emit(event) {
    for (var _len2 = arguments.length, args = new Array(_len2 > 1 ? _len2 - 1 : 0), _key2 = 1; _key2 < _len2; _key2++) {
      args[_key2 - 1] = arguments[_key2];
    }
    if (!this.events[event]) return;
    this.events[event].forEach(listener => listener(...args));
  }
}
function create_code(name, src) {
  return async () => {
    if (!src || src.length == 0) {
      throw new Error("missing code: ".concat(name));
    }
    if (!src.includes("\n")) {
      const response = await fetch(src);
      if (!response.ok) {
        throw new Error("".concat(response.status, " code: ").concat(name));
      }
      return await response.text();
    }
    return src.replace(/\0/g, "");
  };
}
function create_emiter() {
  return new EventEmitter();
}
async function create_frontend(bus, code, canvas, pause_reasons) {
  const cfg = {
    init: false
  };
  if (typeof code.game == "function") {
    code.game = await code.game();
  }
  const bus_emit_resize = unpaused_call(pause_reasons, (width, height) => {
    bus.emit("resize", width, height);
  });
  return {
    native_callback_loop: function native_callback_loop() {
      let dt = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : 16;
      if (!is_paused(pause_reasons)) {
        bus.emit("pad");
        bus.emit("loop", dt);
      }
    },
    native_callback_draw: () => {
      if (!is_paused(pause_reasons)) {
        bus.emit("draw");
      }
    },
    native_callback_init: (width, height) => {
      if (!width || !height) {
        width = canvas.width;
        height = canvas.height;
      }
      if (!is_paused(pause_reasons)) {
        bus.emit("init", width, height, code.game);
      }
      cfg.init = true;
    },
    native_callback_resize: (width, height) => {
      canvas.width = width;
      canvas.height = height;
      if (cfg.init) {
        bus_emit_resize(width, height);
      }
    },
    native_callback_keyboard: (key, value) => {
      if (!is_paused(pause_reasons)) {
        bus.emit("keyboard", key, value);
      }
    }
  };
}


function hexToColor(color) {
  const r = color >>> 24 & 255;
  const g = color >>> 16 & 255;
  const b = color >>> 8 & 255;
  const a = (color & 255) / 255;
  return "rgba(" + r + "," + g + "," + b + "," + a.toFixed(3) + ")";
}
function _native_draw_start(render) {
  render.ctx.clearRect(0, 0, render.canvas.width, render.canvas.height);
}
function _native_draw_flush(render) {}
function _native_draw_clear(render, color, x, y, w, h) {
  render.ctx.fillStyle = hexToColor(color);
  render.ctx.fillRect(x !== null && x !== void 0 ? x : 0, y !== null && y !== void 0 ? y : 0, w !== null && w !== void 0 ? w : render.canvas.width, h !== null && h !== void 0 ? h : render.canvas.height);
}
function _native_draw_color(render, color) {
  const fillstyle = hexToColor(color);
  render.ctx.strokeStyle = fillstyle;
  render.ctx.fillStyle = fillstyle;
}
function _native_draw_line(render, x1, y1, x2, y2) {
  render.ctx.beginPath();
  render.ctx.moveTo(x1, y1);
  render.ctx.lineTo(x2, y2);
  render.ctx.stroke();
}
function _native_draw_rect(render, mode, x, y, w, h) {
  if (mode == 1) {
    render.ctx.strokeRect(x, y, w, h);
  } else {
    render.ctx.fillRect(x, y, w, h);
  }
}
function _native_draw_rect2(render, mode, x, y, w, h, r) {
  if (!r) {
    return _native_draw_rect(render, mode, x, y, w, h);
  }
  const ctx = render.ctx;
  const radius = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + w - radius, y);
  ctx.arc(x + w - radius, y + radius, radius, 1.5 * Math.PI, 0);
  ctx.lineTo(x + w, y + h - radius);
  ctx.arc(x + w - radius, y + h - radius, radius, 0, 0.5 * Math.PI);
  ctx.lineTo(x + radius, y + h);
  ctx.arc(x + radius, y + h - radius, radius, 0.5 * Math.PI, Math.PI);
  ctx.lineTo(x, y + radius);
  ctx.arc(x + radius, y + radius, radius, Math.PI, 1.5 * Math.PI);
  ctx.closePath();
  if (mode === 1) {
    ctx.stroke();
  } else {
    ctx.fill();
  }
}
function _native_draw_poly(render, mode, verts, x, y, scale, angle, ox, oy) {
  let index = 0;
  render.ctx.beginPath();
  while (index < verts.length) {
    const px = verts[index];
    const py = verts[index + 1];
    const xx = x + (ox - px) * -scale * Math.cos(angle) - (oy - py) * -scale * Math.sin(angle);
    const yy = y + (oy - px) * -scale * Math.sin(angle) + (ox - py) * -scale * Math.cos(angle);
    if (index < 2) {
      render.ctx.moveTo(xx, yy);
    } else {
      render.ctx.lineTo(xx, yy);
    }
    index += 2;
  }
  [() => render.ctx.fill(), () => {
    render.ctx.closePath();
    render.ctx.stroke();
  }, () => render.ctx.stroke()][mode]();
}


function _native_http_handler(self) {
  const method = self.method;
  const headers = new Headers(self.header_dict);
  const params = new URLSearchParams(self.param_dict);
  const url = params.toString() ? "".concat(self.url, "?").concat(params.toString()) : self.url;
  const body = ["HEAD", "GET"].includes(method) ? null : self.body_content;
  self.promise();
  fetch(url, {
    body,
    method,
    headers
  }).then(response => {
    self.set("ok", response.ok);
    self.set("status", response.status);
    return response.text();
  }).then(content => {
    self.set("body", content);
    self.resolve();
  }).catch(error => {
    self.set("ok", false);
    self.set("error", "".concat(error));
    self.resolve();
  });
}


function preload_image(src) {
  return document.querySelector("img[src=\"".concat(src, "\"]"));
}
async function load_image(src) {
  return new Promise((resolve, reject) => {
    const el = document.createElement("img");
    el.src = src;
    const failed = ev => {
      resolve(null);
      console.error("[core:html5] image src \"".concat(src, "\" ").concat(typeof ev === "string" ? ev : ev.type));
    };
    el.onerror = failed;
    el.onabort = failed;
    el.onload = () => resolve(el);
  });
}
function get_image_from_id(cache, id) {
  if (id) {
    const el = cache.data[id];
    if (el === null) {
      return;
    }
    if (el === undefined) {
      throw new Error("[core:html5] image id ".concat(id, " not exist!"));
    }
    return el;
  }
  return;
}
function _native_image_load(render, cache, src, url) {
  const id = cache.name[src];
  if (id) {
    return cache.data[id] ? id : undefined;
  }
  const el_preloaded = preload_image(src);
  if (el_preloaded) {
    const new_id2 = ++cache.count;
    cache.name[src] = new_id2;
    cache.data[new_id2] = el_preloaded;
    return new_id2;
  }
  const new_id = ++cache.count;
  cache.name[src] = new_id;
  load_image(src).then(el => cache.data[new_id] = el);
  return;
}
function _native_image_draw(render, cache, src, x, y) {
  const id = typeof src == "string" ? _native_image_load(render, cache, src) : src;
  const el = get_image_from_id(cache, id);
  if (el) {
    render.ctx.drawImage(el, x, y);
  }
}
function _native_image_mensure(render, cache, src) {
  const id = typeof src == "string" ? _native_image_load(render, cache, src) : src;
  const el = get_image_from_id(cache, id);
  if (el) {
    return [el.width, el.height];
  }
  return [0, 0];
}
function _native_image_unload(cache, src) {
  const clear_by_name = src2 => {
    do {
      const id = cache.name[src2];
      if (!id) break;
      delete cache.name[src2];
      if (!cache.data[id]) break;
      delete cache.data[id];
    } while (0);
  };
  if (typeof src == "number") {
    var _Object$entries$find$, _Object$entries$find;
    const name = (_Object$entries$find$ = (_Object$entries$find = Object.entries(cache.name).find(_ref => {
      let [_, id] = _ref;
      return id == src;
    })) === null || _Object$entries$find === void 0 ? void 0 : _Object$entries$find[0]) !== null && _Object$entries$find$ !== void 0 ? _Object$entries$find$ : "";
    return clear_by_name(name);
  }
  return clear_by_name(src);
}
function _native_image_unload_all(cache) {
  cache.count = 0;
  cache.data = [];
  cache.name = {};
}


function _native_media_bootstrap(media, mediatype) {
  const has_support = media.players.map(player => player.can(mediatype, "", 1)).some(score => score !== 0);
  media.devices.push(mediatype);
  media.mixer[media.devices.length - 1] = null;
  return has_support ? 1 : 0;
}
function _native_media_source(media, channel, url) {
  var _media$mixer$channel;
  const type = media.devices[channel];
  const players = media.players.length;
  const best = media.players.map((player, index) => {
    const is_current = player == media.current[channel];
    const score = player.can(type, url, is_current ? 20 : players - index);
    return {
      player,
      score
    };
  }).reduce((max, current) => {
    return current.score > max.score ? current : max;
  });
  if (media.mixer[channel] && (best.score <= 10 || best.player !== media.current[channel])) {
    media.mixer[channel].destroy();
    media.mixer[channel] = null;
  }
  if (!media.mixer[channel] && best.score > 10) {
    media.mixer[channel] = best.player.init(type, channel);
    media.current[channel] = best.player;
  }
  if (!media.mixer[channel]) {
    console.error("unsupported media: channel ".concat(channel, " type ").concat(type, "\n").concat(url));
  }
  (_media$mixer$channel = media.mixer[channel]) === null || _media$mixer$channel === void 0 || _media$mixer$channel.source(url);
}
function _native_media_position(media, channel, x, y, w, h) {
  var _media$mixer$channel2;
  (_media$mixer$channel2 = media.mixer[channel]) === null || _media$mixer$channel2 === void 0 || _media$mixer$channel2.position(x, y, w, h);
}
function _native_media_play(media, channel) {
  var _media$mixer$channel3;
  (_media$mixer$channel3 = media.mixer[channel]) === null || _media$mixer$channel3 === void 0 || _media$mixer$channel3.play();
}
function _native_media_resume(media, channel) {
  var _media$mixer$channel4;
  (_media$mixer$channel4 = media.mixer[channel]) === null || _media$mixer$channel4 === void 0 || _media$mixer$channel4.resume();
}
function _native_media_pause(media, channel) {
  var _media$mixer$channel5;
  (_media$mixer$channel5 = media.mixer[channel]) === null || _media$mixer$channel5 === void 0 || _media$mixer$channel5.pause();
}
function _native_media_stop(media, channel) {
  var _media$mixer$channel6;
  (_media$mixer$channel6 = media.mixer[channel]) === null || _media$mixer$channel6 === void 0 || _media$mixer$channel6.destroy();
  media.mixer[channel] = null;
}
function _native_media_time(media, channel, time) {
  var _media$mixer$channel7;
  (_media$mixer$channel7 = media.mixer[channel]) === null || _media$mixer$channel7 === void 0 || _media$mixer$channel7.set_time(time);
}


function font_apply_if_changes(render, font) {
  if (font.name != font.old.name || font.size != font.old.size) {
    render.ctx.font = "".concat(font.size, "px ").concat(font.name);
    render.ctx.textBaseline = "top";
    render.ctx.textAlign = "left";
  }
}
function _native_text_font_name(render, font, name) {
  font.name = name;
}
function _native_text_font_size(render, font, size) {
  font.size = Math.floor(size);
}
function _native_text_font_default(render, font, id) {
  font.name = "sans";
}
function _native_text_font_previous(render, font) {
  const [name, size] = [font.name, font.size];
  font.name = font.old.name;
  font.size = font.old.size;
  font.old.name = name;
  font.old.size = size;
}
function _native_text_print(render, font, x, y, text) {
  font_apply_if_changes(render, font);
  render.ctx.fillText(text, x, y);
}
function _native_text_mensure(render, font, text) {
  font_apply_if_changes(render, font);
  const {
    width,
    actualBoundingBoxAscent,
    actualBoundingBoxDescent
  } = render.ctx.measureText(text);
  return [width, actualBoundingBoxAscent + actualBoundingBoxDescent];
}


function _native_system_get_language() {
  return navigator.language;
}
function _native_system_get_env(var_name) {
  const hash = location.hash.substring(1);
  const params = new URLSearchParams(hash);
  return params.get(var_name);
}


function create_canvas(canvas) {
  if (typeof canvas == "object") {
    return canvas;
  }
  if (typeof canvas == "string") {
    const el = document.querySelector(canvas);
    if (!el) {
      throw new Error("element dont exist: ".concat(canvas));
    }
    return el;
  }
  return document.createElement("canvas");
}
function create_backend(canvas, ctx, players) {
  const render = {
    canvas,
    ctx
  };
  const text_cache = {
    name: "sans",
    size: 5,
    old: {
      name: "sans",
      size: 8
    }
  };
  const image_cache = {};
  const media_cache = {
    devices: [],
    current: [],
    mixer: {},
    players
  };
  media_cache.players.push({
    can: () => 0
  });
  _native_image_unload_all(image_cache);
  return {
    native_http_handler: self => _native_http_handler(self),
    native_draw_start: () => _native_draw_start(render),
    native_draw_flush: () => _native_draw_flush(render),
    native_draw_color: color => _native_draw_color(render, color),
    native_draw_clear: (color, x, y, w, h) => _native_draw_clear(render, color, x, y, w, h),
    native_draw_rect: (mode, x, y, w, h) => _native_draw_rect(render, mode, x, y, w, h),
    native_draw_rect2: (mode, x, y, w, h, r) => _native_draw_rect2(render, mode, x, y, w, h, r),
    native_draw_line: (x1, y1, x2, y2) => _native_draw_line(render, x1, y1, x2, y2),
    native_draw_poly2: (mode, verts, x, y, scale, angle, ox, oy) => _native_draw_poly(render, mode, verts, x, y, scale, angle, ox, oy),
    native_text_font_name: name => _native_text_font_name(render, text_cache, name),
    native_text_font_default: id => _native_text_font_default(render, text_cache, id),
    native_text_font_size: size => _native_text_font_size(render, text_cache, size),
    native_text_font_previous: size => _native_text_font_previous(render, text_cache),
    native_text_print: (x, y, text) => _native_text_print(render, text_cache, x, y, text),
    native_text_mensure: text => _native_text_mensure(render, text_cache, text),
    native_image_load: (src, url) => _native_image_load(render, image_cache, src, url),
    native_image_draw: (src, x, y) => _native_image_draw(render, image_cache, src, x, y),
    native_image_mensure: text => _native_image_mensure(render, image_cache, text),
    native_image_unload: (src, url) => _native_image_unload(image_cache, src),
    native_image_unload_all: () => _native_image_unload_all(image_cache),
    native_system_get_language: () => _native_system_get_language(),
    native_system_get_env: var_name => _native_system_get_env(var_name),
    native_media_bootstrap: mediatype => _native_media_bootstrap(media_cache, mediatype),
    native_media_source: (channel, url) => _native_media_source(media_cache, channel, url),
    native_media_position: (channel, x, y, w, h) => _native_media_position(media_cache, channel, x, y, w, h),
    native_media_resume: channel => _native_media_resume(media_cache, channel),
    native_media_play: channel => _native_media_play(media_cache, channel),
    native_media_stop: channel => _native_media_stop(media_cache, channel),
    native_media_pause: channel => _native_media_pause(media_cache, channel),
    native_media_time: (channel, time) => _native_media_time(media_cache, channel, time),
    native_log_debug: txt => console.log(txt),
    native_log_trace: txt => console.info(txt),
    native_log_info: txt => console.info(txt),
    native_log_warn: txt => console.warn(txt),
    native_log_error: txt => console.error(txt),
    native_log_fatal: txt => console.error(txt),
    native_draw_poly: function native_draw_poly(mode, verts) {
      let x = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : 0;
      let y = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : 0;
      let scale = arguments.length > 4 && arguments[4] !== undefined ? arguments[4] : 1;
      let angle = arguments.length > 5 && arguments[5] !== undefined ? arguments[5] : 0;
      let ox = arguments.length > 6 && arguments[6] !== undefined ? arguments[6] : 0;
      let oy = arguments.length > 7 && arguments[7] !== undefined ? arguments[7] : 0;
      return _native_draw_poly(render, mode, verts, x, y, scale, angle, ox, oy);
    },
    native_draw_image: (src, x, y) => _native_image_draw(render, image_cache, src, x, y),
    native_draw_text: (x, y, text) => {
      typeof x == "number" && (text || text == 0) && _native_text_print(render, text_cache, x, y, "".concat(text));
      return _native_text_mensure(render, text_cache, "".concat(text !== null && text !== void 0 ? text : x));
    },
    native_draw_font: (name, size) => {
      _native_text_font_name(render, text_cache, name);
      _native_text_font_size(render, text_cache, size);
    }
  };
}


async function prepare(hv) {}
async function install(hv) {}
async function startup(hv) {
  let cfg = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {
    widescreen: true
  };
  const set_size = device => {
    const width = device.innerWidth;
    const height = device.innerHeight;
    const widescreen = cfg.widescreen && height >= width;
    hv.frontend.native_callback_resize(width, widescreen ? height / 2 : height);
  };
  window.addEventListener("resize", ev => set_size(ev.target));
  set_size(window);
}
var resize_default = {
  prepare,
  install,
  startup
};


async function prepare2(hv) {}
async function install2(hv) {}
async function startup2(hv) {
  let cfg = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {
    uptime: false,
    unfocus_pause: false
  };
  let uptime = performance.now();
  function tick() {
    if (hv.running) {
      let new_time = performance.now();
      const dt = cfg.uptime ? new_time : new_time - uptime;
      uptime = new_time;
      hv.frontend.native_callback_loop(dt);
      hv.frontend.native_callback_draw();
      window.requestAnimationFrame(tick);
    }
  }
  if (cfg.unfocus_pause) {
    window.addEventListener("blur", () => _pause(hv.pause_reasons, "focus"));
    window.addEventListener("focus", () => _resume(hv.pause_reasons, "focus"));
  }
  await (() => new Promise(r => setTimeout(r, 1)))();
  window.requestAnimationFrame(() => {
    hv.frontend.native_callback_init();
    tick();
  });
}
var runtime_default = {
  prepare: prepare2,
  install: install2,
  startup: startup2
};


var padmap = {
  default: {
    pads: ["a", "b", "c", "d", "a", "b", "c", "d", "menu", "menu", "menu", "menu", "up", "down", "left", "right"],
    axis: ["left", "right", "up", "down", "left", "right", "up", "down", "left", "right", "up", "down"]
  },
  legacy: {
    pads: ["red", "green", "yellow", "blue", "left", "right", "up", "down", "menu"],
    axis: ["left", "right", "up", "down", "left", "right", "up", "down"]
  }
};
var keymap = {
  default: [[13, "a"], [38, "up"], [37, "left"], [40, "down"], [39, "right"], [403, "a"], [404, "b"], [405, "c"], [406, "d"], [461, "menu"], [10009, "menu"], ["KeyZ", "a"], ["KeyX", "b"], ["KeyC", "c"], ["KeyV", "d"], ["Enter", "a"], ["ArrowUp", "up"], ["ArrowDown", "down"], ["ArrowLeft", "left"], ["ArrowRight", "right"], ["ShiftLeft", "menu"]],
  legacy: [[13, "enter"], [38, "up"], [37, "left"], [40, "down"], [39, "right"], [403, "red"], [404, "green"], [405, "yellow"], [406, "blue"], [10009, "enter"], ["KeyZ", "red"], ["KeyX", "green"], ["KeyC", "yellow"], ["KeyV", "blue"], ["Enter", "enter"], ["ArrowUp", "up"], ["ArrowDown", "down"], ["ArrowLeft", "left"], ["ArrowRight", "right"]]
};


function gamepad_trigger(trigger, gamepadmap) {
  const previousStates = new Array(gamepadmap.pads.length).fill(0);
  const previousAxisStates = new Array(gamepadmap.axis.length).fill(0);
  const deadZone = 0.2;
  return () => {
    var _navigator;
    const gamepads = ((_navigator = navigator) === null || _navigator === void 0 ? void 0 : _navigator.getGamepads()) || [];
    for (const gamepad of gamepads) {
      if (gamepad) {
        gamepadmap.pads.forEach((action, index) => {
          var _gamepad$buttons$inde;
          const isPressed = (_gamepad$buttons$inde = gamepad.buttons[index]) !== null && _gamepad$buttons$inde !== void 0 && _gamepad$buttons$inde.pressed ? 1 : 0;
          if (isPressed !== previousStates[index]) {
            trigger(action, isPressed);
            previousStates[index] = isPressed;
          }
        });
        gamepadmap.axis.forEach((action, index) => {
          let isPressed = 0;
          let axisValue = gamepad.axes[Math.floor(index / 2)];
          if (index & 1 && deadZone < axisValue) {
            isPressed = 1;
          }
          if (!(index & 1) && -deadZone > axisValue) {
            isPressed = 1;
          }
          if (isPressed !== previousAxisStates[index]) {
            trigger(action, isPressed);
            previousAxisStates[index] = isPressed;
          }
        });
      }
    }
  };
}


async function prepare3(hv) {}
async function install3(hv) {}
async function startup3(hv, keys) {
  if (typeof keys != "object") {
    keys = "".concat(keys) in padmap ? padmap[keys] : padmap["default"];
  }
  hv.frontbus.on("pad", gamepad_trigger((key, value) => hv.frontbus.emit("keyboard", key, value), keys));
}
var gamepad_default = {
  prepare: prepare3,
  install: install3,
  startup: startup3
};


function keyboard_trigger(trigger, keymap2) {
  return ev => {
    const key = keymap2.find(key2 => [ev.code, ev.keyCode].includes(key2[0]));
    if (key) {
      ev.preventDefault();
      trigger(key[1], Number(ev.type === "keydown"));
    }
  };
}


async function prepare4(hv) {}
async function install4(hv) {}
async function startup4(hv, keys) {
  if (typeof keys != "object") {
    keys = "".concat(keys) in keymap ? keymap[keys] : keymap["default"];
  }
  document.addEventListener("keydown", keyboard_trigger(hv.frontend.native_callback_keyboard, keys));
  document.addEventListener("keyup", keyboard_trigger(hv.frontend.native_callback_keyboard, keys));
}
var keyboard_default = {
  prepare: prepare4,
  install: install4,
  startup: startup4
};


var mock = async _ => {};
async function check_wasmoon(hv) {
  if (!hv.vm.wasmoon) {
    throw new Error("wasmoon is required!");
  }
}
async function check_fengari(hv) {
  if (!hv.vm.fengari) {
    throw new Error("fengari is required!");
  }
}
var check_default = {
  wasmoon: {
    prepare: mock,
    install: check_wasmoon,
    startup: mock
  },
  fengari: {
    prepare: mock,
    install: check_fengari,
    startup: mock
  },
  fengari_wasmoon: {
    install: async hv => {
      var _hv$vm;
      if (!((_hv$vm = hv.vm) !== null && _hv$vm !== void 0 && _hv$vm.lua)) {
        throw new Error("wamoon or fengari is required!");
      }
    },
    prepare: mock,
    startup: mock
  }
};


async function prepare5(hv, LuaFactory) {
  if (!LuaFactory || hv.vm.lua) {
    return;
  }
  hv.vm.lua = true;
  hv.vm.wasmoon = new LuaFactory();
  hv.vm.lua = await hv.vm.wasmoon.createEngine();
}
async function install5(hv, _, LuaMultiReturn) {
  if (!hv.vm.wasmoon) {
    return;
  }
  for (const key in hv.backend) {
    hv.vm.lua.global.set(key, hv.backend[key]);
  }
  hv.vm.lua.global.set("native_image_mensure", src => {
    return LuaMultiReturn.from(hv.backend.native_image_mensure(src));
  });
  hv.vm.lua.global.set("native_text_mensure", text => {
    return LuaMultiReturn.from(hv.backend.native_text_mensure(text));
  });
  hv.vm.lua.global.set("native_draw_text", (x, y, text) => {
    return LuaMultiReturn.from(hv.backend.native_draw_text(x, y, text));
  });
  hv.vm.lua.global.set("native_dict_poly", {
    poly: hv.backend.native_draw_poly,
    poly2: hv.backend.native_draw_poly
  });
  if (window.location.protocol == "https:") {
    hv.vm.lua.global.set("native_http_force_protocol", "https");
  }
  hv.vm.lua.global.set("native_http_has_ssl", true);
  hv.vm.lua.global.set("native_json_encode", JSON.stringify);
  hv.vm.lua.global.set("native_json_decode", JSON.parse);
  hv.vm.lua.global.set("native_base64_encode", atob);
  hv.vm.lua.global.set("native_base64_decode", btoa);
  await hv.vm.lua.doString(await hv.code.engine());
  for (const key in hv.frontend) {
    hv.frontbus.on(key.replace(/^native_callback_/, ""), hv.vm.lua.global.get(key));
  }
}
async function startup5(hv) {}
async function destroy(hv) {
  if (hv.vm.wasmoon) {
    hv.vm.lua.global.close();
  }
}
var wasmoon_default = {
  prepare: prepare5,
  install: install5,
  startup: startup5,
  destroy
};


async function prepare_jsonrxi(hv, json_lib_rxi) {
  if (!hv.vm.fengari) {
    return;
  }
  const pseudonym = "jsonrxi.lua";
  const lua_lib = await create_code(pseudonym, json_lib_rxi)();
  const lua_code = lua_lib.replace("json.encode", "native_json_encode").replace("json.decode", "native_json_decode");
  const lua_buffer = hv.vm.fengari.to_luastring(lua_code);
  hv.vm.fengari.lauxlib.luaL_loadbuffer(hv.vm.lua, lua_buffer, lua_code.length, pseudonym);
  hv.vm.fengari.lua.lua_pcall(hv.vm.lua, 0, 0, 0);
}
async function prepare6(hv, fengari) {
  if (!fengari || hv.vm.lua) {
    return;
  }
  hv.vm.fengari = fengari;
  hv.vm.lua = fengari.lauxlib.luaL_newstate();
  fengari.lualib.luaL_openlibs(hv.vm.lua);
}
async function install6(hv, fengari) {
  if (!hv.vm.fengari) {
    return;
  }
  const httplua = (reqid, key, data) => {
    const params = data !== undefined ? 3 : 2;
    fengari.lua.lua_getglobal(hv.vm.lua, fengari.to_luastring("native_callback_http"));
    fengari.lua.lua_pushinteger(hv.vm.lua, reqid);
    fengari.lua.lua_pushstring(hv.vm.lua, fengari.to_luastring(key));
    if (typeof data == "string") {
      fengari.lua.lua_pushstring(hv.vm.lua, fengari.to_luastring(data));
    }
    if (typeof data == "number") {
      fengari.lua.lua_pushnumber(hv.vm.lua, data);
    }
    if (typeof data == "boolean") {
      fengari.lua.lua_pushboolean(hv.vm.lua, data);
    }
    if (fengari.lua.lua_pcall(hv.vm.lua, params, 1, 0) !== 0) {
      const err = fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, -1));
      fengari.lua.lua_settop(hv.vm.lua, 0);
      throw err;
    }
    if (fengari.lua.lua_type(hv.vm.lua, -1) == fengari.lua.LUA_TSTRING) {
      const res = fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, -1));
      fengari.lua.lua_settop(hv.vm.lua, 0);
      return res;
    }
    fengari.lua.lua_settop(hv.vm.lua, 0);
  };
  const define_lua_callback = (func_name, func_decorator) => {
    hv.frontbus.on(func_name.replace(/^native_callback_/, ""), (a, b, c, d, e, f) => {
      var _func;
      fengari.lua.lua_getglobal(hv.vm.lua, fengari.to_luastring(func_name));
      const func = func_decorator !== null && func_decorator !== void 0 ? func_decorator : () => 0;
      const res = (_func = func(a, b, c, d, e, f)) !== null && _func !== void 0 ? _func : 0;
      if (fengari.lua.lua_pcall(hv.vm.lua, res, 0, 0) !== 0) {
        const error_message = fengari.lua.lua_tostring(hv.vm.lua, -1);
        throw error_message && fengari.to_jsstring(error_message) || func_name;
      }
    });
  };
  const define_lua_func = (func_name, func_decorator) => {
    const func_native = hv.backend[func_name];
    fengari.lua.lua_pushcfunction(hv.vm.lua, () => {
      try {
        const res = func_decorator(func_native);
        return res !== null && res !== void 0 ? res : 0;
      } catch (e) {
        throw "".concat(e, " in ").concat(func_name);
      }
    });
    fengari.lua.lua_setglobal(hv.vm.lua, fengari.to_luastring(func_name));
  };
  define_lua_func("native_draw_start", func => {
    func();
  });
  define_lua_func("native_draw_flush", func => {
    func();
  });
  define_lua_func("native_draw_clear", func => {
    const color = fengari.lua.lua_tointeger(hv.vm.lua, 1) >>> 0;
    const x = fengari.lua.lua_tonumber(hv.vm.lua, 2);
    const y = fengari.lua.lua_tonumber(hv.vm.lua, 3);
    const w = fengari.lua.lua_tonumber(hv.vm.lua, 4);
    const h = fengari.lua.lua_tonumber(hv.vm.lua, 5);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(color, x, y, w, h);
  });
  define_lua_func("native_draw_color", func => {
    const color = fengari.lua.lua_tointeger(hv.vm.lua, 1) >>> 0;
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(color);
  });
  define_lua_func("native_draw_rect", func => {
    const mode = fengari.lua.lua_tointeger(hv.vm.lua, 1);
    const x = fengari.lua.lua_tonumber(hv.vm.lua, 2);
    const y = fengari.lua.lua_tonumber(hv.vm.lua, 3);
    const w = fengari.lua.lua_tonumber(hv.vm.lua, 4);
    const h = fengari.lua.lua_tonumber(hv.vm.lua, 5);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(mode, x, y, w, h);
  });
  define_lua_func("native_draw_rect2", func => {
    const mode = fengari.lua.lua_tointeger(hv.vm.lua, 1);
    const x = fengari.lua.lua_tonumber(hv.vm.lua, 2);
    const y = fengari.lua.lua_tonumber(hv.vm.lua, 3);
    const w = fengari.lua.lua_tonumber(hv.vm.lua, 4);
    const h = fengari.lua.lua_tonumber(hv.vm.lua, 5);
    const r = fengari.lua.lua_tonumber(hv.vm.lua, 6);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(mode, x, y, w, h, r);
  });
  define_lua_func("native_draw_line", func => {
    const x1 = fengari.lua.lua_tonumber(hv.vm.lua, 1);
    const y1 = fengari.lua.lua_tonumber(hv.vm.lua, 2);
    const x2 = fengari.lua.lua_tonumber(hv.vm.lua, 3);
    const y2 = fengari.lua.lua_tonumber(hv.vm.lua, 4);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(x1, y1, x2, y2);
  });
  define_lua_func("native_draw_poly2", func => {
    let i = 1;
    const mode = fengari.lua.lua_tointeger(hv.vm.lua, 1);
    const verts = [];
    const x = fengari.lua.lua_tonumber(hv.vm.lua, 3);
    const y = fengari.lua.lua_tonumber(hv.vm.lua, 4);
    const scale = fengari.lua.lua_tonumber(hv.vm.lua, 5);
    const angle = fengari.lua.lua_tonumber(hv.vm.lua, 6);
    const ox = fengari.lua.lua_tonumber(hv.vm.lua, 7);
    const oy = fengari.lua.lua_tonumber(hv.vm.lua, 8);
    while (fengari.lua.lua_rawgeti(hv.vm.lua, 2, i) !== fengari.lua.LUA_TNIL) {
      verts.push(fengari.lua.lua_tonumber(hv.vm.lua, -1));
      fengari.lua.lua_pop(hv.vm.lua, 1);
      i++;
    }
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(mode, verts, x, y, scale, angle, ox, oy);
  });
  define_lua_func("native_text_print", func => {
    const x = fengari.lua.lua_tonumber(hv.vm.lua, 1);
    const y = fengari.lua.lua_tonumber(hv.vm.lua, 2);
    const text = fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 3));
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(x, y, text);
  });
  define_lua_func("native_text_font_size", func => {
    const size = fengari.lua.lua_tonumber(hv.vm.lua, 1);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(size);
  });
  define_lua_func("native_text_font_name", func => {
    const name = fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 1));
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(name);
  });
  define_lua_func("native_text_font_default", func => {
    func();
  });
  define_lua_func("native_text_font_previous", func => {
    func();
  });
  define_lua_func("native_text_mensure", func => {
    const text = fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 1));
    fengari.lua.lua_settop(hv.vm.lua, 0);
    const [width, height] = func(text);
    fengari.lua.lua_pushnumber(hv.vm.lua, width);
    fengari.lua.lua_pushnumber(hv.vm.lua, height);
    return 2;
  });
  define_lua_func("native_system_get_language", func => {
    fengari.lua.lua_pushstring(hv.vm.lua, fengari.to_luastring(func()));
    return 1;
  });
  define_lua_func("native_system_get_env", func => {
    const var_name = fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 1));
    fengari.lua.lua_settop(hv.vm.lua, 0);
    const var_value = func(var_name);
    if (var_value) {
      fengari.lua.lua_pushstring(hv.vm.lua, fengari.to_luastring(var_value));
      return 1;
    }
  });
  define_lua_func("native_image_load", func => {
    const src = fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 1));
    const url = fengari.lua.lua_type(hv.vm.lua, 2) === fengari.lua.LUA_TSTRING ? fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 2)) : null;
    fengari.lua.lua_settop(hv.vm.lua, 0);
    const id = func(src, url);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    if (id) {
      fengari.lua.lua_pushnumber(hv.vm.lua, 1);
      return 1;
    }
    return 0;
  });
  define_lua_func("native_image_draw", func => {
    const get_src_arg = idx => {
      const type = fengari.lua.lua_type(hv.vm.lua, idx);
      if (type === fengari.lua.LUA_TSTRING) {
        return fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, idx));
      } else if (type === fengari.lua.LUA_TNUMBER) {
        return fengari.lua.lua_tonumber(hv.vm.lua, idx);
      }
      return;
    };
    const src = get_src_arg(1);
    const x = fengari.lua.lua_tonumber(hv.vm.lua, 2);
    const y = fengari.lua.lua_tonumber(hv.vm.lua, 3);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(src, x, y);
  });
  define_lua_func("native_image_mensure", func => {
    const get_src_arg = idx => {
      const type = fengari.lua.lua_type(hv.vm.lua, idx);
      if (type === fengari.lua.LUA_TSTRING) {
        return fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, idx));
      } else if (type === fengari.lua.LUA_TNUMBER) {
        return fengari.lua.lua_tonumber(hv.vm.lua, idx);
      }
      return;
    };
    const src = get_src_arg(1);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    const [width, height] = func(src);
    fengari.lua.lua_pushnumber(hv.vm.lua, width);
    fengari.lua.lua_pushnumber(hv.vm.lua, height);
    return 2;
  });
  define_lua_func("native_media_bootstrap", func => {
    const mediatype = fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 1));
    const channels = func(mediatype);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    fengari.lua.lua_pushnumber(hv.vm.lua, channels);
    return 1;
  });
  define_lua_func("native_media_source", func => {
    const channel = fengari.lua.lua_tonumber(hv.vm.lua, 1);
    const src = fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 2));
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(channel, src);
  });
  define_lua_func("native_media_position", func => {
    const channel = fengari.lua.lua_tonumber(hv.vm.lua, 1);
    const x = fengari.lua.lua_tonumber(hv.vm.lua, 2);
    const y = fengari.lua.lua_tonumber(hv.vm.lua, 3);
    const w = fengari.lua.lua_tonumber(hv.vm.lua, 4);
    const h = fengari.lua.lua_tonumber(hv.vm.lua, 5);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(channel, x, y, w, h);
  });
  define_lua_func("native_media_time", func => {
    const channel = fengari.lua.lua_tonumber(hv.vm.lua, 1);
    const time = fengari.lua.lua_tonumber(hv.vm.lua, 2);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(channel, Math.floor(time));
  });
  define_lua_func("native_media_resume", func => {
    const channel = fengari.lua.lua_tonumber(hv.vm.lua, 1);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(channel);
  });
  define_lua_func("native_media_play", func => {
    const channel = fengari.lua.lua_tonumber(hv.vm.lua, 1);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(channel);
  });
  define_lua_func("native_media_pause", func => {
    const channel = fengari.lua.lua_tonumber(hv.vm.lua, 1);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(channel);
  });
  define_lua_func("native_media_stop", func => {
    const channel = fengari.lua.lua_tonumber(hv.vm.lua, 1);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func(channel);
  });
  define_lua_func("native_http_handler", func => {
    const request_id = fengari.lua.lua_tonumber(hv.vm.lua, 2);
    fengari.lua.lua_settop(hv.vm.lua, 0);
    func({
      param_dict: {},
      header_dict: {},
      set: (key, value) => httplua(request_id, "set-".concat(key), value),
      promise: () => httplua(request_id, "async-promise"),
      resolve: () => httplua(request_id, "async-resolve"),
      method: httplua(request_id, "get-method"),
      body: httplua(request_id, "get-body"),
      url: httplua(request_id, "get-fullurl")
    });
  });
  define_lua_func("native_log_debug", func => {
    func(fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 1)));
  });
  define_lua_func("native_log_info", func => {
    func(fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 1)));
  });
  define_lua_func("native_log_warn", func => {
    func(fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 1)));
  });
  define_lua_func("native_log_error", func => {
    func(fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 1)));
  });
  define_lua_func("native_log_fatal", func => {
    func(fengari.to_jsstring(fengari.lua.lua_tostring(hv.vm.lua, 1)));
  });
  if (window.location.protocol == "https:") {
    fengari.lua.lua_pushstring(hv.vm.lua, fengari.to_luastring("https"));
    fengari.lua.lua_setglobal(hv.vm.lua, fengari.to_luastring("native_http_force_protocol"));
  }
  fengari.lua.lua_pushboolean(hv.vm.lua, true);
  fengari.lua.lua_setglobal(hv.vm.lua, fengari.to_luastring("native_http_has_ssl"));
  const lua_engine = await hv.code.engine();
  fengari.lauxlib.luaL_loadbuffer(hv.vm.lua, fengari.to_luastring(lua_engine), lua_engine.length, "engine");
  fengari.lua.lua_pcall(hv.vm.lua, 0, 0, 0);
  define_lua_callback("native_callback_init", (width, height, game) => {
    fengari.lua.lua_pushnumber(hv.vm.lua, width);
    fengari.lua.lua_pushnumber(hv.vm.lua, height);
    fengari.lauxlib.luaL_loadbuffer(hv.vm.lua, fengari.to_luastring(game), game.lenght, "game");
    return 3;
  });
  define_lua_callback("native_callback_draw");
  define_lua_callback("native_callback_loop", dt => {
    fengari.lua.lua_pushnumber(hv.vm.lua, dt);
    return 1;
  });
  define_lua_callback("native_callback_resize", (width, height) => {
    fengari.lua.lua_pushnumber(hv.vm.lua, width);
    fengari.lua.lua_pushnumber(hv.vm.lua, height);
    return 2;
  });
  define_lua_callback("native_callback_keyboard", (key, value) => {
    fengari.lua.lua_pushstring(hv.vm.lua, fengari.to_luastring(key));
    fengari.lua.lua_pushboolean(hv.vm.lua, value);
    return 2;
  });
}
async function startup6(hv, fengari) {}
async function destroy2(hv) {
  if (hv.vm.fengari) {
    hv.vm.fengari.lua.lua_close(hv.vm.lua);
  }
}
var fengari_default = {
  jsonrxi: {
    prepare: prepare_jsonrxi,
    install: async hv => {},
    startup: async hv => {}
  },
  prepare: prepare6,
  install: install6,
  startup: startup6,
  destroy: destroy2
};


function _set_time(time) {
  return Math.max(0, performance.now() - time);
}
function genVerts(ms, width, height) {
  const pts = [];
  const duration = 1000;
  const points = [[width / 2, 0], [width, 0], [width, height], [0, height], [0, 0], [width / 2, 0]];
  const segmentTime = duration / (points.length - 1);
  const step = Math.min(Math.floor(ms / segmentTime), points.length - 2);
  const t = ms % segmentTime / segmentTime;
  function getLastPoint() {
    const [x1, y1] = points[step];
    const [x2, y2] = points[step + 1];
    return [x1 + (x2 - x1) * t, y1 + (y2 - y1) * t];
  }
  pts.push(width / 2, height / 2);
  points.filter((_, index) => index < step + 1).forEach(points2 => pts.push(points2[0], points2[1]));
  const [x, y] = getLastPoint();
  pts.push(x, y);
  return pts;
}
function cronomether(ms) {
  let date = new Date(ms);
  let formattedTime = date.toISOString().substr(11, 8);
  let milliseconds = (ms % 1000).toFixed(0).padStart(3, "0");
  return "".concat(formattedTime, ":").concat(milliseconds);
}
function _can(type, url, score, default_score) {
  if (typeof default_score !== "number") {
    default_score = 11;
  }
  if (!["video", "tv", "youtube", "stream"].includes(type)) {
    return 0;
  }
  return score + default_score;
}
function init(type, channel) {
  const el_root = document.querySelector("main");
  const el_media = document.createElement("canvas");
  const ctx = el_media.getContext("2d");
  const render = {
    canvas: el_media,
    ctx
  };
  let src = "";
  let cmd = "init";
  let paused = true;
  let started = performance.now();
  el_media.width = el_root.clientWidth;
  el_media.height = el_root.clientHeight;
  el_media.style.zIndex = "".concat(-channel - 1);
  el_root.appendChild(el_media);
  function tick() {
    if (!el_media.parentElement) {
      return;
    }
    const uptime = performance.now() - started;
    const crono = cronomether(uptime);
    const [cor1, cor2] = [255, 572662527];
    const font1 = (el_media.width / 80).toFixed(0);
    const font2 = (el_media.width / 16).toFixed(0);
    const secs = Math.ceil(uptime / 1000);
    _native_draw_clear(render, secs & 1 ? cor1 : cor2);
    _native_draw_color(render, secs & 1 ? cor2 : cor1);
    _native_draw_poly(render, 0, genVerts(uptime % 1000, el_media.width, el_media.height), 0, 0, 1, 0, 0, 0);
    _native_draw_color(render, 858993663);
    _native_draw_line(render, 0, el_media.height / 2, el_media.width, el_media.height / 2);
    _native_draw_line(render, el_media.width / 2, 0, el_media.width / 2, el_media.height);
    _native_draw_color(render, 4294967295);
    ctx.font = "".concat(font1, "px sans");
    ctx.textBaseline = "top";
    ctx.textAlign = "left";
    ctx.fillText(type, 0, 0);
    ctx.textBaseline = "bottom";
    ctx.fillText(cmd, 0, el_media.height);
    ctx.textAlign = "right";
    ctx.fillText(src, el_media.width, el_media.height);
    ctx.textBaseline = "top";
    ctx.fillText(crono, el_media.width, 0);
    ctx.font = "".concat(font2, "px sans");
    ctx.textBaseline = "middle";
    ctx.textAlign = "center";
    ctx.fillText("".concat(secs), el_media.width / 2, el_media.height / 2);
    if (!paused) {
      window.requestAnimationFrame(tick);
    }
  }
  return {
    can: _can,
    set_time: time => {
      started = _set_time(time);
    },
    source: url => {
      cmd = "source";
      src = url;
    },
    play: () => {
      cmd = "play";
      started = _set_time(0);
      if (paused) {
        paused = false;
        tick();
      }
    },
    pause: () => {
      cmd = "pause";
      paused = true;
    },
    resume: () => {
      cmd = "resume";
      if (paused) {
        paused = false;
        tick();
      }
    },
    position: (x, y, width, height) => {
      cmd = "position";
      el_media.style.left = "".concat(x, "px");
      el_media.style.top = "".concat(y, "px");
      el_media.width = width;
      el_media.height = height;
    },
    destroy: () => {
      el_media.remove();
    }
  };
}
async function create_player(hv, default_score) {
  hv.media_players.push({
    init,
    can: (a, b, c) => _can(a, b, c, default_score)
  });
}
var fake_default = {
  prepare: create_player,
  install: async () => {},
  startup: async () => {}
};


var is_video = (type, func) => type === "video" ? func : () => {};
function set_time2(el) {
  return function (time) {
    if (el.fastSeek) {
      el.fastSeek(time);
    } else {
      el.currentTime = time;
    }
  };
}
function can2(type, url, score) {
  if (!["video", "audio", "music", "sfx"].includes(type)) {
    return 0;
  }
  return score + 20;
}
function init2(type, channel) {
  let el_media = document.createElement(type === "video" ? "video" : "audio");
  const el_root = document.querySelector("main");
  is_video(type, () => el_media.style.zIndex = "".concat(-channel - 1))();
  el_root.appendChild(el_media);
  return {
    can: can2,
    set_time: set_time2(el_media),
    source: url => {
      el_media.src = url;
    },
    play: () => {
      set_time2(el_media)(0);
      el_media.play();
    },
    pause: () => {
      el_media.pause();
    },
    resume: () => {
      el_media.play();
    },
    position: is_video(type, (x, y, width, height) => {
      el_media.style.left = "".concat(x, "px");
      el_media.style.top = "".concat(y, "px");
      el_media.style.width = "".concat(width, "px");
      el_media.style.height = "".concat(height, "px");
    }),
    destroy: () => {
      const drop = () => el_media.remove();
      el_media.onerror = drop;
      el_media.onabort = drop;
      el_media.onload = drop;
      el_media.src = "";
      el_media.load();
    }
  };
}
async function create_player2(hv) {
  hv.media_players.push({
    init: init2,
    can: can2
  });
}
var html5_default = {
  prepare: create_player2,
  install: async () => {},
  startup: async () => {}
};


function can3(type, url, score) {
  if (!["video", "stream"].includes(type)) {
    return 0;
  }
  if (/\.(m3u8|mpd)$/i.test(url)) {
    return score + 40;
  }
  return score + 20;
}
function init3(videojslib, type, channel) {
  const el_root = document.querySelector("main");
  const el_media = document.createElement("video");
  el_media.className = "video-js";
  el_root.appendChild(el_media);
  if (!document.querySelector("#vsj-hidden")) {
    const style = document.createElement("style");
    style.innerHTML = ".vsj-hidden, .video-js div, .video-js button { display: none }";
    style.id = "vsj-hidden";
    document.head.appendChild(style);
  }
  el_media.style.zIndex = "".concat(-channel - 1);
  const player = videojslib(el_media, {
    controls: false
  });
  return {
    can: can3,
    set_time: time => {
      player.currentTime(time);
    },
    source: url => {
      player.src({
        src: url
      });
    },
    play: () => {
      player.currentTime(0);
      player.play();
    },
    pause: () => {
      player.pause();
    },
    resume: () => {
      player.play();
    },
    position: (x, y, width, height) => {
      player.width(width);
      player.height(height);
      el_media.style.left = "".concat(x, "px");
      el_media.style.top = "".concat(y, "px");
      el_media.style.width = "".concat(width, "px");
      el_media.style.height = "".concat(height, "px");
    },
    destroy: () => {
      player.dispose();
      const drop = () => el_media.remove();
      el_media.onabort = drop;
      el_media.onerror = drop;
      el_media.onload = drop;
      el_media.src = "";
      el_media.load();
      el_media.remove();
    }
  };
}
async function create_player3(hv, videojslib) {
  if (videojslib) {
    hv.media_players.push({
      can: can3,
      init: (a, b) => init3(videojslib, a, b)
    });
  }
}
var videojs_default = {
  prepare: create_player3,
  install: async () => {},
  startup: async () => {}
};


function youtubeId(url) {
  const regex = /(?:youtu\.be\/|youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|v\/))([^?&"'>]+)/;
  const match = url.match(regex);
  return match ? match[1] : null;
}
function can4(type, url, score) {
  if (!["video", "youtube"].includes(type)) {
    return 0;
  }
  if (url.length === 0) {
    return 1;
  }
  if (youtubeId(url)) {
    return 100;
  }
  return 0;
}
function init4(type, channel) {
  const el_root = document.querySelector("main");
  const iframe = document.createElement("iframe");
  iframe.className = "youtube-player";
  iframe.frameBorder = "0";
  iframe.allow = "autoplay encrypted-media";
  iframe.allowFullscreen = true;
  el_root.appendChild(iframe);
  let isPlayerReady = false;
  iframe.style.zIndex = "".concat(-channel - 1);
  iframe.addEventListener("load", () => {
    isPlayerReady = true;
  });
  function sendCommandWhenReady(func) {
    let args = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : [];
    if (isPlayerReady) {
      var _iframe$contentWindow;
      (_iframe$contentWindow = iframe.contentWindow) === null || _iframe$contentWindow === void 0 || _iframe$contentWindow.postMessage(JSON.stringify({
        event: "command",
        func,
        args
      }), "*");
    } else {
      setTimeout(() => sendCommandWhenReady(func, args), 100);
    }
  }
  return {
    can: can4,
    set_time: time => {
      sendCommandWhenReady("seekTo", [time, true]);
    },
    source: url => {
      iframe.src = "https://www.youtube.com/embed/".concat(youtubeId(url), "?enablejsapi=1&autoplay=0&modestbranding=1&controls=0");
    },
    play: () => {
      sendCommandWhenReady("playVideo");
    },
    pause: () => {
      sendCommandWhenReady("pauseVideo");
    },
    resume: () => {
      sendCommandWhenReady("playVideo");
    },
    position: (x, y, width, height) => {
      iframe.style.left = "".concat(x, "px");
      iframe.style.top = "".concat(y, "px");
      iframe.style.width = "".concat(width, "px");
      iframe.style.height = "".concat(height, "px");
    },
    destroy: () => {
      el_root.removeChild(iframe);
    }
  };
}
async function create_player4(hv) {
  hv.media_players.push({
    init: init4,
    can: can4
  });
}
var youtube_default = {
  prepare: create_player4,
  install: async () => {},
  startup: async () => {}
};


var none = {
  prepare: async hv => {},
  install: async hv => {},
  startup: async hv => {}
};
var driver_map = {
  none,
  resize: resize_default,
  fengari: fengari_default,
  wasmoon: wasmoon_default,
  runtime: runtime_default,
  gamepad: gamepad_default,
  keyboard: keyboard_default,
  "player-fake": fake_default,
  "player-html5": html5_default,
  "player-videojs": videojs_default,
  "player-youtube": youtube_default,
  "wasmoon-check": check_default.wasmoon,
  "fengari-check": check_default.fengari,
  "fengari-or-wasmoon-check": check_default.fengari_wasmoon,
  "fengari-jsonrxi": fengari_default.jsonrxi
};
function custom_driver(step_name, driver_name) {
  return async function (hv, func) {
    if (typeof func !== "object" || typeof func[step_name] !== "function") {
      if (step_name == "destroy") return;
      throw new Error("driver not found: ".concat(driver_name, " (").concat(step_name, ")"));
    }
    for (var _len3 = arguments.length, args = new Array(_len3 > 2 ? _len3 - 2 : 0), _key3 = 2; _key3 < _len3; _key3++) {
      args[_key3 - 2] = arguments[_key3];
    }
    await func[step_name](hv, ...args);
  };
}
function get_driver(driver_name) {
  const driver = driver_map[driver_name];
  if (driver) {
    return driver;
  }
  return {
    prepare: custom_driver("prepare", driver_name),
    install: custom_driver("install", driver_name),
    startup: custom_driver("startup", driver_name),
    destroy: custom_driver("destroy", driver_name)
  };
}


var src_default = () => {
  let cfg_game;
  let cfg_engine;
  let cfg_libs = [];
  let cfg_canvas;
  let cfg_rootel;
  const methods = () => ({
    setGame: game_code => {
      cfg_game = game_code;
      return methods();
    },
    setEngine: engine_code => {
      cfg_engine = engine_code;
      return methods();
    },
    setElementRoot: element => {
      cfg_rootel = element;
      return methods();
    },
    setElementCanvas: canvas => {
      cfg_canvas = canvas;
      return methods();
    },
    addLibrary: function addLibrary(type) {
      for (var _len4 = arguments.length, args = new Array(_len4 > 1 ? _len4 - 1 : 0), _key4 = 1; _key4 < _len4; _key4++) {
        args[_key4 - 1] = arguments[_key4];
      }
      cfg_libs.push({
        driver: get_driver(type),
        args
      });
      return methods();
    },
    build: async () => {
      const vm = {};
      const running = true;
      const media_players = [];
      const pause_reasons = {};
      const code = {
        game: typeof cfg_game == "string" ? create_code("game.lua", cfg_game) : cfg_game,
        engine: create_code("engine.lua", cfg_engine)
      };
      const canvas = create_canvas(cfg_canvas);
      const ctx = canvas.getContext("2d");
      const backend = create_backend(canvas, ctx, media_players);
      const frontbus = create_emiter();
      const frontend = await create_frontend(frontbus, code, canvas, pause_reasons);
      const hypervisor = {
        vm,
        code,
        backend,
        frontend,
        frontbus,
        pause_reasons,
        media_players,
        running
      };
      await Promise.all(cfg_libs.map(lib => lib.driver.prepare(hypervisor, ...lib.args)));
      await Promise.all(cfg_libs.map(lib => lib.driver.install(hypervisor, ...lib.args)));
      await Promise.all(cfg_libs.map(lib => lib.driver.startup(hypervisor, ...lib.args)));
      const shutdown = async () => {
        await Promise.all(cfg_libs.map(lib => {
          var _lib$driver$destroy, _lib$driver;
          return (_lib$driver$destroy = (_lib$driver = lib.driver).destroy) === null || _lib$driver$destroy === void 0 ? void 0 : _lib$driver$destroy.call(_lib$driver, hypervisor, ...lib.args);
        }));
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        hypervisor.running = false;
      };
      return create_engine(hypervisor, canvas, ctx, shutdown);
    }
  });
  return methods();
};


window.CoreNativeHtml5 = src_default;

},{}]},{},[1]);
