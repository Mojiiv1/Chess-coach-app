import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// A pure display widget. All selection/move state is managed by the parent.
class ChessBoard extends StatelessWidget {
  final String fen;
  final String? selectedSquare;
  final Set<String> validMoves;
  final void Function(String algebraic) onSquareTapped;
  final bool flipped;

  const ChessBoard({
    super.key,
    required this.fen,
    required this.onSquareTapped,
    this.selectedSquare,
    this.validMoves = const {},
    this.flipped = false,
  });

  Map<String, String> _parseFen(String fen) {
    final Map<String, String> board = {};
    final String position = fen.split(' ').first;
    final List<String> ranks = position.split('/');

    for (int rankIdx = 0; rankIdx < 8; rankIdx++) {
      final String rankStr = ranks[rankIdx];
      int fileIdx = 0;
      for (final ch in rankStr.runes) {
        final char = String.fromCharCode(ch);
        final int? empty = int.tryParse(char);
        if (empty != null) {
          fileIdx += empty;
        } else {
          board['${kFiles[fileIdx]}${8 - rankIdx}'] = char;
          fileIdx++;
        }
      }
    }
    return board;
  }

  @override
  Widget build(BuildContext context) {
    final boardState = _parseFen(fen);

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final squareSize = constraints.maxWidth / 8;
          return Column(
            children: List.generate(8, (rowIdx) {
              final rank = flipped ? rowIdx + 1 : 8 - rowIdx;
              return Row(
                children: List.generate(8, (colIdx) {
                  final fileIdx = flipped ? 7 - colIdx : colIdx;
                  final square = '${kFiles[fileIdx]}$rank';
                  final isLight = (fileIdx + rank) % 2 == 0;
                  final piece = boardState[square];

                  return _ChessSquare(
                    key: ValueKey(square),
                    size: squareSize,
                    isLight: isLight,
                    isSelected: selectedSquare == square,
                    isValidMove: validMoves.contains(square),
                    piece: piece,
                    rankLabel: colIdx == 0 ? '$rank' : null,
                    fileLabel: rowIdx == 7 ? kFiles[fileIdx] : null,
                    onTap: () => onSquareTapped(square),
                  );
                }),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ChessSquare extends StatelessWidget {
  final double size;
  final bool isLight;
  final bool isSelected;
  final bool isValidMove;
  final String? piece;
  final String? rankLabel; // shown top-left (rank number)
  final String? fileLabel; // shown bottom-right (file letter)
  final VoidCallback onTap;

  const _ChessSquare({
    super.key,
    required this.size,
    required this.isLight,
    required this.isSelected,
    required this.isValidMove,
    required this.onTap,
    this.piece,
    this.rankLabel,
    this.fileLabel,
  });

  Color get _baseColor => isLight ? kLightSquare : kDarkSquare;
  Color get _coordColor => isLight ? kDarkSquare : kLightSquare;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? kSelectedSquare : _baseColor;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Container(color: bgColor),

            // Valid move dot (circle) or capture ring (piece present)
            if (isValidMove)
              Center(
                child: piece != null
                    ? _CaptureRing(size: size)
                    : _MoveDot(size: size),
              ),

            // Piece glyph
            if (piece != null)
              Center(
                child: Text(
                  kPieceSymbols[piece] ?? '',
                  style: TextStyle(
                    fontSize: size * 0.72,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),

            // Rank number (top-left of leftmost column)
            if (rankLabel != null)
              Positioned(
                top: 2,
                left: 3,
                child: Text(
                  rankLabel!,
                  style: TextStyle(
                    fontSize: size * 0.18,
                    fontWeight: FontWeight.bold,
                    color: _coordColor,
                  ),
                ),
              ),

            // File letter (bottom-right of bottom row)
            if (fileLabel != null)
              Positioned(
                bottom: 2,
                right: 3,
                child: Text(
                  fileLabel!,
                  style: TextStyle(
                    fontSize: size * 0.18,
                    fontWeight: FontWeight.bold,
                    color: _coordColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoveDot extends StatelessWidget {
  final double size;
  const _MoveDot({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * kValidMoveDotFraction,
      height: size * kValidMoveDotFraction,
      decoration: BoxDecoration(
        color: kValidMoveColor.withValues(alpha: 0.75),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CaptureRing extends StatelessWidget {
  final double size;
  const _CaptureRing({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.9,
      height: size * 0.9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: kValidMoveColor.withValues(alpha: 0.7),
          width: size * 0.08,
        ),
      ),
    );
  }
}
