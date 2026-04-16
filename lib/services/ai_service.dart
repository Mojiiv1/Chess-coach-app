import 'dart:math';
import 'package:chess/chess.dart' as ch;
import '../utils/error_handler.dart';

/// Piece values in centipawns.
const Map<String, int> _pieceValues = {
  'p': 100,
  'n': 320,
  'b': 330,
  'r': 500,
  'q': 900,
  'k': 20000,
};

// ── Piece-Square Tables (from White's perspective, a1=index 0) ──────────────
// Indices run a1→h1, a2→h2 … a8→h8  (rank 1 at front, rank 8 at back)

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

/// Maps piece type to its PST.
const Map<String, List<int>> _pstMap = {
  'p': _pawnPst,
  'n': _knightPst,
  'b': _bishopPst,
  'r': _rookPst,
  'q': _queenPst,
  'k': _kingMiddlePst,
};

// ── Opening Book ──────────────────────────────────────────────────────────────
// Each entry is a sequence of UCI moves. AI plays the next move in the line.
const List<List<String>> _openingBook = [
  // Ruy Lopez
  ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1b5'],
  // Sicilian Defense
  ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4'],
  // Queen's Gambit
  ['d2d4', 'd7d5', 'c2c4', 'e7e6', 'b1c3'],
  // King's Indian
  ['d2d4', 'g8f6', 'c2c4', 'g7g6', 'b1c3'],
  // English Opening
  ['c2c4', 'e7e5', 'b1c3', 'g8f6', 'g2g3'],
  // French Defense
  ['e2e4', 'e7e6', 'd2d4', 'd7d5', 'b1c3'],
  // Caro-Kann
  ['e2e4', 'c7c6', 'd2d4', 'd7d5', 'b1c3'],
  // Italian Game
  ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4'],
  // London System
  ['d2d4', 'd7d5', 'c1f4', 'g8f6', 'e2e3'],
  // Nimzo-Indian
  ['d2d4', 'g8f6', 'c2c4', 'e7e6', 'b1c3', 'f8b4'],
  // Dutch Defense
  ['d2d4', 'f7f5', 'g2g3', 'g8f6', 'f1g2'],
  // Pirc Defense
  ['e2e4', 'd7d6', 'd2d4', 'g8f6', 'b1c3', 'g7g6'],
];

class AIService {
  static final _rng = Random();

  /// Returns (uciMove, evalCentipawns).
  /// evalCentipawns is positive = good for the side to move.
  static (String move, int eval) getAIMove(
    String fen,
    String difficulty,
    List<String> uciHistory,
  ) {
    try {
      if (!validateFen(fen)) {
        logWarning('AIService: invalid FEN received');
        return ('', 0);
      }

      switch (difficulty) {
        case 'beginner':
          return _randomMove(fen);
        case 'easy':
          return _greedyMove(fen);
        case 'intermediate':
          return _minimaxMove(fen, uciHistory, depth: 4);
        case 'advanced':
          return _minimaxMove(fen, uciHistory, depth: 6);
        default:
          return _randomMove(fen);
      }
    } catch (e) {
      handleError(e, context: 'getAIMove');
      return ('', 0);
    }
  }

  // ── Random (Beginner) ──────────────────────────────────────────────────────

  static (String, int) _randomMove(String fen) {
    final game = ch.Chess.fromFEN(fen);
    final moves = game.generate_moves();
    if (moves.isEmpty) return ('', 0);
    final m = moves[_rng.nextInt(moves.length)];
    return (_toUci(m), 0);
  }

  // ── Greedy capture-first (Easy) ────────────────────────────────────────────

  static (String, int) _greedyMove(String fen) {
    final game = ch.Chess.fromFEN(fen);
    final moves = game.generate_moves();
    if (moves.isEmpty) return ('', 0);

    // Sort: captures first (by victim value), then random among non-captures
    final captures =
        moves.where((m) => m.captured != null).toList();
    if (captures.isNotEmpty) {
      captures.sort((a, b) =>
          (_pieceValues[b.captured!.toLowerCase()] ?? 0) -
          (_pieceValues[a.captured!.toLowerCase()] ?? 0));
      return (_toUci(captures.first), 0);
    }
    final m = moves[_rng.nextInt(moves.length)];
    return (_toUci(m), 0);
  }

