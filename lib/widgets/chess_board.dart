import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;
import '../utils/constants.dart';

// Map FEN piece letter → asset path (used when PNG files are present).
// White pieces are uppercase letters, black are lowercase.
const Map<String, String> _pieceAsset = {
  'K': 'assets/chess_pieces/white_king.png',
  'Q': 'assets/chess_pieces/white_queen.png',
  'R': 'assets/chess_pieces/white_rook.png',
  'B': 'assets/chess_pieces/white_bishop.png',
  'N': 'assets/chess_pieces/white_knight.png',
  'P': 'assets/chess_pieces/white_pawn.png',
  'k': 'assets/chess_pieces/black_king.png',
  'q': 'assets/chess_pieces/black_queen.png',
  'r': 'assets/chess_pieces/black_rook.png',
  'b': 'assets/chess_pieces/black_bishop.png',
  'n': 'assets/chess_pieces/black_knight.png',
  'p': 'assets/chess_pieces/black_pawn.png',
};

// Unicode symbol for each piece type (lowercase = piece type key)
const Map<String, String> _pieceSymbol = {
  'k': '♚',
  'q': '♛',
  'r': '♜',
  'b': '♝',
  'n': '♞',
  'p': '♟',
};

class ChessBoard extends StatelessWidget {
  final String fen;
  final Set<String> selectedSquares;
  final Set<String> validMoveSquares;
  final void Function(String square) onSquareTap;
  final bool flipped;

  const ChessBoard({
    super.key,
    required this.fen,
    required this.selectedSquares,
    required this.validMoveSquares,
    required this.onSquareTap,
    this.flipped = false,
  });

  @override
  Widget build(BuildContext context) {
    final board = _parseFen(fen);

    return AspectRatio(
      aspectRatio: 1,
      child: Column(
        children: List.generate(8, (rankIdx) {
          return Expanded(
            child: Row(
              children: List.generate(8, (fileIdx) {
                final displayRank = flipped ? rankIdx : 7 - rankIdx;
                final displayFile = flipped ? 7 - fileIdx : fileIdx;
                final squareName =
                    '${kFiles[displayFile]}${kRanks[7 - displayRank]}';
                final piece = board[squareName];

                final isLight = (rankIdx + fileIdx) % 2 == 0;
                final isSelected = selectedSquares.contains(squareName);
                final isValidMove = validMoveSquares.contains(squareName);
                final hasOccupant = piece != null;

                // Show rank label on left edge, file label on bottom edge
                final showRankLabel = fileIdx == 0;
                final showFileLabel = rankIdx == 7;
                final rankLabel = flipped ? '${rankIdx + 1}' : '${8 - rankIdx}';
                final fileLabel =
                    flipped ? kFiles[7 - fileIdx] : kFiles[fileIdx];

                Color squareColor;
                if (isSelected) {
                  squareColor = kSelectedSquare;
                } else {
                  squareColor = isLight ? kLightSquare : kDarkSquare;
                }

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSquareTap(squareName),
                    child: Container(
                      color: squareColor,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ── Valid-move indicator ──────────────────────────
                          if (isValidMove)
                            Center(
                              child: hasOccupant
                                  ? _CaptureRing()
                                  : _MoveDot(),
                            ),

                          // ── Piece ─────────────────────────────────────────
                          if (piece != null)
                            Center(
                              child: RepaintBoundary(
                                key: ValueKey('piece_$squareName'),
                                child: _PieceWidget(piece: piece),
                              ),
                            ),

                          // ── Coordinate labels ─────────────────────────────
                          if (showRankLabel)
                            Positioned(
                              top: 1,
                              left: 2,
                              child: Text(
                                rankLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isLight
                                      ? kDarkSquare
                                      : kLightSquare,
                                ),
                              ),
                            ),
                          if (showFileLabel)
                            Positioned(
                              bottom: 1,
                              right: 2,
                              child: Text(
                                fileLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isLight
                                      ? kDarkSquare
                                      : kLightSquare,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  static Map<String, ch.Piece?> _parseFen(String fen) {
    final board = <String, ch.Piece?>{};
    try {
      final game = ch.Chess.fromFEN(fen);
      for (int rank = 1; rank <= 8; rank++) {
        for (final file in kFiles) {
          final sq = '$file$rank';
          board[sq] = game.get(sq);
        }
      }
    } catch (_) {}
    return board;
  }
}

// ── Piece widget ──────────────────────────────────────────────────────────────

class _PieceWidget extends StatelessWidget {
  final ch.Piece piece;
  const _PieceWidget({required this.piece});

  @override
  Widget build(BuildContext context) {
    final isWhite = piece.color == ch.Color.WHITE;
    final typeKey = piece.type.toLowerCase(); // 'p','n','b','r','q','k'
    // FEN letter: uppercase for white, lowercase for black
    final fenLetter = isWhite ? typeKey.toUpperCase() : typeKey;
    final assetPath = _pieceAsset[fenLetter];

    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.maxWidth * 0.82;

      // Try PNG asset first; fall back to styled unicode symbol.
      if (assetPath != null) {
        return _PieceImage(path: assetPath, size: size);
      }
      return _PieceSymbol(
          symbol: _pieceSymbol[typeKey] ?? '?',
          isWhite: isWhite,
          size: size);
    });
  }
}

/// Loads a PNG asset; if it fails, falls back to the symbol widget.
class _PieceImage extends StatelessWidget {
  final String path;
  final double size;
  const _PieceImage({required this.path, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) {
        // PNG file missing — derive piece info from path and fall back.
        final isWhite = path.contains('white_');
        final symbol = _symbolFromPath(path);
        return _PieceSymbol(symbol: symbol, isWhite: isWhite, size: size);
      },
    );
  }

  static String _symbolFromPath(String path) {
    for (final entry in _pieceSymbol.entries) {
      if (path.contains(entry.key == 'k'
          ? 'king'
          : entry.key == 'q'
              ? 'queen'
              : entry.key == 'r'
                  ? 'rook'
                  : entry.key == 'b'
                      ? 'bishop'
                      : entry.key == 'n'
                          ? 'knight'
                          : 'pawn')) {
        return entry.value;
      }
    }
    return '?';
  }
}

/// Styled unicode chess symbol — used when no PNG is available.
class _PieceSymbol extends StatelessWidget {
  final String symbol;
  final bool isWhite;
  final double size;
  const _PieceSymbol(
      {required this.symbol, required this.isWhite, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isWhite ? const Color(0xFFF5F0E8) : const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
        ],
        border: Border.all(
          color: isWhite ? const Color(0xFF8B7355) : const Color(0xFF6B7FD4),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: size * 0.56,
            color: isWhite ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8F0),
            height: 1.0,
            shadows: isWhite
                ? null
                : [
                    const Shadow(
                        color: Colors.white24,
                        blurRadius: 2,
                        offset: Offset(0, 1))
                  ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Move indicators ───────────────────────────────────────────────────────────

class _MoveDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final d = c.maxWidth * kValidMoveDotFraction * 2;
      return Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kValidMove,
        ),
      );
    });
  }
}

class _CaptureRing extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final size = c.maxWidth * 0.9;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kValidMove, width: c.maxWidth * 0.1),
          color: Colors.transparent,
        ),
      );
    });
  }
}
