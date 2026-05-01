// Web Worker wrapper for stockfish-18-asm.js (nmrugg/stockfish.js v18, ASM.js build).
// Loaded by StockfishService via: new Worker('stockfish_worker.js')
// stockfish.js must live at the same path root (web/).

// Web Workers don't have `window` — shim it to `self`.
var window = self;
// Some ASM.js builds probe document.currentScript.src to locate sibling files.
var document = { currentScript: { src: 'stockfish.js' } };

// CommonJS shim so the module can assign module.exports.
var exports = {};
var module = { exports: exports };

self.postMessage('[worker] script start');

importScripts('stockfish.js');

var StockfishExport = module.exports;
var pendingCmds = [];

function startEngine(sf) {
  self.postMessage('[worker] engine acquired: ' + typeof sf);

  // ── Output ────────────────────────────────────────────────────────────────
  // v18 ASM.js routes all print() calls through d.listener when set.
  // Try every known API so we work regardless of exact build variant.
  var outputFn = function (line) { self.postMessage(line); };
  if (typeof sf.addMessageListener === 'function') sf.addMessageListener(outputFn);
  // Set listener-style properties only if they're not already functions
  // (avoids stomping a real method with our callback).
  if (typeof sf.onmessage !== 'function')  sf.onmessage = outputFn;
  if (typeof sf.listen    !== 'function')  sf.listen    = outputFn;
  if (typeof sf.listener  !== 'function')  sf.listener  = outputFn;

  // ── Input ─────────────────────────────────────────────────────────────────
  // The module installs   onmessage = onmessage || function(A){w.processCommand(A.data)}
  // during async engine init, just before it resolves the promise.
  // Capture that handler here — it is the bridge to w.processCommand.
  var moduleHandler = (typeof self.onmessage === 'function') ? self.onmessage : null;

  function sendToEngine(cmd) {
    // Try every known direct API first, then fall back to the module's handler.
    if (typeof sf.processCommand === 'function') { sf.processCommand(cmd); return; }
    if (typeof sf.postMessage     === 'function') { sf.postMessage(cmd);     return; }
    if (typeof sf.send            === 'function') { sf.send(cmd);            return; }
    if (typeof sf.cmd             === 'function') { sf.cmd(cmd);             return; }
    if (moduleHandler)                            { moduleHandler({ data: cmd }); return; }
    self.postMessage('[worker] ERROR: no input API found for cmd: ' + cmd);
  }

  // Override self.onmessage so Dart messages reach the engine.
  self.onmessage = function (event) {
    var cmd = (event && event.data !== undefined) ? event.data : event;
    if (typeof cmd === 'string') sendToEngine(cmd);
  };

  // Flush any commands that were queued before engine was ready.
  pendingCmds.forEach(function (c) { sendToEngine(c); });
  pendingCmds = [];

  // Kick off UCI handshake.
  sendToEngine('uci');
}

// ── Bootstrap ─────────────────────────────────────────────────────────────────

if (typeof StockfishExport === 'function') {
  // Factory pattern. Pass listener in the config object so d.listener is set
  // from the very first print() call (otherwise the engine banner goes only
  // to console.log and we get no output before startEngine runs).
  var result = StockfishExport({
    listener: function (line) { self.postMessage(line); }
  });

  if (result && typeof result.then === 'function') {
    result.then(startEngine).catch(function (err) {
      self.postMessage('[worker] error: ' + err);
    });
  } else {
    // Synchronous factory (unlikely for this build, but handle it).
    startEngine(result);
  }
} else if (StockfishExport && typeof StockfishExport === 'object') {
  // Already-instantiated export.
  startEngine(StockfishExport);
} else {
  self.postMessage('[worker] ERROR: unexpected module.exports type: ' + typeof StockfishExport);
}

// NOTE: we intentionally do NOT set self.onmessage here (synchronously).
// The module installs its own handler via  onmessage = onmessage || fn
// during async init. If we set ours first the || guard blocks theirs,
// leaving w.processCommand unreachable. startEngine() captures and
// wraps the module handler after the factory promise resolves.
