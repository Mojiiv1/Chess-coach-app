import 'package:chess/chess.dart' as ch;
import 'ai_service.dart';
import '../utils/error_handler.dart';

enum MoveQuality { blunder, mistake, inaccuracy, good, excellent, brilliant }

class CoachFeedback {
  final MoveQuality quality;
  final String message;
  final int evalDelta;
  final String? suggestion; // Better UCI move (e.g. "d2d4"), only for bad moves
  final String tip;         // Contextual principle tip
  final List<String> tactics; // e.g. ["Check", "Pin", "Capture"]

  const CoachFeedback({
    required this.quality,
    required this.message,
    required this.evalDelta,
    this.suggestion,
    this.tip = '',
    this.tactics = const [],
  });

  String get qualityLabel {
    switch (quality) {
      case MoveQuality.brilliant:
        return '✨ Brilliant!';
      case MoveQuality.excellent:
        return '⭐ Excellent';
      case MoveQuality.good:
        return '👍 Good';
      case MoveQuality.inaccuracy:
        return '⚠️ Inaccuracy';
      case MoveQuality.mistake:
        return '❌ Mistake';
      case MoveQuality.blunder:
        return '💀 Blunder';
    }
  }
}

class CoachService {
  static CoachFeedback analyzeMove({
    required String beforeFen,
    required String from,
    required String to,
    required bool isPlayerWhite,
  }) {
    try {
      if (!validateFen(beforeFen)) {
        return const CoachFeedback(
          quality: MoveQuality.good,
          message: 'Keep playing!',
          evalDelta: 0,
        );
      }

      final gameBefore = ch.Chess.fromFEN(beforeFen);
      final evalBefore = _evalForPlayer(beforeFen, isPlayerWhite);

      final gameAfter = ch.Chess.fromFEN(beforeFen);
      gameAfter.move({'from': from, 'to': to});
      final afterFen = gameAfter.fen;
      final evalAfter = _evalForPlayer(afterFen, isPlayerWhite);

      final delta = evalAfter - evalBefore;

      final movingPiece = gameBefore.get(from);
      final capturedPiece = gameBefore.get(to);
      final pieceName = _pieceName(movingPiece?.type);
      final isCapture = capturedPiece != null;
      final isCheck = gameAfter.in_check;
      final isCheckmate = gameAfter.in_checkmate;
      final movesPlayed = gameBefore.history.length;

      final hangsAfter = _findHangingPieces(gameAfter, isPlayerWhite);
      const String? forkTarget = null;
      final pinTarget = _detectPin(gameAfter, isPlayerWhite);
      final hangsBefore = _findHangingPieces(gameBefore, !isPlayerWhite);

      final quality = _classifyDelta(delta, isCheckmate);

      final message = _buildMessage(
        quality: quality,
        pieceName: pieceName,
        from: from,
        to: to,
        isCapture: isCapture,
        capturedName: _pieceName(capturedPiece?.type),
        isCheck: isCheck,
        isCheckmate: isCheckmate,
        movesPlayed: movesPlayed,
        hangsAfter: hangsAfter,
        hangsBefore: hangsBefore,
        forkTarget: forkTarget,
        pinTarget: pinTarget,
        delta: delta,
        isPlayerWhite: isPlayerWhite,
      );

      // Suggestion: only compute for inaccuracy or worse (keep web fast)
      final suggestion = delta < -30
          ? _findSuggestion(beforeFen, from, to, isPlayerWhite)
          : null;

      final tip = _getTip(
        movingPiece?.type,
        to,
        movesPlayed,
        isCapture,
        isCheck,
        isCheckmate,
      );

      final tactics = _detectTactics(
        gameAfter: gameAfter,
        to: to,
        movingPiece: movingPiece,
        isPlayerWhite: isPlayerWhite,
        isCheck: isCheck,
        isCheckmate: isCheckmate,
        isCapture: isCapture,
        capturedPiece: capturedPiece,
        pinTarget: pinTarget,
      );

      return CoachFeedback(
        quality: quality,
        message: message,
        evalDelta: delta,
        suggestion: suggestion,
        tip: tip,
        tactics: tactics,
      );
    } catch (e) {
      handleError(e, context: 'analyzeMove');
      return const CoachFeedback(
        quality: MoveQuality.good,
        message: 'Keep playing!',
        evalDelta: 0,
      );
    }
  }

