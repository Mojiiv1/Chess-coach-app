import 'package:chess/chess.dart' as ch;
import '../models/move.dart';

enum MoveQuality { blunder, mistake, inaccuracy, good, excellent }

class CoachFeedback {
  final MoveQuality quality;
  final String message;
  final int evalDelta; // centipawns, positive = better for the side that moved

  const CoachFeedback({
    required this.quality,
    required this.message,
    required this.evalDelta,
  });

  String get qualityLabel {
    switch (quality) {
      case MoveQuality.blunder:
        return '?? Blunder';
      case MoveQuality.mistake:
        return '? Mistake';
      case MoveQuality.inaccuracy:
        return '?! Inaccuracy';
      case MoveQuality.good:
        return '✓ Good';
      case MoveQuality.excellent:
        return '!! Excellent';
    }
  }

  String get qualityEmoji {
    switch (quality) {
      case MoveQuality.blunder:
        return '💀';
      case MoveQuality.mistake:
        return '😬';
      case MoveQuality.inaccuracy:
        return '🤔';
      case MoveQuality.good:
        return '👍';
      case MoveQuality.excellent:
        return '⭐';
    }
  }
}

class CoachService {
  /// Analyses a move and returns coach feedback.
  /// [beforeFen] = position before the move
  /// [move] = the move that was made
  /// [isPlayerWhite] = whether the coaching is for the white player
  static CoachFeedback analyzeMove({
    required String beforeFen,
    required Move move,
    required bool isPlayerWhite,
  }) {
    final before = ch.Chess.fromFEN(beforeFen);

    // Reconstruct the position after the move
    final after = ch.Chess.fromFEN(beforeFen);
    after.move({'from': move.from, 'to': move.to, 'promotion': 'q'});

    // Evaluate both positions from the moving player's perspective
    final evalBefore = _evaluate(before, isPlayerWhite);
    final evalAfter = _evaluate(after, isPlayerWhite);
    final delta = evalAfter - evalBefore;

    // Check special move properties
    final isCapture = move.isCapture;
    final isCheck = after.in_check;
    final isCheckmate = after.in_checkmate;
    final isPawnMove = move.piece.toLowerCase() == 'pawn';
    final isCenterSquare =
        ['d4', 'd5', 'e4', 'e5'].contains(move.to);

    // Checkmate overrides everything
    if (isCheckmate) {
      return const CoachFeedback(
        quality: MoveQuality.excellent,
        message: 'Checkmate! Brilliant finish!',
        evalDelta: 9999,
      );
    }

    // Determine quality from eval delta
    final quality = _qualityFromDelta(delta);

    // Build contextual message
    final message = _buildMessage(
      quality: quality,
      isCapture: isCapture,
      isCheck: isCheck,
      isPawnMove: isPawnMove,
      isCenterSquare: isCenterSquare,
      move: move,
      delta: delta,
    );

    return CoachFeedback(quality: quality, message: message, evalDelta: delta);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static MoveQuality _qualityFromDelta(int delta) {
    if (delta < -300) return MoveQuality.blunder;
    if (delta < -100) return MoveQuality.mistake;
    if (delta < -20) return MoveQuality.inaccuracy;
    if (delta <= 20) return MoveQuality.good;
    return MoveQuality.excellent;
  }

  static String _buildMessage({
    required MoveQuality quality,
    required bool isCapture,
    required bool isCheck,
    required bool isPawnMove,
    required bool isCenterSquare,
    required Move move,
    required int delta,
  }) {
    // Quality-driven messages first
    if (quality == MoveQuality.blunder) {
      return 'That was a blunder — you lost significant material!';
    }
    if (quality == MoveQuality.mistake) {
      return 'Mistake — consider if there was a better square.';
    }

    // Context-driven messages for good/excellent moves
    if (isCheck && isCapture) return 'Check with capture — great combination!';
    if (isCheck) return 'Good — checking the king puts pressure on your opponent!';
    if (isCapture) {
      return quality == MoveQuality.excellent
          ? 'Excellent capture — great material gain!'
          : 'Good capture!';
    }
    if (isCenterSquare) {
      return 'Good — controlling the center is key in the opening!';
    }
    if (isPawnMove) return 'Control the center with your pawns.';
    if (quality == MoveQuality.inaccuracy) {
      return 'Inaccuracy — there may be a stronger move here.';
    }
    if (quality == MoveQuality.excellent) return 'Excellent move!';
    return 'Solid move.';
  }

  /// Material evaluation in centipawns, from [isWhite]'s perspective.
  static int _evaluate(ch.Chess chess, bool isWhite) {
    if (chess.in_checkmate) {
      return chess.turn == (isWhite ? ch.Color.WHITE : ch.Color.BLACK)
          ? -99999
          : 99999;
    }
    if (chess.in_draw) return 0;

    const values = {'p': 100, 'n': 300, 'b': 300, 'r': 500, 'q': 900, 'k': 0};
    int score = 0;
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    for (final file in files) {
      for (int rank = 1; rank <= 8; rank++) {
        final piece = chess.get('$file$rank');
        if (piece == null) continue;
        final v = values[piece.type.name.toLowerCase()] ?? 0;
        final isOurs = isWhite
            ? piece.color == ch.Color.WHITE
            : piece.color == ch.Color.BLACK;
        score += isOurs ? v : -v;
      }
    }
    return score;
  }
}
