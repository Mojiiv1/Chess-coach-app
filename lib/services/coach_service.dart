import 'package:chess/chess.dart' as ch;
import 'package:flutter/foundation.dart';
import 'ai_service.dart';
import 'stockfish_service.dart';
import '../utils/error_handler.dart';

enum MoveQuality { blunder, mistake, inaccuracy, good, excellent, brilliant }

class CoachFeedback {
  final MoveQuality quality;
  final String message;
  final int evalDelta;
  final String? suggestion; // Better move in SAN, only for bad moves
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
      final isCapture = capturedPiece != null;
      final isCheck = gameAfter.in_check;
      final isCheckmate = gameAfter.in_checkmate;
      final movesPlayed = gameBefore.history.length;

      final hangsAfter = _detectHangingPieces(gameAfter, isPlayerWhite);
      const String? forkTarget = null;
      final pinTarget = _detectPin(gameAfter, isPlayerWhite);
      final hangsBefore = _detectMissedCaptures(gameBefore, isPlayerWhite);

      final quality = _classifyDelta(delta, isCheckmate);

      final message = _buildMessage(
        quality: quality,
        gameBefore: gameBefore,
        gameAfter: gameAfter,
        from: from,
        to: to,
        isCapture: isCapture,
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

  // ── Async analysis (Stockfish-backed) ────────────────────────────────────

  /// Evaluates the move using Stockfish at depth 8.
  /// Falls back to [analyzeMove] if Stockfish is unavailable or times out.
  static Future<CoachFeedback> analyzeMoveAsync({
    required String beforeFen,
    required String from,
    required String to,
    required bool isPlayerWhite,
  }) async {
    if (!validateFen(beforeFen)) {
      return const CoachFeedback(
        quality: MoveQuality.good,
        message: 'Keep playing!',
        evalDelta: 0,
      );
    }

    try {
      final gameBefore = ch.Chess.fromFEN(beforeFen);
      final gameAfter  = ch.Chess.fromFEN(beforeFen);
      gameAfter.move({'from': from, 'to': to});
      final afterFen = gameAfter.fen;

      // Sequential calls — the service only supports one in-flight request;
      // concurrent calls would cancel the first via the pending-completer swap.
      final stockfish   = StockfishService.instance;
      final resultBefore = await stockfish.evaluatePosition(beforeFen, depth: 8);
      final resultAfter  = await stockfish.evaluatePosition(afterFen,  depth: 8);

      if (resultBefore == null || resultAfter == null) {
        debugPrint('[CoachAsync] FALLBACK — Stockfish returned null '
            '(resultBefore=${resultBefore?.evalCentipawns} '
            'resultAfter=${resultAfter?.evalCentipawns})');
        return analyzeMove(
          beforeFen: beforeFen, from: from, to: to,
          isPlayerWhite: isPlayerWhite);
      }

      // Stockfish score cp is always from the side-to-move's POV.
      // After the move the turn flips, so negate evalAfter to stay in
      // the mover's perspective for both numbers.
      final evalBefore = resultBefore.evalCentipawns;
      final evalAfter  = -resultAfter.evalCentipawns;
      final delta      = evalAfter - evalBefore;

      final isCheckmate = gameAfter.in_checkmate;
      final quality     = _classifyDelta(delta, isCheckmate);

      // Suggestion: Stockfish's best move on beforeFen (free — already computed).
      String? suggestion;
      if (delta < -10) {
        final bestUci   = resultBefore.bestMove;
        final playedUci = '$from$to';
        if (bestUci.isNotEmpty && bestUci != playedUci) {
          suggestion = _uciToSan(bestUci, beforeFen);
        }
      }

      final movingPiece   = gameBefore.get(from);
      final capturedPiece = gameBefore.get(to);
      final isCapture   = capturedPiece != null;
      final isCheck     = gameAfter.in_check;
      final movesPlayed = gameBefore.history.length;

      final hangsAfter  = _detectHangingPieces(gameAfter, isPlayerWhite);
      final pinTarget   = _detectPin(gameAfter, isPlayerWhite);
      final hangsBefore = _detectMissedCaptures(gameBefore, isPlayerWhite);

      // ── LPDO: Loose Pieces Drop Off ───────────────────────────────────────
      // Primary signal: piece is currently attacked and undefended.
      final valuableHangs = hangsAfter
          .where((sq) => _pieceValue(gameAfter.get(sq)?.type) >= 320)
          .toList();

      // Secondary signal: opponent's Stockfish best-response would capture
      // one of our valuable pieces. Only checked when nothing is already
      // immediately hanging, to avoid double-counting the same piece.
      String? loosePieceMessage;
      final oppBestUci = resultAfter.bestMove;
      int capValue = 0;
      if (valuableHangs.isEmpty && oppBestUci.length >= 4) {
        final oppTo = oppBestUci.substring(2, 4);
        final targetPiece = gameAfter.get(oppTo);
        final ourColor = isPlayerWhite ? ch.Color.WHITE : ch.Color.BLACK;
        if (targetPiece != null && targetPiece.color == ourColor) {
          capValue = _pieceValue(targetPiece.type);
          if (capValue >= 320) {
            final oppBestSan = _uciToSan(oppBestUci, afterFen) ?? oppBestUci;
            loosePieceMessage =
                'Inaccuracy. Watch out — your ${_pieceName(targetPiece.type)} '
                'on $oppTo is vulnerable. Opponent can play $oppBestSan next.';
          }
        }
      }

      debugPrint('[CoachLoose] oppBest=$oppBestUci capValue=$capValue '
          '→ loose=${loosePieceMessage != null}');

      final effectiveQuality =
          (quality.index >= MoveQuality.good.index &&
                  (valuableHangs.isNotEmpty || loosePieceMessage != null))
              ? MoveQuality.inaccuracy
              : quality;

      final String message;
      if (loosePieceMessage != null && quality.index >= MoveQuality.good.index) {
        message = loosePieceMessage;
      } else {
        message = _buildMessage(
          quality: effectiveQuality,
          gameBefore: gameBefore,
          gameAfter: gameAfter,
          from: from,
          to: to,
          isCapture: isCapture,
          isCheck: isCheck,
          isCheckmate: isCheckmate,
          movesPlayed: movesPlayed,
          hangsAfter: effectiveQuality != quality ? valuableHangs : hangsAfter,
          hangsBefore: hangsBefore,
          forkTarget: null,
          pinTarget: pinTarget,
          delta: delta,
          isPlayerWhite: isPlayerWhite,
        );
      }

      final tip = _getTip(
        movingPiece?.type, to, movesPlayed, isCapture, isCheck, isCheckmate);

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
        quality: effectiveQuality,
        message: message,
        evalDelta: delta,
        suggestion: suggestion,
        tip: tip,
        tactics: tactics,
      );
    } catch (e) {
      handleError(e, context: 'analyzeMoveAsync');
      return analyzeMove(
        beforeFen: beforeFen, from: from, to: to,
        isPlayerWhite: isPlayerWhite);
    }
  }