  // ── Classification ─────────────────────────────────────────────────────────

  static MoveQuality _classifyDelta(int delta, bool isCheckmate) {
    if (isCheckmate) return MoveQuality.brilliant;
    if (delta > 200) return MoveQuality.brilliant;
    if (delta > 30) return MoveQuality.excellent;
    if (delta >= -20) return MoveQuality.good;
    if (delta >= -80) return MoveQuality.inaccuracy;
    if (delta >= -250) return MoveQuality.mistake;
    return MoveQuality.blunder;
  }

  // ── Message builder ───────────────────────────────────────────────────────

  static String _buildMessage({
    required MoveQuality quality,
    required String pieceName,
    required String from,
    required String to,
    required bool isCapture,
    required String capturedName,
    required bool isCheck,
    required bool isCheckmate,
    required int movesPlayed,
    required List<String> hangsAfter,
    required List<String> hangsBefore,
    required String? forkTarget,
    required String? pinTarget,
    required int delta,
    required bool isPlayerWhite,
  }) {
    if (isCheckmate) {
      return 'Checkmate! Brilliant finish — your $pieceName delivered the decisive blow on $to.';
    }

    if (quality == MoveQuality.blunder || quality == MoveQuality.mistake) {
      if (hangsAfter.isNotEmpty) {
        final target = hangsAfter.first;
        return '${quality == MoveQuality.blunder ? "Blunder" : "Mistake"}! '
            'Your piece on $target is now undefended — the opponent can capture it for free!';
      }
      if (hangsBefore.isNotEmpty) {
        final missed = hangsBefore.first;
        return '${quality == MoveQuality.blunder ? "Blunder" : "Mistake"}! '
            'You missed capturing the opponent\'s undefended piece on $missed.';
      }
      if (delta < -400) {
        return 'Blunder! This move loses significant material. '
            'Look for your opponent\'s threats before moving.';
      }
      return '${quality == MoveQuality.mistake ? "Mistake" : "Blunder"}! '
          'This move lost about ${(-delta / 100).toStringAsFixed(1)} pawns worth of advantage.';
    }

    if (quality == MoveQuality.inaccuracy) {
      if (movesPlayed < 10 && !isCapture) {
        return 'Inaccuracy. In the opening, try to develop your pieces toward the center.';
      }
      return 'Slight inaccuracy — there was a better option, but this move is still playable.';
    }

    if (isCheck) {
      return 'Good move! Your $pieceName on $to gives check, forcing the opponent to respond.';
    }

    if (isCapture) {
      if (quality == MoveQuality.brilliant || quality == MoveQuality.excellent) {
        return 'Excellent capture! Taking the $capturedName on $to gains material advantage.';
      }
      return 'Good capture of the $capturedName on $to.';
    }

    if (forkTarget != null && quality.index >= MoveQuality.excellent.index) {
      return 'Excellent! Your $pieceName on $to creates a fork — attacking multiple pieces at once!';
    }

    if (pinTarget != null && quality.index >= MoveQuality.excellent.index) {
      return 'Excellent! Your move creates a pin on $pinTarget — restricting the opponent\'s options.';
    }

    if (movesPlayed < 6) {
      final centerFiles = ['d', 'e'];
      if (centerFiles.contains(to[0])) {
        return 'Good! Developing toward the center early gives you more space.';
      }
      if (pieceName == 'Knight' || pieceName == 'Bishop') {
        return 'Good development! Getting your $pieceName into play early is strong opening strategy.';
      }
    }

    if (movesPlayed >= 6 && movesPlayed < 14) {
      if (to == 'g1' || to == 'c1' || to == 'g8' || to == 'c8') {
        return 'Good! Castling keeps your king safe and connects your rooks.';
      }
    }

    if (quality == MoveQuality.brilliant) {
      return 'Brilliant move! Your $pieceName to $to gains a significant advantage.';
    }
    if (quality == MoveQuality.excellent) {
      return 'Excellent! Moving the $pieceName to $to improves your position noticeably.';
    }
    return 'Good move — your $pieceName is well-placed on $to.';
  }

