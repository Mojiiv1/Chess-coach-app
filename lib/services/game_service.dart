import 'package:chess/chess.dart' as ch;
import '../models/move.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

class GameService {
  ch.Chess _chess = ch.Chess.fromFEN(kStartingFen);
  final List<Move> _history = [];
  final List<String> _uciHistory = [];

  String get fen => _chess.fen;
  String get turn => _chess.turn == ch.Color.WHITE ? 'white' : 'black';
  List<Move> get history => List.unmodifiable(_history);
  List<String> get uciHistory => List.unmodifiable(_uciHistory);

  bool get isCheckmate => _chess.in_checkmate;
  bool get isDraw => _chess.in_draw;
  bool get isStalemate => _chess.in_stalemate;
  bool get isInCheck => _chess.in_check;
  bool get isGameOver => isCheckmate || isDraw || isStalemate;

  /// Returns valid destination squares for the piece on [square].
  Set<String> getLegalMoves(String square) {
    try {
      return _chess
          .generate_moves()
          .where((m) => m.fromAlgebraic == square)
          .map((m) => m.toAlgebraic)
          .toSet();
    } catch (e) {
      handleError(e, context: 'getLegalMoves');
      return {};
    }
  }

  /// Makes a move. Returns the [Move] object or null if illegal.
  Move? makeMove(String from, String to) {
    try {
      // Handle pawn promotion: always promote to queen
      final movingPiece = _chess.get(from);
      Map<String, String> moveMap = {'from': from, 'to': to};
      if (movingPiece?.type == ch.PieceType.PAWN) {
        final toRank = int.tryParse(to[1]) ?? 0;
        if (toRank == 8 || toRank == 1) {
          moveMap['promotion'] = 'q';
        }
      }

      final result = _chess.move(moveMap);
      if (!result) return null;

      // Get SAN via verbose history
      String san = to;
      bool isCapture = false;
      final verbose = _chess.getHistory({'verbose': true});
      if (verbose.isNotEmpty) {
        final last = verbose.last as Map;
        san = last['san']?.toString() ?? to;
        isCapture = last['captured'] != null;
      }

      final uci = from + to + (moveMap['promotion'] ?? '');
      _uciHistory.add(uci);

      final move = Move(
        from: from,
        to: to,
        piece: movingPiece?.type.toLowerCase() ?? '',
        notation: san,
        isCapture: isCapture,
      );
      _history.add(move);
      logDebug('Move made: $uci  FEN: ${_chess.fen}');
      return move;
    } catch (e) {
      handleError(e, context: 'makeMove $from$to');
      return null;
    }
  }

  void reset() {
    _chess = ch.Chess.fromFEN(kStartingFen);
    _history.clear();
    _uciHistory.clear();
  }

  void loadFromFen(String fen, List<String> uciHistory) {
    _chess = ch.Chess.fromFEN(fen);
    _history.clear();
    _uciHistory
      ..clear()
      ..addAll(uciHistory);
  }

  /// Returns the piece type at [square] (lowercase), or null if empty.
  String? pieceAt(String square) =>
      _chess.get(square)?.type.toLowerCase();
}
