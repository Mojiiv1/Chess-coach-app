import 'package:chess/chess.dart' as ch;
import '../models/move.dart' as app;

/// Wraps the chess.dart engine and exposes a clean API for the UI layer.
class GameService {
  late ch.Chess _game;
  final List<app.Move> _history = [];

  GameService() {
    _game = ch.Chess();
    print('🎯 GameService initialized');
    print('📊 Initial FEN: ${_game.fen}');
    print('⚙️ Turn: ${_game.turn}');
  }

  // ── State ──────────────────────────────────────────────────────────────────

  String get fen => _game.fen;

  String get turn =>
      _game.turn == ch.Color.WHITE ? 'white' : 'black';

  bool get isWhiteTurn => _game.turn == ch.Color.WHITE;

  bool get isGameOver => _game.game_over;

  List<app.Move> get history => List.unmodifiable(_history);

  // ── Move generation ────────────────────────────────────────────────────────

  /// Returns destination squares a piece on [square] can legally move to.
  /// Returns an empty list if the square is empty or has no legal moves.
  List<String> getLegalMoves(String square) {
    print('📍 Getting legal moves for $square');

    final rawMoves = _game.moves({'square': square, 'verbose': true});
    print('✅ Legal moves found: $rawMoves');

    if (rawMoves.isEmpty) return [];

    return rawMoves
        .map<String>((m) => (m as Map<String, dynamic>)['to'] as String)
        .toList();
  }

  // ── Move execution ─────────────────────────────────────────────────────────

  /// Attempts to make a move from [from] to [to].
  /// Defaults to queen promotion for pawns.
  /// Returns the [app.Move] if successful, null if illegal.
  app.Move? makeMove(String from, String to) {
    print('✅ Move executed: $from -> $to');

    final moveMap = <String, String>{'from': from, 'to': to};

    // Auto-promote to queen
    final piece = _game.get(from);
    if (piece != null &&
        piece.type == ch.PieceType.PAWN &&
        ((piece.color == ch.Color.WHITE && to[1] == '8') ||
            (piece.color == ch.Color.BLACK && to[1] == '1'))) {
      moveMap['promotion'] = 'q';
    }

    // Grab SAN before making the move (chess.dart computes it pre-move)
    final verboseMoves = _game.moves({'verbose': true});
    String notation = '$from$to';
    String? captured;
    for (final m in verboseMoves) {
      final mv = m as Map<String, dynamic>;
      if (mv['from'] == from && mv['to'] == to) {
        notation = mv['san'] as String;
        if (mv['captured'] != null) captured = mv['captured'].toString();
        break;
      }
    }

    final ok = _game.move(moveMap);
    if (!ok) return null;

    final move = app.Move(
      from: from,
      to: to,
      piece: piece?.type.name ?? '',
      notation: notation,
      isCapture: captured != null,
      timestamp: DateTime.now(),
    );
    _history.add(move);
    return move;
  }

  // ── Game-ending checks ─────────────────────────────────────────────────────

  bool isCheckmate() => _game.in_checkmate;

  bool isDraw() => _game.in_draw;

  bool isInCheck() => _game.in_check;

  bool isStalemate() => _game.in_stalemate;

  // ── Reset ──────────────────────────────────────────────────────────────────

  void reset() {
    _game = ch.Chess();
    _history.clear();
  }
}
