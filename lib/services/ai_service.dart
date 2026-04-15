import 'dart:math';
import 'package:chess/chess.dart' as ch;

enum AIDifficulty { beginner, easy, intermediate, advanced }

class AIService {
  static final Random _rng = Random();

  /// Returns a move map `{from, to}` for the given [fen], or null if no moves.
  static Map<String, String>? getAIMove(String fen, AIDifficulty difficulty) {
    final chess = ch.Chess.fromFEN(fen);
    final moves = chess.moves({'verbose': true});
    if (moves.isEmpty) return null;

    final prettyMoves =
        moves.map((m) => m as Map<String, dynamic>).toList();

    switch (difficulty) {
      case AIDifficulty.beginner:
        return _randomMove(prettyMoves);
      case AIDifficulty.easy:
        return _preferCaptures(prettyMoves);
      case AIDifficulty.intermediate:
        return _greedyBestMove(chess, prettyMoves);
      case AIDifficulty.advanced:
        return _minimaxMove(chess, prettyMoves, depth: 3);
    }
  }

  // ── Difficulty implementations ─────────────────────────────────────────────

  /// Picks a completely random legal move.
  static Map<String, String> _randomMove(List<Map<String, dynamic>> moves) {
    final m = moves[_rng.nextInt(moves.length)];
    return _toMoveMap(m);
  }

  /// Prefers captures; falls back to random.
  static Map<String, String> _preferCaptures(
      List<Map<String, dynamic>> moves) {
    final captures =
        moves.where((m) => m['captured'] != null).toList();
    final pool = captures.isNotEmpty ? captures : moves;
    return _toMoveMap(pool[_rng.nextInt(pool.length)]);
  }

  /// Single-ply greedy: picks the move that maximises material gain.
  static Map<String, String> _greedyBestMove(
      ch.Chess chess, List<Map<String, dynamic>> moves) {
    int bestScore = -999999;
    final candidates = <Map<String, dynamic>>[];

    for (final m in moves) {
      final clone = ch.Chess.fromFEN(chess.fen);
      clone.move({'from': m['from'], 'to': m['to'], 'promotion': 'q'});
      final score = _evaluate(clone);

      if (score > bestScore) {
        bestScore = score;
        candidates.clear();
        candidates.add(m);
      } else if (score == bestScore) {
        candidates.add(m);
      }
    }

    return _toMoveMap(candidates[_rng.nextInt(candidates.length)]);
  }

  /// Minimax with alpha-beta pruning.
  static Map<String, String> _minimaxMove(
      ch.Chess chess, List<Map<String, dynamic>> moves,
      {required int depth}) {
    // AI is always the side to move when this is called (black)
    final isMaximising = chess.turn == ch.Color.BLACK;

    int bestScore = isMaximising ? -999999 : 999999;
    final candidates = <Map<String, dynamic>>[];

    for (final m in moves) {
      final clone = ch.Chess.fromFEN(chess.fen);
      clone.move({'from': m['from'], 'to': m['to'], 'promotion': 'q'});
      final score = _minimax(clone, depth - 1, -999999, 999999, !isMaximising);

      if (isMaximising) {
        if (score > bestScore) {
          bestScore = score;
          candidates.clear();
          candidates.add(m);
        } else if (score == bestScore) {
          candidates.add(m);
        }
      } else {
        if (score < bestScore) {
          bestScore = score;
          candidates.clear();
          candidates.add(m);
        } else if (score == bestScore) {
          candidates.add(m);
        }
      }
    }

    return _toMoveMap(candidates[_rng.nextInt(candidates.length)]);
  }

  static int _minimax(
      ch.Chess chess, int depth, int alpha, int beta, bool maximising) {
    if (depth == 0 || chess.game_over) return _evaluate(chess);

    final moves = chess.moves({'verbose': true});
    if (maximising) {
      int best = -999999;
      for (final m in moves) {
        final mv = m as Map<String, dynamic>;
        final clone = ch.Chess.fromFEN(chess.fen);
        clone.move({'from': mv['from'], 'to': mv['to'], 'promotion': 'q'});
        best = max(best, _minimax(clone, depth - 1, alpha, beta, false));
        alpha = max(alpha, best);
        if (beta <= alpha) break;
      }
      return best;
    } else {
      int best = 999999;
      for (final m in moves) {
        final mv = m as Map<String, dynamic>;
        final clone = ch.Chess.fromFEN(chess.fen);
        clone.move({'from': mv['from'], 'to': mv['to'], 'promotion': 'q'});
        best = min(best, _minimax(clone, depth - 1, alpha, beta, true));
        beta = min(beta, best);
        if (beta <= alpha) break;
      }
      return best;
    }
  }

  // ── Evaluation ─────────────────────────────────────────────────────────────

  static const Map<String, int> _pieceValues = {
    'p': 100,
    'n': 320,
    'b': 330,
    'r': 500,
    'q': 900,
    'k': 20000,
  };

  /// Positive = good for black (AI), negative = good for white (player).
  static int _evaluate(ch.Chess chess) {
    if (chess.in_checkmate) {
      return chess.turn == ch.Color.BLACK ? -99999 : 99999;
    }
    if (chess.in_draw) return 0;

    int score = 0;
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    for (final file in files) {
      for (int rank = 1; rank <= 8; rank++) {
        final sq = '$file$rank';
        final piece = chess.get(sq);
        if (piece == null) continue;
        final value = _pieceValues[piece.type.name.toLowerCase()] ?? 0;
        if (piece.color == ch.Color.BLACK) {
          score += value;
        } else {
          score -= value;
        }
      }
    }
    return score;
  }

  static Map<String, String> _toMoveMap(Map<String, dynamic> m) =>
      {'from': m['from'] as String, 'to': m['to'] as String};
}
