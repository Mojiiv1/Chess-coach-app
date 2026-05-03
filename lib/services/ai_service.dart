import 'dart:math';
import 'package:chess/chess.dart' as ch;
import '../utils/error_handler.dart';
import 'stockfish_service.dart';

/// Piece values in centipawns.
const Map<String, int> _pieceValues = {
  'p': 100,
  'n': 320,
  'b': 330,
  'r': 500,
  'q': 900,
  'k': 20000,
};

// ── Piece-Square Tables (from White's perspective) ────────────────────────────
// Layout: a1=index 0, h1=index 7, a8=index 56, h8=index 63

const List<int> _pawnPst = [
   0,  0,  0,  0,  0,  0,  0,  0,
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
   5,  5, 10, 25, 25, 10,  5,  5,
   0,  0,  0, 20, 20,  0,  0,  0,
   5, -5,-10,  0,  0,-10, -5,  5,
   5, 10, 10,-20,-20, 10, 10,  5,
   0,  0,  0,  0,  0,  0,  0,  0,
];

const List<int> _knightPst = [
  -50,-40,-30,-30,-30,-30,-40,-50,
  -40,-20,  0,  0,  0,  0,-20,-40,
  -30,  0, 10, 15, 15, 10,  0,-30,
  -30,  5, 15, 20, 20, 15,  5,-30,
  -30,  0, 15, 20, 20, 15,  0,-30,
  -30,  5, 10, 15, 15, 10,  5,-30,
  -40,-20,  0,  5,  5,  0,-20,-40,
  -50,-40,-30,-30,-30,-30,-40,-50,
];

const List<int> _bishopPst = [
  -20,-10,-10,-10,-10,-10,-10,-20,
  -10,  0,  0,  0,  0,  0,  0,-10,
  -10,  0,  5, 10, 10,  5,  0,-10,
  -10,  5,  5, 10, 10,  5,  5,-10,
  -10,  0, 10, 10, 10, 10,  0,-10,
  -10, 10, 10, 10, 10, 10, 10,-10,
  -10,  5,  0,  0,  0,  0,  5,-10,
  -20,-10,-10,-10,-10,-10,-10,-20,
];

const List<int> _rookPst = [
   0,  0,  0,  0,  0,  0,  0,  0,
   5, 10, 10, 10, 10, 10, 10,  5,
  -5,  0,  0,  0,  0,  0,  0, -5,
  -5,  0,  0,  0,  0,  0,  0, -5,
  -5,  0,  0,  0,  0,  0,  0, -5,
  -5,  0,  0,  0,  0,  0,  0, -5,
  -5,  0,  0,  0,  0,  0,  0, -5,
   0,  0,  0,  5,  5,  0,  0,  0,
];

const List<int> _queenPst = [
  -20,-10,-10, -5, -5,-10,-10,-20,
  -10,  0,  0,  0,  0,  0,  0,-10,
  -10,  0,  5,  5,  5,  5,  0,-10,
   -5,  0,  5,  5,  5,  5,  0, -5,
    0,  0,  5,  5,  5,  5,  0, -5,
  -10,  5,  5,  5,  5,  5,  0,-10,
  -10,  0,  5,  0,  0,  0,  0,-10,
  -20,-10,-10, -5, -5,-10,-10,-20,
];

const List<int> _kingMiddlePst = [
  -30,-40,-40,-50,-50,-40,-40,-30,
  -30,-40,-40,-50,-50,-40,-40,-30,
  -30,-40,-40,-50,-50,-40,-40,-30,
  -30,-40,-40,-50,-50,-40,-40,-30,
  -20,-30,-30,-40,-40,-30,-30,-20,
  -10,-20,-20,-20,-20,-20,-20,-10,
   20, 20,  0,  0,  0,  0, 20, 20,
   20, 30, 10,  0,  0, 10, 30, 20,
];

const Map<String, List<int>> _pstMap = {
  'p': _pawnPst,
  'n': _knightPst,
  'b': _bishopPst,
  'r': _rookPst,
  'q': _queenPst,
  'k': _kingMiddlePst,
};

// ── Opening Book ──────────────────────────────────────────────────────────────
const List<List<String>> _openingBook = [
  ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1b5'],
  ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4'],
  ['d2d4', 'd7d5', 'c2c4', 'e7e6', 'b1c3'],
  ['d2d4', 'g8f6', 'c2c4', 'g7g6', 'b1c3'],
  ['c2c4', 'e7e5', 'b1c3', 'g8f6', 'g2g3'],
  ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1c3'],
  ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'b1c3'],
  ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4'],
  ['d2d4', 'd7d5', 'c1f4', 'g8f6', 'e2e3'],
  ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'b1c3', 'f8b4'],
  ['d2d4', 'f7f5', 'g2g3', 'g8f6', 'f1g2'],
  ['e2e4', 'd7d6', 'd2d4', 'g8f6', 'b1c3', 'g7g6'],
];

