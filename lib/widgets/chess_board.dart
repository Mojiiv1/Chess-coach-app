import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ChessBoard extends StatefulWidget {
  final String fen;
  final void Function(String algebraic)? onSquareTapped;
  final bool flipped;

  const ChessBoard({
    super.key,
    required this.fen,
    this.onSquareTapped,
    this.flipped = false,
  });

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  String? _selectedSquare;
  Set<String> _validMoves = {};

  // Parse FEN into a rank-file map: e.g. {'e1': 'K', 'e8': 'k', ...}
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
          final String square =
              '${kFiles[fileIdx]}${8 - rankIdx}';
          board[square] = char;
          fileIdx++;
        }
      }
    }
    return board;
  }

  void _onTap(String square) {
    setState(() {
      if (_selectedSquare == square) {
        // Deselect
        _selectedSquare = null;
        _validMoves = {};
      } else if (_validMoves.contains(square)) {
        // Move to valid destination — parent handles logic
        _selectedSquare = null;
        _validMoves = {};
        widget.onSquareTapped?.call(square);
      } else {
        _selectedSquare = square;
        _validMoves = {}; // Game logic will populate via parent
        widget.onSquareTapped?.call(square);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final boardState = _parseFen(widget.fen);

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final squareSize = constraints.maxWidth / 8;
          return Stack(
            children: [
              // Board squares
              Column(
                children: List.generate(8, (rowIdx) {
                  final rank = widget.flipped ? rowIdx + 1 : 8 - rowIdx;
                  return Row(
                    children: List.generate(8, (colIdx) {
                      final fileIdx =
                          widget.flipped ? 7 - colIdx : colIdx;
                      final square =
                          '${kFiles[fileIdx]}$rank';
                      final isLight = (fileIdx + rank) % 2 == 0;
                      final isSelected = _selectedSquare == square;
                      final isValidMove = _validMoves.contains(square);
                      final piece = boardState[square];

                      return _ChessSquare(
                        key: ValueKey(square),
                        size: squareSize,
                        isLight: isLight,
                        isSelected: isSelected,
                        isValidMove: isValidMove,
                        piece: piece,
                        showCoords: true,
                        file: colIdx == 0 ? '$rank' : null,
                        rank: rowIdx == 7 ? kFiles[fileIdx] : null,
                        onTap: () => _onTap(square),
                      );
                    }),
                  );
                }),
              ),
            ],
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
  final String? file; // rank label on left edge
  final String? rank; // file label on bottom edge
  final bool showCoords;
  final VoidCallback onTap;

  const _ChessSquare({
    super.key,
    required this.size,
    required this.isLight,
    required this.isSelected,
    required this.isValidMove,
    required this.onTap,
    this.piece,
    this.file,
    this.rank,
    this.showCoords = true,
  });

  Color get _baseColor => isLight ? kLightSquare : kDarkSquare;
  Color get _coordColor => isLight ? kDarkSquare : kLightSquare;

  @override
  Widget build(BuildContext context) {
    Color bgColor = _baseColor;
    if (isSelected) bgColor = kSelectedSquare;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            // Background
            Container(color: bgColor),

            // Valid move indicator
            if (isValidMove)
              Center(
                child: Container(
                  width: size * kValidMoveDotFraction,
                  height: size * kValidMoveDotFraction,
                  decoration: BoxDecoration(
                    color: piece != null
                        ? kValidMoveColor.withValues(alpha: 0.6)
                        : kValidMoveColor.withValues(alpha: 0.75),
                    shape: piece != null
                        ? BoxShape.rectangle
                        : BoxShape.circle,
                  ),
                ),
              ),

            // Piece
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

            // Rank label (left edge)
            if (showCoords && file != null)
              Positioned(
                top: 2,
                left: 3,
                child: Text(
                  file!,
                  style: TextStyle(
                    fontSize: size * 0.18,
                    fontWeight: FontWeight.bold,
                    color: _coordColor,
                  ),
                ),
              ),

            // File label (bottom edge)
            if (showCoords && rank != null)
              Positioned(
                bottom: 2,
                right: 3,
                child: Text(
                  rank!,
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
