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
  // v18 ASM.js routes print() through d.listener; we passed it in the factory
  // config too, so output is captured from the very first call.  Register all
  // other known variants defensively.
  var outputFn = function (line) { self.postMessage(line); };
  if (typeof sf.addMessageListener === 'function') sf.addMessageListener(outputFn);
  if (typeof sf.onmessage !== 'function') sf.onmessage = outputFn;
  if (typeof sf.listen    !== 'function') sf.listen    = outputFn;
  if (typeof sf.listener  !== 'function') sf.listener  = outputFn;

  // ── Input (with retry) ────────────────────────────────────────────────────
  // In this build the module installs its w.processCommand bridge via
  //   onmessage = onmessage || function(A){ w.processCommand(A.data) }
  // in a callback that fires AFTER the factory promise resolves.
  // Poll self.onmessage for up to ~1 second (100 × 10 ms) until it appears.
  function tryConnectInput(attemptsLeft) {
    // Check direct APIs on the engine object first.
    var hasDirect = (
      typeof sf.processCommand === 'function' ||
      typeof sf.postMessage    === 'function' ||
      typeof sf.send           === 'function' ||
      typeof sf.cmd            === 'function'
    );
    // Capture the module's own self.onmessage bridge if it has been installed.
    var moduleHandler = (typeof self.onmessage === 'function') ? self.onmessage : null;

    if (!hasDirect && !moduleHandler) {
      if (attemptsLeft > 0) {
        setTimeout(function () { tryConnectInput(attemptsLeft - 1); }, 10);
        return;
      }
      self.postMessage('[worker] ERROR: no input API found after 1s retry');
      return;
    }

    // Input API is ready — wire it up.
    self.postMessage('[worker] input API ready (direct=' + hasDirect +
                     ' moduleHandler=' + (moduleHandler !== null) + ')');

    function sendToEngine(cmd) {
      if (typeof sf.processCommand === 'function') { sf.processCommand(cmd); return; }
      if (typeof sf.postMessage    === 'function') { sf.postMessage(cmd);    return; }
      if (typeof sf.send           === 'function') { sf.send(cmd);           return; }
      if (typeof sf.cmd            === 'function') { sf.cmd(cmd);            return; }
      if (moduleHandler)                           { moduleHandler({ data: cmd }); return; }
      self.postMessage('[worker] ERROR: no input API for cmd: ' + cmd);
    }

    // Override self.onmessage so Dart commands reach the engine.
    self.onmessage = function (event) {
      var cmd = (event && event.data !== undefined) ? event.data : event;
      if (typeof cmd === 'string') sendToEngine(cmd);
    };

    // Flush anything queued before engine was ready.
    pendingCmds.forEach(function (c) { sendToEngine(c); });
    pendingCmds = [];

    // Kick off UCI handshake.
    sendToEngine('uci');
  }

  tryConnectInput(100); // up to ~1 second
}

// ── Bootstrap ─────────────────────────────────────────────────────────────────

if (typeof StockfishExport === 'function') {
  // Factory pattern. Pass listener in the config so d.listener is set from
  // the first print() call (engine banner flows to Dart rather than console.log).
  var result = StockfishExport({
    listener: function (line) { self.postMessage(line); }
  });

  if (result && typeof result.then === 'function') {
    result.then(startEngine).catch(function (err) {
      self.postMessage('[worker] error: ' + err);
    });
  } else {
    startEngine(result); // synchronous factory (unlikely but handled)
  }
} else if (StockfishExport && typeof StockfishExport === 'object') {
  startEngine(StockfishExport); // already-instantiated export
} else {
  self.postMessage('[worker] ERROR: unexpected module.exports type: ' + typeof StockfishExport);
}

// NOTE: self.onmessage is NOT set synchronously here.  The module uses
//   onmessage = onmessage || fn
// to install its w.processCommand bridge.  Setting ours first would trip
// the || guard.  tryConnectInput() polls until the module's handler appears,
// then wraps it.