class AIService {
  static final _rng = Random();

  /// Main entry point. Returns (uciMove, evalCentipawns).
  /// Tries Stockfish first at the appropriate skill/time setting for the
  /// difficulty, then falls back to the homemade AI if Stockfish is
  /// unavailable (engine not yet ready, or non-web platform).
  static Future<(String move, int eval)> getAIMove(
    String fen,
    String difficulty,
    List<String> uciHistory,
  ) async {
    try {
      if (!validateFen(fen)) {
        logWarning('AIService: invalid FEN');
        return _randomMove(fen);
      }

      // ── Stockfish path ────────────────────────────────────────────────────
      final sfMove = await _stockfishMove(fen, difficulty);
      if (sfMove != null && sfMove.isNotEmpty) {
        return (sfMove, 0);
      }

      // ── Homemade AI fallback (Stockfish unavailable) ──────────────────────
      final (move, eval) = switch (difficulty) {
        'beginner' => _beginnerMove(fen),
        'easy' => _greedyMove(fen),
        'intermediate' => _minimaxMove(fen, uciHistory, depth: 3, qdepth: 2),
        'advanced' => _minimaxMove(fen, uciHistory, depth: 4, qdepth: 1),
        _ => _randomMove(fen),
      };

      if (move.isEmpty) {
        logWarning('AIService: empty move from $difficulty — falling back to random');
        return _randomMove(fen);
      }
      return (move, eval);
    } catch (e) {
      handleError(e, context: 'getAIMove');
      return _randomMove(fen);
    }
  }