  // ── Classification ────────────────────────────────────────────────────────

  static MoveQuality _classifyDelta(int delta, bool isCheckmate) {
    if (isCheckmate) return MoveQuality.brilliant;
    if (delta > 200)   return MoveQuality.brilliant;
    if (delta > 30)    return MoveQuality.excellent;
    if (delta >= -10)  return MoveQuality.good;
    if (delta >= -50)  return MoveQuality.inaccuracy;
    if (delta >= -150) return MoveQuality.mistake;
    return MoveQuality.blunder;
  }

  // ── Message builder (priority: P1 concrete → P2 structural → P3 generic) ──

  static String _buildMessage({
    required MoveQuality quality,
    required ch.Chess gameBefore,
    required ch.Chess gameAfter,
    required String from,
    required String to,
    required bool isCapture,
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
    final movingPiece = gameBefore.get(from);
    final capturedPiece = gameBefore.get(to);
    final pieceName = _pieceName(movingPiece?.type);
    final capturedName = _pieceName(capturedPiece?.type);
    final prefix = _qualityPrefix(quality);
    final isBad = quality.index <= MoveQuality.inaccuracy.index;

    debugPrint('[Coach] quality=$quality isBad=$isBad hangsAfter=${hangsAfter.length} '
        'hangsBefore=${hangsBefore.length} piece=${movingPiece?.type} moves=$movesPlayed');

    // Always first: checkmate
    if (isCheckmate) {
      return 'Checkmate! Brilliant finish — your $pieceName delivered the decisive blow on $to.';
    }

    // ── PRIORITY 1: Concrete material events ─────────────────────────────

    // P1a: Own piece is now hanging — always check regardless of quality,
    // because any move can incidentally leave a piece en prise.
    if (hangsAfter.isNotEmpty) {
      final sq = hangsAfter.first;
      final hung = gameAfter.get(sq);
      final name = _pieceName(hung?.type);
      final badPrefix = isBad ? '$prefix ' : 'Watch out! ';
      return '${badPrefix}You hung your $name on $sq — it\'s attacked and undefended.';
    }

    // P1b & P1c: Only meaningful for bad moves
    if (isBad) {
      // P1b: Unfavorable capture — gave up a more valuable piece
      if (isCapture) {
        final ourValue = _pieceValue(movingPiece?.type);
        final theirValue = _pieceValue(capturedPiece?.type);
        if (ourValue > theirValue + 150 && delta < -80) {
          return '$prefix You gave up your $pieceName for their $capturedName — an unfavorable trade.';
        }
      }

      // P1c: Missed capturing an undefended opponent piece
      if (hangsBefore.isNotEmpty) {
        final sq = hangsBefore.first;
        final missed = gameBefore.get(sq);
        final name = _pieceName(missed?.type);
        return '$prefix You missed capturing the undefended $name on $sq.';
      }
    }

    // ── PRIORITY 2: Structural observations ──────────────────────────────
    // These fire for ALL quality levels — the simple evaluator can't detect
    // positional principles like early-queen or repeated-piece development.

    // P2a: Queen out too early — fire even if eval says "good"
    if (movingPiece?.type == ch.PieceType.QUEEN && movesPlayed < 8) {
      final p2prefix = isBad ? '$prefix ' : '';
      return '${p2prefix}Your queen came out too early — opponents can chase it and gain time.';
    }

    // P2b: Same minor piece moved twice in the opening
    if (isBad &&
        movesPlayed < 12 &&
        (movingPiece?.type == ch.PieceType.KNIGHT ||
            movingPiece?.type == ch.PieceType.BISHOP)) {
      final whiteStart = ['b1', 'g1', 'c1', 'f1'];
      final blackStart = ['b8', 'g8', 'c8', 'f8'];
      final startSquares = isPlayerWhite ? whiteStart : blackStart;
      if (!startSquares.contains(from)) {
        return '$prefix You moved the same piece twice in the opening, losing a tempo.';
      }
    }

    // P2c: Kingside pawn pushed — weakens king shelter (only warn for bad moves)
    if (isBad && movingPiece?.type == ch.PieceType.PAWN) {
      final weakSquares = isPlayerWhite ? ['g2', 'h2'] : ['g7', 'h7'];
      if (weakSquares.contains(from)) {
        return '$prefix You advanced your kingside pawn — this can weaken your king\'s shelter.';
      }
    }

    // ── PRIORITY 3: Positive feedback and generic fallbacks ───────────────

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

    // Generic bad-move fallback (P1/P2 fired nothing concrete)
    if (quality == MoveQuality.blunder || quality == MoveQuality.mistake) {
      if (delta < -400) {
        return 'Blunder! This move loses significant material. Look for your opponent\'s threats before moving.';
      }
      return '$prefix This move lost about ${(-delta / 100).toStringAsFixed(1)} pawns of advantage.';
    }

    if (quality == MoveQuality.inaccuracy) {
      return 'Slight inaccuracy — there was a better option, but this move is still playable.';
    }

    // Opening development tips (P3 generic, good+ moves only)
    if (movesPlayed < 6) {
      final centerFiles = ['d', 'e'];
      if (centerFiles.contains(to[0])) {
        return 'Good! Developing toward the center early gives you more space.';
      }
      if (movingPiece?.type == ch.PieceType.KNIGHT ||
          movingPiece?.type == ch.PieceType.BISHOP) {
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

  // ── Suggestion: best alternative in SAN notation ─────────────────────────

  static String? _findSuggestion(
      String beforeFen, String playedFrom, String playedTo, bool isPlayerWhite) {
    try {
      final game = ch.Chess.fromFEN(beforeFen);
      final moves = game.generate_moves();
      if (moves.length <= 1) return null;

      int bestEval = -999999;
      ch.Move? bestMove;

      for (final move in moves) {
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

      // Convert to SAN via a clone — never mutate the real game state
      final sanClone = ch.Chess.fromFEN(beforeFen);
      return sanClone.move_to_san(bestMove);
    } catch (_) {
      return null;
    }
  }

  // ── Priority 1 detectors ──────────────────────────────────────────────────

  /// Returns squares of own pieces that are attacked and fully undefended.
  static List<String> _detectHangingPieces(ch.Chess game, bool forWhite) {
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

  /// Returns squares of opponent's undefended pieces the mover could capture.
  static List<String> _detectMissedCaptures(ch.Chess game, bool forWhite) {
    return _detectHangingPieces(game, !forWhite);
  }

  // ── Tip: contextual opening/midgame principle (P3 fallback) ──────────────

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
      return tactics;
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

    if (movingPiece?.type == ch.PieceType.PAWN) {
      final rank = int.tryParse(to[1]) ?? 0;
      final isPromoThreat = isPlayerWhite ? rank == 7 : rank == 2;
      if (isPromoThreat) tactics.add('Promotion');
    }

    return tactics;
  }

  // ── Pin detection ─────────────────────────────────────────────────────────

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

  static String _qualityPrefix(MoveQuality quality) {
    switch (quality) {
      case MoveQuality.blunder:
        return 'Blunder!';
      case MoveQuality.mistake:
        return 'Mistake!';
      case MoveQuality.inaccuracy:
        return 'Inaccuracy.';
      default:
        return '';
    }
  }

  static int _pieceValue(ch.PieceType? type) {
    if (type == ch.PieceType.PAWN) return 100;
    if (type == ch.PieceType.KNIGHT) return 320;
    if (type == ch.PieceType.BISHOP) return 330;
    if (type == ch.PieceType.ROOK) return 500;
    if (type == ch.PieceType.QUEEN) return 900;
    if (type == ch.PieceType.KING) return 20000;
    return 0;
  }

  static String _pieceName(ch.PieceType? type) {
    if (type == null) return 'piece';
    if (type == ch.PieceType.PAWN) return 'pawn';
    if (type == ch.PieceType.KNIGHT) return 'knight';
    if (type == ch.PieceType.BISHOP) return 'bishop';
    if (type == ch.PieceType.ROOK) return 'rook';
    if (type == ch.PieceType.QUEEN) return 'queen';
    if (type == ch.PieceType.KING) return 'king';
    return 'piece';
  }

  /// Converts a UCI move string (e.g. "e2e4") to SAN (e.g. "e4") for display.
  static String? _uciToSan(String uci, String fen) {
    try {
      if (uci.length < 4) return null;
      final from  = uci.substring(0, 2);
      final to    = uci.substring(2, 4);
      final game  = ch.Chess.fromFEN(fen);
      final match = game.generate_moves().where(
        (m) => m.fromAlgebraic == from && m.toAlgebraic == to,
      ).toList();
      if (match.isEmpty) return null;
      return game.move_to_san(match.first);
    } catch (_) {
      return null;
    }
  }
}
