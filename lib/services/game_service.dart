import 'package:bishop/bishop.dart' as bishop;
import '../models/move.dart' as app;
import '../utils/constants.dart';

/// Wraps the bishop chess engine and exposes a clean API for the UI layer.
class GameService {
  late bishop.Game _game;
  final List<app.Move> _history = [];

  GameService() {
    _game = bishop.Game(variant: bishop.Variant.standard());
  }

  // ── State ──────────────────────────────────────────────────────────────────

  /// Current board as FEN string.
  String get fen => _game.fen;

  /// 'white' or 'black'
  String get turn => _game.turn == bishop.Bishop.white ? 'white' : 'black';

  bool get isWhiteTurn => _game.turn == bishop.Bishop.white;

  bool get isGameOver => _game.gameOver;

  List<app.Move> get history => List.unmodifiable(_history);

  // ── Move generation ────────────────────────────────────────────────────────

  /// Returns algebraic destination squares a piece on [square] can legally
  /// move to, e.g. ['e4', 'e3'] for a pawn on e2.
  /// Returns an empty list if the square is empty or has no legal moves.
  List<String> getLegalMoves(String square) {
    final legalMoves = _game.generateLegalMoves();
    final size = _game.size;

    // Convert the source square name to an internal index
    int fromIdx;
    try {
      fromIdx = size.squareNumber(square);
    } catch (_) {
      return [];
    }

    return legalMoves
        .where((m) => m.from == fromIdx)
        .map((m) => size.squareName(m.to))
        .toSet() // deduplicate promotions
        .toList();
  }

  // ── Move execution ─────────────────────────────────────────────────────────

  /// Attempts to make a move from [from] to [to].
  /// For pawn promotions defaults to queen.
  /// Returns the [app.Move] if successful, null if illegal.
  app.Move? makeMove(String from, String to) {
    // Build the algebraic string; append 'q' for queen promotion when needed
    final alg = _buildAlgebraic(from, to);
    final bishopMove = _game.getMove(alg);
    if (bishopMove == null) return null;

    final pieceChar = _pieceAt(from);
    final isCapture = bishopMove.capture;
    final notation = _game.toAlgebraic(bishopMove);

    final ok = _game.makeMove(bishopMove);
    if (!ok) return null;

    final move = app.Move(
      from: from,
      to: to,
      piece: pieceChar ?? '',
      notation: notation,
      isCapture: isCapture,
      timestamp: DateTime.now(),
    );
    _history.add(move);
    return move;
  }

  // ── Game-ending checks ─────────────────────────────────────────────────────

  bool isCheckmate() => _game.checkmate;

  bool isDraw() => _game.drawn;

  bool isInCheck() => _game.inCheck;

  bool isStalemate() => _game.stalemate;

  // ── Reset ──────────────────────────────────────────────────────────────────

  void reset() {
    _game = bishop.Game(variant: bishop.Variant.standard());
    _history.clear();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the FEN piece character at [square], e.g. 'P', 'k', null.
  String? _pieceAt(String square) {
    final boardMap = _parseFenToMap(fen);
    return boardMap[square];
  }

  /// Builds the algebraic move string, appending 'q' for pawn promotion.
  String _buildAlgebraic(String from, String to) {
    final piece = _pieceAt(from);
    final toRank = to[1];
    final isPromotion = (piece == 'P' && toRank == '8') ||
        (piece == 'p' && toRank == '1');
    return isPromotion ? '$from${to}q' : '$from$to';
  }

  /// Parses the position part of a FEN into a square→piece map.
  static Map<String, String> _parseFenToMap(String fen) {
    final Map<String, String> board = {};
    final position = fen.split(' ').first;
    final ranks = position.split('/');

    for (int rankIdx = 0; rankIdx < 8; rankIdx++) {
      final rankStr = ranks[rankIdx];
      int fileIdx = 0;
      for (final ch in rankStr.runes) {
        final char = String.fromCharCode(ch);
        final empty = int.tryParse(char);
        if (empty != null) {
          fileIdx += empty;
        } else {
          final square = '${kFiles[fileIdx]}${8 - rankIdx}';
          board[square] = char;
          fileIdx++;
        }
      }
    }
    return board;
  }
}