  // ── Suggestion: best alternative from the pre-move position ───────────────

  /// Returns the UCI string of the best alternative the player could have played.
  /// Only called when delta < -30 (inaccuracy or worse) to keep web performance.
  static String? _findSuggestion(
      String beforeFen, String playedFrom, String playedTo, bool isPlayerWhite) {
    try {
      final game = ch.Chess.fromFEN(beforeFen);
      final moves = game.generate_moves();
      if (moves.length <= 1) return null;

      int bestEval = -999999;
      ch.Move? bestMove;

      for (final move in moves) {
        // Skip the move the player already made
        if (move.fromAlgebraic == playedFrom &&
            move.toAlgebraic == playedTo) {
          continue;
        }

        game.move(move);
        final eval = isPlayerWhite
            ? AIService.evaluatePosition(game.fen)
            : -AIService.evaluatePosition(game.fen);
        game.undo_move();

        if (eval > bestEval) {
          bestEval = eval;
          bestMove = move;
        }
      }

      if (bestMove == null) return null;
      return '${bestMove.fromAlgebraic}${bestMove.toAlgebraic}';
    } catch (_) {
      return null;
    }
  }

  // ── Tip: contextual opening/midgame principle ──────────────────────────────

  static String _getTip(
    ch.PieceType? type,
    String to,
    int movesPlayed,
    bool isCapture,
    bool isCheck,
    bool isCheckmate,
  ) {
    if (isCheckmate) return '';
    if (isCheck) return 'Checks force responses — use them to gain tempo.';

    final rank = int.tryParse(to[1]) ?? 0;

    if (movesPlayed < 8) {
      // Opening principles
      if (type == ch.PieceType.QUEEN) {
        return "Don't develop the queen too early — it can be chased by opponent pieces.";
      }
      if (type == ch.PieceType.KNIGHT || type == ch.PieceType.BISHOP) {
        return 'Develop knights and bishops before rooks and queen in the opening.';
      }
      if (type == ch.PieceType.PAWN) {
        final centerFiles = ['d', 'e'];
        if (centerFiles.contains(to[0])) {
          return 'Central pawns control space and open lines for your pieces.';
        }
        return 'Avoid moving too many pawns in the opening — develop your pieces first.';
      }
      if (type == ch.PieceType.KING) {
        return 'Castle early to keep your king safe and connect your rooks.';
      }
      if (type == ch.PieceType.ROOK) {
        return 'Rooks are best on open files — place them after the center opens up.';
      }
    }

    if (movesPlayed >= 8 && movesPlayed < 20) {
      // Middlegame tips
      if (type == ch.PieceType.ROOK) {
        return 'Rooks belong on open or semi-open files where they control space.';
      }
      if (type == ch.PieceType.KNIGHT) {
        return 'Knights are strongest in the center — outposts on d5/e5 are ideal.';
      }
      if (type == ch.PieceType.BISHOP) {
        return 'Bishops thrive on long diagonals with open lines.';
      }
      if (type == ch.PieceType.PAWN && rank >= 5) {
        return 'Advanced pawns create threats — support them with your pieces.';
      }
    }

    if (movesPlayed >= 20) {
      // Endgame tips
      if (type == ch.PieceType.KING) {
        return 'In the endgame, activate your king — it becomes a powerful attacker.';
      }
      if (type == ch.PieceType.PAWN) {
        return 'Passed pawns are powerful in the endgame — push them toward promotion.';
      }
    }

    return '';
  }

  // ── Tactics detection ─────────────────────────────────────────────────────

