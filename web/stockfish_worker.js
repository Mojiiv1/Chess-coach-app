// Web Worker wrapper for stockfish-18-lite-single.js (nmrugg/stockfish.js v18, single-threaded WASM build).
// Loaded by StockfishService via: new Worker('stockfish_worker.js')
// stockfish-18-lite-single.js and stockfish.wasm must live at the same path root (web/).

// Web Workers don't have `window` — shim it to `self`.
var window = self;
// Shim document.currentScript for build compatibility.
var document = { currentScript: { src: 'stockfish-18-lite-single.js' } };

// CommonJS shim so the module can assign module.exports.
var exports = {};
var module = { exports: exports };

self.postMessage('[worker] script start');

importScripts('stockfish-18-lite-single.js');

var StockfishExport = module.exports;
var pendingCmds = [];

function startEngine(sf) {
  self.postMessage('[worker] engine acquired: ' + typeof sf);

  // ── Output ────────────────────────────────────────────────────────────────
  // v18 ASM.js print() → d.listener when set; we already passed listener in
  // the factory config so this is belt-and-suspenders for other build shapes.
  var outputFn = function (line) { self.postMessage(line); };
  if (typeof sf.addMessageListener === 'function') sf.addMessageListener(outputFn);
  if (typeof sf.onmessage !== 'function') sf.onmessage = outputFn;
  if (typeof sf.listen    !== 'function') sf.listen    = outputFn;
  if (typeof sf.listener  !== 'function') sf.listener  = outputFn;

  // ── Input ─────────────────────────────────────────────────────────────────
  // In CommonJS mode the module does NOT install a self.onmessage handler.
  // Its internal processCommand() is implemented exactly as:
  //   w.ccall("command", null, ["string"], [cmd], {async: ...})
  // where w === the Module we receive from the factory (sf === d === w).
  // So sf.ccall("command", null, ["string"], [cmd]) is the correct path.
  function sendToEngine(cmd) {
    if (typeof sf.processCommand === 'function') { sf.processCommand(cmd); return; }
    if (typeof sf.postMessage    === 'function') { sf.postMessage(cmd);    return; }
    if (typeof sf.send           === 'function') { sf.send(cmd);           return; }
    if (typeof sf.cmd            === 'function') { sf.cmd(cmd);            return; }
    // Direct Emscripten ccall — equivalent to what processCommand does internally.
    if (typeof sf.ccall          === 'function') {
      sf.ccall('command', null, ['string'], [cmd]);
      return;
    }
    self.postMessage('[worker] ERROR: no input API for cmd: ' + cmd);
  }

  self.postMessage('[worker] input API: ' + (
    typeof sf.processCommand === 'function' ? 'processCommand' :
    typeof sf.postMessage    === 'function' ? 'postMessage'    :
    typeof sf.send           === 'function' ? 'send'           :
    typeof sf.cmd            === 'function' ? 'cmd'            :
    typeof sf.ccall          === 'function' ? 'ccall'          : 'NONE'
  ));

  self.onmessage = function (event) {
    var cmd = (event && event.data !== undefined) ? event.data : event;
    if (typeof cmd === 'string') sendToEngine(cmd);
  };

  pendingCmds.forEach(function (c) { sendToEngine(c); });
  pendingCmds = [];

  sendToEngine('uci');
}

// ── Bootstrap ─────────────────────────────────────────────────────────────────

if (typeof StockfishExport === 'function') {
  var result = StockfishExport({
    // Pass listener in the config so d.listener is set from the first print()
    // call — engine banner and all UCI output reach Dart, not just console.log.
    listener: function (line) { self.postMessage(line); }
  });

  if (result && typeof result.then === 'function') {
    result.then(startEngine).catch(function (err) {
      self.postMessage('[worker] error: ' + err);
    });
  } else {
    startEngine(result);
  }
} else if (StockfishExport && typeof StockfishExport === 'object') {
  startEngine(StockfishExport);
} else {
  self.postMessage('[worker] ERROR: unexpected module.exports type: ' + typeof StockfishExport);
}