  /// Asks Stockfish for the best move at the skill/time settings for this
  /// difficulty. Returns null if Stockfish is not available.
  static Future<String?> _stockfishMove(
      String fen, String difficulty) async {
    try {
      final sf = StockfishService.instance;
      return switch (difficulty) {
        'beginner' => await sf.getBestMoveForOpponent(
            fen: fen, skillLevel: 1, depthOrTimeMs: 100, useMovetime: true),
        'easy' => await sf.getBestMoveForOpponent(
            fen: fen, skillLevel: 5, depthOrTimeMs: 200, useMovetime: true),
        'intermediate' => await sf.getBestMoveForOpponent(
            fen: fen, skillLevel: 10, depthOrTimeMs: 8),
        'advanced' => await sf.getBestMoveForOpponent(
            fen: fen, skillLevel: 20, depthOrTimeMs: 12),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  // ── Beginner: purely random ────────────────────────────────────────────────

  /// Completely random — ignores captures, checks, everything.
  static (String, int) _beginnerMove(String fen) {
    try {
      final game = ch.Chess.fromFEN(fen);
      final moves = game.generate_moves();
      if (moves.isEmpty) return ('', 0);
      return (_toUci(moves[_rng.nextInt(moves.length)]), 0);
    } catch (_) {
      return ('', 0);
    }
  }

  // ── Random (internal fallback) ─────────────────────────────────────────────

  static (String, int) _randomMove(String fen) {
    try {
      final game = ch.Chess.fromFEN(fen);
      final moves = game.generate_moves();
      if (moves.isEmpty) return ('', 0);
      return (_toUci(moves[_rng.nextInt(moves.length)]), 0);
    } catch (_) {
      return ('', 0);
    }
  }

  // ── Greedy capture-first (Easy) ────────────────────────────────────────────

  static (String, int) _greedyMove(String fen) {
    try {
      final game = ch.Chess.fromFEN(fen);
      final moves = game.generate_moves();
      if (moves.isEmpty) return ('', 0);

      final captures = moves.where((m) => m.captured != null).toList();
      if (captures.isNotEmpty) {
        captures.sort((a, b) =>
            (_pieceValues[b.captured!.toLowerCase()] ?? 0) -
            (_pieceValues[a.captured!.toLowerCase()] ?? 0));
        return (_toUci(captures.first), 0);
      }
      return (_toUci(moves[_rng.nextInt(moves.length)]), 0);
    } catch (_) {
      return _randomMove(fen);
    }
  }

  // ── Minimax + Alpha-Beta ───────────────────────────────────────────────────
  // Depths are kept LOW intentionally: Flutter Web (JS) runs ~20x slower than
  // native Dart. Depth 2 ≈ ~400 nodes, depth 3 ≈ ~3000 nodes — both respond
  // in under 2 seconds on web. Depth 4+ causes 10–30 second freezes.

  static (String, int) _minimaxMove(
    String fen,
    List<String> uciHistory, {
    required int depth,
    required int qdepth,
  }) {
    try {
      // Opening book for intermediate (depth>=3) and advanced (depth>=4)
      final bookMove = _lookupOpeningBook(uciHistory);
      if (bookMove != null) return (bookMove, 0);

      final game = ch.Chess.fromFEN(fen);
      final moves = _sortedMoves(game);
      if (moves.isEmpty) return ('', 0);

      String bestMove = _toUci(moves.first);
      int bestEval = -999999;
      int alpha = -999999;
      const beta = 999999;

      for (final move in moves) {
        game.move(move);
        final eval = -_alphaBeta(game, depth - 1, -beta, -alpha, qdepth);
        game.undo_move();
        if (eval > bestEval) {
          bestEval = eval;
          bestMove = _toUci(move);
        }
        if (bestEval > alpha) alpha = bestEval;
      }
      return (bestMove, bestEval);
    } catch (e) {
      handleError(e, context: '_minimaxMove');
      return _randomMove(fen);
    }
  }

  static int _alphaBeta(
      ch.Chess game, int depth, int alpha, int beta, int qdepth) {
    if (game.in_checkmate) return -99999 - depth;
    if (game.in_draw || game.in_stalemate || game.in_threefold_repetition) {
      return 0;
    }
    if (depth == 0) return _quiescence(game, alpha, beta, qdepth: qdepth);

    final moves = _sortedMoves(game);
    for (final move in moves) {
      game.move(move);
      final score = -_alphaBeta(game, depth - 1, -beta, -alpha, qdepth);
      game.undo_move();
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  /// Quiescence search capped at [qdepth] to prevent runaway recursion on web.
  static int _quiescence(ch.Chess game, int alpha, int beta,
      {required int qdepth}) {
    final standPat = _evaluate(game);
    if (standPat >= beta) return beta;
    if (standPat > alpha) alpha = standPat;
    if (qdepth <= 0) return alpha; // depth cap — prevents JS freeze

    final captures = game.generate_moves().where((m) => m.captured != null);
    for (final move in captures) {
      game.move(move);
      final score =
          -_quiescence(game, -beta, -alpha, qdepth: qdepth - 1);
      game.undo_move();
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  // ── Move ordering ──────────────────────────────────────────────────────────

  static List<ch.Move> _sortedMoves(ch.Chess game) {
    final moves = game.generate_moves();
    moves.sort((a, b) => _moveScore(b) - _moveScore(a));
    return moves;
  }

  static int _moveScore(ch.Move m) {
    if (m.captured != null) {
      final victimVal = _pieceValues[m.captured!.toLowerCase()] ?? 0;
      final attackerVal = _pieceValues[m.piece.toLowerCase()] ?? 0;
      return victimVal * 10 - attackerVal; // MVV-LVA
    }
    const centerSquares = ['d4', 'd5', 'e4', 'e5'];
    if (centerSquares.contains(m.toAlgebraic)) return 5;
    return 0;
  }

  // ── Static evaluation ──────────────────────────────────────────────────────

  /// Returns score from the perspective of the side to move.
  static int _evaluate(ch.Chess game) {
    if (game.in_checkmate) return -99999;
    if (game.in_draw || game.in_stalemate) return 0;

    int score = 0;
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

    for (int rank = 1; rank <= 8; rank++) {
      for (int fi = 0; fi < 8; fi++) {
        final piece = game.get('${files[fi]}$rank');
        if (piece == null) continue;

        final type = piece.type.toLowerCase();
        final value = _pieceValues[type] ?? 0;
        final pst = _pstMap[type];
        int pstBonus = 0;
        if (pst != null) {
          final row = rank - 1;
          final idx = piece.color == ch.Color.WHITE
              ? row * 8 + fi
              : (7 - row) * 8 + fi;
          pstBonus = pst[idx];
        }

        final pieceScore = value + pstBonus;
        if (piece.color == ch.Color.WHITE) {
          score += pieceScore;
        } else {
          score -= pieceScore;
        }
      }
    }

    return game.turn == ch.Color.WHITE ? score : -score;
  }

  // ── Opening book ──────────────────────────────────────────────────────────

  static String? _lookupOpeningBook(List<String> uciHistory) {
    for (final line in _openingBook) {
      if (uciHistory.length >= line.length) continue;
      bool match = true;
      for (int i = 0; i < uciHistory.length; i++) {
        if (line[i] != uciHistory[i]) {
          match = false;
          break;
        }
      }
      if (match) return line[uciHistory.length];
    }
    return null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _toUci(ch.Move move) {
    String uci = move.fromAlgebraic + move.toAlgebraic;
    if (move.promotion != null) uci += move.promotion!.toLowerCase();
    return uci;
  }

  /// Evaluate from white's perspective (for coach / eval bar).
  static int evaluatePosition(String fen) {
    try {
      if (!validateFen(fen)) return 0;
      final game = ch.Chess.fromFEN(fen);
      final sideScore = _evaluate(game);
      return game.turn == ch.Color.WHITE ? sideScore : -sideScore;
    } catch (_) {
      return 0;
    }
  }
}
