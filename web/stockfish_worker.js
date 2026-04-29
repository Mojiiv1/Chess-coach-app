// Web Worker wrapper for stockfish-18-asm.js (nmrugg/stockfish.js v18, ASM.js build).
// Loaded by StockfishService via: new Worker('stockfish_worker.js')
// stockfish.js must live at the same path root (web/).

// Web Workers don't have `window` — shim it to `self` so stockfish-18-asm.js
// browser-detection code doesn't throw a silent ReferenceError.
var window = self;
// Some ASM.js builds probe document.currentScript.src to locate the .wasm
// file or construct a worker URL. Stub it out so those checks don't crash.
var document = { currentScript: { src: 'stockfish.js' } };

// Provide a minimal CommonJS environment so the stockfish module can export itself.
var exports = {};
var module = { exports: exports };

importScripts('stockfish.js');

var StockfishFactory = module.exports;
var engine = null;
var pendingCmds = [];

StockfishFactory().then(function (sf) {
  engine = sf;

  // All UCI output lines are forwarded to the Dart side as plain strings.
  sf.listener = function (line) {
    self.postMessage(line);
  };

  // Flush commands that arrived before the engine was ready.
  pendingCmds.forEach(function (cmd) { sf.postMessage(cmd); });
  pendingCmds = [];

  // Begin UCI handshake.
  sf.postMessage('uci');
}).catch(function (err) {
  self.postMessage('error: ' + err);
});

// Commands from Dart arrive here and are forwarded to the engine.
self.onmessage = function (event) {
  var cmd = event.data;
  if (engine) {
    engine.postMessage(cmd);
  } else {
    pendingCmds.push(cmd);
  }
};
