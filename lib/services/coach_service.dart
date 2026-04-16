import 'package:chess/chess.dart' as ch;
import 'ai_service.dart';
import '../utils/error_handler.dart';

enum MoveQuality { blunder, mistake, inaccuracy, good, excellent, brilliant }

class CoachFeedback {
  final MoveQuality quality;
  final String message;
  final int evalDelta; // centipawns; positive = improved for player

  const CoachFeedback({
    required this.quality,
    required this.message,
    required this.evalDelta,
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
  /// Full tactical analysis of a player's move.
  ///
  /// [beforeFen]  — position BEFORE the move
  /// [from],[to]  — the move made
  /// [isPlayerWhite] — perspective to evaluate from
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

      // Execute the move
      final gameAfter = ch.Chess.fromFEN(beforeFen);
      gameAfter.move({'from': from, 'to': to});
      final afterFen = gameAfter.fen;
      final evalAfter = _evalForPlayer(afterFen, isPlayerWhite);

      final delta = evalAfter - evalBefore; // positive = good for player

      // ── Context analysis ────────────────────────────────────────────────
      final movingPiece = gameBefore.get(from);
      final capturedPiece = gameBefore.get(to);
      final pieceName = _pieceName(movingPiece?.type);
      final isCapture = capturedPiece != null;
      final isCheck = gameAfter.in_check;
      final isCheckmate = gameAfter.in_checkmate;
      final movesPlayed = gameBefore.history.length;

      // Detect tactics in the position AFTER the move
      final hangsAfter = _findHangingPieces(gameAfter, isPlayerWhite);
      final forkTarget = _detectFork(gameAfter, isPlayerWhite);
      final pinTarget = _detectPin(gameAfter, isPlayerWhite);

      // Also check for hanging pieces BEFORE the move (did we leave one?)
      final hangsBefore = _findHangingPieces(gameBefore, !isPlayerWhite);

      // Determine quality from delta thresholds
      final quality = _classifyDelta(delta, isCheckmate);

      // Build specific message
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

      return CoachFeedback(quality: quality, message: message, evalDelta: delta);
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
    // ── Checkmate ──
    if (isCheckmate) {
      return 'Checkmate! Brilliant finish — your $pieceName delivered the decisive blow on $to.';
    }

    // ── Blunders & mistakes — give specific reason ──
    if (quality == MoveQuality.blunder || quality == MoveQuality.mistake) {
      // Did we hang a piece?
      if (hangsAfter.isNotEmpty) {
        final target = hangsAfter.first;
        return '${quality == MoveQuality.blunder ? "Blunder" : "Mistake"}! '
            'Your piece on $target is now undefended — the opponent can capture it for free!';
      }
      if (hangsBefore.isNotEmpty) {
        // Player missed capturing a hanging piece
        final missed = hangsBefore.first;
        return '${quality == MoveQuality.blunder ? "Blunder" : "Mistake"}! '
            'You missed capturing the opponent\'s undefended piece on $missed.';
      }
      if (delta < -400) {
        return 'Blunder! This move loses significant material. '
            'Try to look for your opponent\'s threats before moving.';
      }
      return '${quality == MoveQuality.mistake ? "Mistake" : "Blunder"}! '
          'This move lost about ${(-delta / 100).toStringAsFixed(1)} pawns worth of advantage.';
    }

    // ── Inaccuracy ──
    if (quality == MoveQuality.inaccuracy) {
      if (movesPlayed < 10 && !isCapture) {
        return 'Inaccuracy. In the opening, try to develop your pieces towards the center.';
      }
      return 'Slight inaccuracy — there was a better option, but this move is still playable.';
    }

    // ── Good / Excellent / Brilliant ──
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

    // Opening development hints
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

  // ── Tactical detectors ────────────────────────────────────────────────────

  /// Returns squares of player's pieces that are hanging (attacked but undefended).
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

        // Check if any opponent piece attacks this square
        final isAttacked = game.attacked(oppColor, sqIdx);
        if (!isAttacked) continue;

        // Check if defended by own piece
        final isDefended = game.attacked(color, sqIdx);
        if (!isDefended) result.add(sq);
      }
    }
    return result;
  }

  /// Detects if the player's last move creates a fork opportunity.
  /// Returns the square being forked, or null.
  static String? _detectFork(ch.Chess game, bool isPlayerWhite) {
    try {
      final color = isPlayerWhite ? ch.Color.WHITE : ch.Color.BLACK;
      final oppColor = isPlayerWhite ? ch.Color.BLACK : ch.Color.WHITE;

      const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
      for (int rank = 1; rank <= 8; rank++) {
        for (final file in files) {
          final sq = '$file$rank';
          final piece = game.get(sq);
          if (piece == null || piece.color != color) continue;

          // Find all squares this piece attacks
          final attacked = <String>[];
          for (int r2 = 1; r2 <= 8; r2++) {
            for (final f2 in files) {
              final sq2 = '$f2$r2';
              if (sq2 == sq) continue;
              final target = game.get(sq2);
              final sq2Idx = ch.Chess.SQUARES[sq2];
              if (target != null &&
                  target.color == oppColor &&
                  sq2Idx != null &&
                  game.attacked(color, sq2Idx)) {
                attacked.add(sq2);
              }
            }
          }

          // Fork = attacking 2+ valuable pieces simultaneously
          final valuable = attacked.where((s) {
            final p = game.get(s);
            return p != null &&
                (p.type == ch.PieceType.QUEEN ||
                    p.type == ch.PieceType.ROOK ||
                    p.type == ch.PieceType.KING);
          }).toList();
          if (valuable.length >= 2) return sq;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Detects if the player's move creates a pin. Returns pinned square or null.
  static String? _detectPin(ch.Chess game, bool isPlayerWhite) {
    // Simplified: check if a sliding piece (bishop/rook/queen) is lined up
    // behind an opponent piece toward the king
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
                return firstOppSq; // pin detected
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