  static List<String> _detectTactics({
    required ch.Chess gameAfter,
    required String to,
    required ch.Piece? movingPiece,
    required bool isPlayerWhite,
    required bool isCheck,
    required bool isCheckmate,
    required bool isCapture,
    required ch.Piece? capturedPiece,
    required String? pinTarget,
  }) {
    final tactics = <String>[];

    if (isCheckmate) {
      tactics.add('Checkmate');
      return tactics; // No need to add other tags
    }
    if (isCheck) tactics.add('Check');
    if (isCapture && capturedPiece != null) {
      const valuablePieces = [
        ch.PieceType.QUEEN,
        ch.PieceType.ROOK,
        ch.PieceType.BISHOP,
        ch.PieceType.KNIGHT,
      ];
      if (valuablePieces.contains(capturedPiece.type)) {
        tactics.add('Capture');
      }
    }
    if (pinTarget != null) tactics.add('Pin');

    // Promotion threat: pawn on 7th rank (white) or 2nd rank (black)
    if (movingPiece?.type == ch.PieceType.PAWN) {
      final rank = int.tryParse(to[1]) ?? 0;
      final isPromoThreat = isPlayerWhite ? rank == 7 : rank == 2;
      if (isPromoThreat) tactics.add('Promotion');
    }

    return tactics;
  }

  // ── Tactical detectors ────────────────────────────────────────────────────

  static List<String> _findHangingPieces(ch.Chess game, bool forWhite) {
    final color = forWhite ? ch.Color.WHITE : ch.Color.BLACK;
    final oppColor = forWhite ? ch.Color.BLACK : ch.Color.WHITE;
    final result = <String>[];

    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    for (int rank = 1; rank <= 8; rank++) {
      for (final file in files) {
        final sq = '$file$rank';
        final piece = game.get(sq);
        if (piece == null || piece.color != color) continue;
        if (piece.type == ch.PieceType.KING) continue;

        final sqIdx = ch.Chess.SQUARES[sq];
        if (sqIdx == null) continue;

        final isAttacked = game.attacked(oppColor, sqIdx);
        if (!isAttacked) continue;
        final isDefended = game.attacked(color, sqIdx);
        if (!isDefended) result.add(sq);
      }
    }
    return result;
  }

  static String? _detectPin(ch.Chess game, bool isPlayerWhite) {
    try {
      final color = isPlayerWhite ? ch.Color.WHITE : ch.Color.BLACK;
      final oppColor = isPlayerWhite ? ch.Color.BLACK : ch.Color.WHITE;

      const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
      const directions = [
        [1, 0], [-1, 0], [0, 1], [0, -1],
        [1, 1], [1, -1], [-1, 1], [-1, -1],
      ];

      for (int rank = 1; rank <= 8; rank++) {
        for (int fi = 0; fi < 8; fi++) {
          final sq = '${files[fi]}$rank';
          final piece = game.get(sq);
          if (piece == null || piece.color != color) continue;

          final isBishop = piece.type == ch.PieceType.BISHOP;
          final isRook = piece.type == ch.PieceType.ROOK;
          final isQueen = piece.type == ch.PieceType.QUEEN;
          if (!isBishop && !isRook && !isQueen) continue;

          for (final dir in directions) {
            final isDiag = dir[0] != 0 && dir[1] != 0;
            if (isBishop && !isDiag) continue;
            if (isRook && isDiag) continue;

            int r = rank + dir[1];
            int f = fi + dir[0];
            String? firstOppSq;

            while (r >= 1 && r <= 8 && f >= 0 && f < 8) {
              final s = '${files[f]}$r';
              final p = game.get(s);
              if (p == null) {
                r += dir[1];
                f += dir[0];
                continue;
              }
              if (p.color == oppColor && firstOppSq == null) {
                firstOppSq = s;
              } else if (p.color == oppColor &&
                  firstOppSq != null &&
                  p.type == ch.PieceType.KING) {
                return firstOppSq;
              } else {
                break;
              }
              r += dir[1];
              f += dir[0];
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  static int _evalForPlayer(String fen, bool isWhite) {
    final raw = AIService.evaluatePosition(fen);
    return isWhite ? raw : -raw;
  }

  static String _pieceName(ch.PieceType? type) {
    if (type == null) return 'piece';
    if (type == ch.PieceType.PAWN) return 'Pawn';
    if (type == ch.PieceType.KNIGHT) return 'Knight';
    if (type == ch.PieceType.BISHOP) return 'Bishop';
    if (type == ch.PieceType.ROOK) return 'Rook';
    if (type == ch.PieceType.QUEEN) return 'Queen';
    if (type == ch.PieceType.KING) return 'King';
    return 'piece';
  }
}
