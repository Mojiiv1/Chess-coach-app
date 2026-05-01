// Stockfish engine service for Flutter web.
//
// Web-only. Requires two files in web/:
//   web/stockfish.js        — stockfish-18-asm.js (nmrugg/stockfish.js v18)
//                             Pure ASM.js build: no .wasm, no SharedArrayBuffer,
//                             no CORS headers needed. ~10 MB, loads in a Worker.
//   web/stockfish_worker.js — Worker bootstrap (ships with this project).
//
// Public API:
//   evaluatePosition(fen)           → StockfishResult? (bestMove UCI + centipawns)
//   getBestMove(fen, skillLevel)    → String? UCI move
//
// Initialises eagerly on first access of StockfishService.instance.
// All calls return null (never throw) if the engine is unavailable.

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

// ── JS interop types ─────────────────────────────────────────────────────────

@JS('Worker')
extension type _Worker._(JSObject _) implements JSObject {
  external factory _Worker(String scriptURL);
  external void postMessage(JSAny? message);
  external set onmessage(JSFunction? fn);
  external set onerror(JSFunction? fn);
}

// ── Public result type ────────────────────────────────────────────────────────

class StockfishResult {
  final String bestMove;      // UCI notation, e.g. "e2e4"
  final int evalCentipawns;   // positive = white advantage
  const StockfishResult({required this.bestMove, required this.evalCentipawns});

  @override
  String toString() =>
      'StockfishResult(bestMove=$bestMove, eval=${evalCentipawns}cp)';
}

// ── Service ───────────────────────────────────────────────────────────────────

class StockfishService {
  static final StockfishService instance = StockfishService._();

  StockfishService._() {
    _init();
  }

  _Worker? _worker;
  bool _ready = false;
  final _readyCompleter = Completer<void>();

  // At most one pending evaluation at a time (engine is single-threaded).
  Completer<StockfishResult?>? _pending;
  int? _latestScore;

  void _init() {
    try {
      _worker = _Worker('stockfish_worker.js');
      _worker!.onmessage = ((JSAny? event) {
        if (event == null) return;
        final line =
            ((event as JSObject)['data']?.dartify() as String?) ?? '';
        if (line.isNotEmpty) _onLine(line);
      }).toJS;
      _worker!.onerror = ((JSAny? _) {
        debugPrint('[Stockfish] Worker error — engine unavailable');
      }).toJS;
    } catch (e) {
      debugPrint('[Stockfish] Failed to create Worker: $e');
    }
  }

  void _onLine(String line) {
    // Worker diagnostics — always print so we can trace the bridge.
    if (line.startsWith('[worker]')) {
      debugPrint('[Stockfish] $line');
      return;
    }

    // Log any line that carries key UCI tokens so we confirm engine output flows.
    if (line.contains('uci') ||
        line.contains('bestmove') ||
        line.contains('readyok')) {
      debugPrint('[Stockfish raw] $line');
    }

    if (line == 'uciok') {
      _worker!.postMessage('isready'.toJS);
    } else if (line == 'readyok') {
      _ready = true;
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
      debugPrint('[Stockfish] Engine ready');
    } else if (line.startsWith('info') && line.contains('score cp')) {
      _latestScore = _parseScore(line);
    } else if (line.startsWith('bestmove')) {
      final parts = line.split(' ');
      final move = parts.length >= 2 ? parts[1] : null;
      final result =
          (move != null && move != '(none)')
              ? StockfishResult(
                  bestMove: move,
                  evalCentipawns: _latestScore ?? 0,
                )
              : null;
      _pending?.complete(result);
      _pending = null;
      _latestScore = null;
    }
  }

  int? _parseScore(String line) {
    final m = RegExp(r'score cp (-?\d+)').firstMatch(line);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  Future<void> _waitReady() => _ready
      ? Future.value()
      : _readyCompleter.future.timeout(const Duration(seconds: 30));

  /// Evaluates [fen] and returns the best move and centipawn score.
  /// Returns null if the engine is unavailable or times out.
  Future<StockfishResult?> evaluatePosition(
    String fen, {
    int depth = 15,
  }) async {
    if (_worker == null) return null;
    try {
      await _waitReady();
    } catch (_) {
      return null;
    }
    _pending?.complete(null); // cancel any stale request
    _pending = Completer<StockfishResult?>();
    _latestScore = null;
    _worker!.postMessage('position fen $fen'.toJS);
    _worker!.postMessage('go depth $depth'.toJS);
    try {
      return await _pending!.future.timeout(const Duration(seconds: 30));
    } catch (_) {
      _pending = null;
      return null;
    }
  }

  /// Returns the best move in UCI notation for use as an AI opponent move.
  /// [skillLevel] is 0–20 (Stockfish Skill Level UCI option).
  Future<String?> getBestMove(
    String fen, {
    int skillLevel = 20,
    int depth = 15,
  }) async {
    if (_worker == null) return null;
    try {
      await _waitReady();
    } catch (_) {
      return null;
    }
    _worker!.postMessage('setoption name Skill Level value $skillLevel'.toJS);
    return (await evaluatePosition(fen, depth: depth))?.bestMove;
  }
}