  // ── Minimax + Alpha-Beta (Intermediate & Advanced) ─────────────────────────

  static (String, int) _minimaxMove(
    String fen,
    List<String> uciHistory,
    {required int depth}
  ) {
    // Try opening book first (Advanced depth implies opening book enabled)
    if (depth >= 6) {
      final bookMove = _lookupOpeningBook(uciHistory);
      if (bookMove != null) return (bookMove, 0);
    }

    final game = ch.Chess.fromFEN(fen);
    final moves = _sortedMoves(game);
    if (moves.isEmpty) return ('', 0);

    String bestMove = _toUci(moves.first);
    int bestEval = -999999;
    const alpha = -999999;
    const beta = 999999;

    for (final move in moves) {
      game.move(move);
      final eval = -_alphaBeta(game, depth - 1, -beta, -alpha);
      game.undo_move();
      if (eval > bestEval) {
        bestEval = eval;
        bestMove = _toUci(move);
      }
    }
    return (bestMove, bestEval);
  }

  static int _alphaBeta(ch.Chess game, int depth, int alpha, int beta) {
    if (game.in_checkmate) return -99999 - depth; // prefer faster mates
    if (game.in_draw || game.in_stalemate || game.in_threefold_repetition) {
      return 0;
    }
    if (depth == 0) return _quiescence(game, alpha, beta);

    final moves = _sortedMoves(game);
    for (final move in moves) {
      game.move(move);
      final score = -_alphaBeta(game, depth - 1, -beta, -alpha);
      game.undo_move();
      if (score >= beta) return beta; // beta cutoff
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  /// Quiescence search: only look at captures to avoid horizon effect.
  static int _quiescence(ch.Chess game, int alpha, int beta) {
    final standPat = _evaluate(game);
    if (standPat >= beta) return beta;
    if (standPat > alpha) alpha = standPat;

    final captures = game.generate_moves().where((m) => m.captured != null);
    for (final move in captures) {
      game.move(move);
      final score = -_quiescence(game, -beta, -alpha);
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
    // Bonus for central moves
    const centerSquares = ['d4', 'd5', 'e4', 'e5'];
    if (centerSquares.contains(m.toAlgebraic)) return 5;
    return 0;
  }

  // ── Static evaluation ──────────────────────────────────────────────────────

  /// Returns score from the perspective of the side currently to move.
  static int _evaluate(ch.Chess game) {
    if (game.in_checkmate) return -99999;
    if (game.in_draw || game.in_stalemate) return 0;

    int score = 0;
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

    for (int rank = 1; rank <= 8; rank++) {
      for (int fileIdx = 0; fileIdx < 8; fileIdx++) {
        final square = '${files[fileIdx]}$rank';
        final piece = game.get(square);
        if (piece == null) continue;

        final type = piece.type.toLowerCase();
        final value = _pieceValues[type] ?? 0;
        final pst = _pstMap[type];
        int pstBonus = 0;
        if (pst != null) {
          // PST index: rank 1 = row 0 in the table for white
          final row = rank - 1;
          final col = fileIdx;
          final idx = piece.color == ch.Color.WHITE
              ? row * 8 + col
              : (7 - row) * 8 + col; // mirror for black
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

    // Return from perspective of side to move
    return game.turn == ch.Color.WHITE ? score : -score;
  }

  // ── Opening book ──────────────────────────────────────────────────────────

  static String? _lookupOpeningBook(List<String> uciHistory) {
    for (final line in _openingBook) {
      if (uciHistory.length >= line.length) continue;
      bool match = true;
      for (int i = 0; i < uciHistory.length; i++) {
        if (i >= line.length || line[i] != uciHistory[i]) {
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
    if (move.promotion != null) {
      uci += move.promotion!.toLowerCase();
    }
    return uci;
  }

  /// Evaluate the current position from white's perspective (for coach use).
  static int evaluatePosition(String fen) {
    try {
      if (!validateFen(fen)) return 0;
      final game = ch.Chess.fromFEN(fen);
      // _evaluate returns from side-to-move perspective; convert to white-relative
      final sideScore = _evaluate(game);
      return game.turn == ch.Color.WHITE ? sideScore : -sideScore;
    } catch (e) {
      return 0;
    }
  }
}
