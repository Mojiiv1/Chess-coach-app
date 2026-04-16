import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;
import '../utils/constants.dart';

class ChessBoard extends StatelessWidget {
  final String fen;
  final Set<String> selectedSquares;
  final Set<String> validMoveSquares;
  final void Function(String square) onSquareTap;
  final bool flipped; // true = board from black's perspective

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
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final squareSize = constraints.maxWidth / 8;
          return RepaintBoundary(
            child: CustomPaint(
              painter: _BoardPainter(
                fen: fen,
                selectedSquares: selectedSquares,
                validMoveSquares: validMoveSquares,
                squareSize: squareSize,
                flipped: flipped,
              ),
              child: Stack(
                children: _buildInteractiveSquares(squareSize),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildInteractiveSquares(double size) {
    final widgets = <Widget>[];
    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final displayRank = flipped ? rank : 7 - rank;
        final displayFile = flipped ? 7 - file : file;
        final squareName =
            '${kFiles[displayFile]}${kRanks[7 - displayRank]}';
        widgets.add(Positioned(
          left: file * size,
          top: rank * size,
          child: GestureDetector(
            onTap: () => onSquareTap(squareName),
            child: SizedBox(width: size, height: size),
          ),
        ));
      }
    }
    return widgets;
  }
}

class _BoardPainter extends CustomPainter {
  final String fen;
  final Set<String> selectedSquares;
  final Set<String> validMoveSquares;
  final double squareSize;
  final bool flipped;

  final Map<String, ch.Piece?> _board;

  _BoardPainter({
    required this.fen,
    required this.selectedSquares,
    required this.validMoveSquares,
    required this.squareSize,
    required this.flipped,
  }) : _board = _parseFen(fen);

  @override
  void paint(Canvas canvas, Size size) {
    _drawSquares(canvas);
    _drawCoordinates(canvas, size);
    _drawPieces(canvas);
  }

  void _drawSquares(Canvas canvas) {
    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final displayRank = flipped ? rank : 7 - rank;
        final displayFile = flipped ? 7 - file : file;
        final squareName =
            '${kFiles[displayFile]}${kRanks[7 - displayRank]}';

        final rect = Rect.fromLTWH(
          file * squareSize,
          rank * squareSize,
          squareSize,
          squareSize,
        );

        // Base color
        Color color = (rank + file) % 2 == 0 ? kLightSquare : kDarkSquare;

        // Highlight selected
        if (selectedSquares.contains(squareName)) {
          color = kSelectedSquare;
        }

        canvas.drawRect(rect, Paint()..color = color);

        // Valid move overlay
        if (validMoveSquares.contains(squareName)) {
          final hasOccupant = _board[squareName] != null;
          if (hasOccupant) {
            // Ring for captures
            final borderPaint = Paint()
              ..color = kValidMove
              ..style = PaintingStyle.stroke
              ..strokeWidth = squareSize * 0.1;
            canvas.drawCircle(rect.center, squareSize * 0.45, borderPaint);
          } else {
            // Dot for empty squares
            canvas.drawCircle(
              rect.center,
              squareSize * kValidMoveDotFraction,
              Paint()..color = kValidMove,
            );
          }
        }
      }
    }
  }

  void _drawCoordinates(Canvas canvas, Size size) {
    const textStyle = TextStyle(
      color: Colors.black54,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    // Rank numbers (left side)
    for (int i = 0; i < 8; i++) {
      final rankLabel = flipped ? '${i + 1}' : '${8 - i}';
      final tp = TextPainter(
        text: TextSpan(text: rankLabel, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, i * squareSize + 2));
    }

    // File letters (bottom)
    for (int i = 0; i < 8; i++) {
      final fileLabel = flipped ? kFiles[7 - i] : kFiles[i];
      final tp = TextPainter(
        text: TextSpan(text: fileLabel, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset(i * squareSize + squareSize - tp.width - 2,
              size.height - tp.height - 2));
    }
  }

  void _drawPieces(Canvas canvas) {
    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final displayRank = flipped ? rank : 7 - rank;
        final displayFile = flipped ? 7 - file : file;
        final squareName =
            '${kFiles[displayFile]}${kRanks[7 - displayRank]}';
        final piece = _board[squareName];
        if (piece == null) continue;

        final rect = Rect.fromLTWH(
          file * squareSize + squareSize * 0.05,
          rank * squareSize + squareSize * 0.05,
          squareSize * 0.9,
          squareSize * 0.9,
        );

        _drawPiece(canvas, rect, piece);
      }
    }
  }

  void _drawPiece(Canvas canvas, Rect rect, ch.Piece piece) {
    final isWhite = piece.color == ch.Color.WHITE;
    final pieceChar = piece.type.toLowerCase();

    // Outer circle (piece body)
    final bodyColor = isWhite ? Colors.white : const Color(0xFF2C2C2C);
    final borderColor = isWhite ? const Color(0xFF888888) : Colors.white38;

    canvas.drawCircle(
      rect.center,
      rect.width * 0.42,
      Paint()..color = bodyColor,
    );
    canvas.drawCircle(
      rect.center,
      rect.width * 0.42,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Piece letter
    final textColor = isWhite ? Colors.black87 : Colors.white;
    final label = _pieceLabel(pieceChar);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: rect.width * 0.45,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas,
        Offset(
          rect.center.dx - tp.width / 2,
          rect.center.dy - tp.height / 2,
        ));
  }

  String _pieceLabel(String type) {
    switch (type) {
      case 'p':
        return '♟';
      case 'n':
        return '♞';
      case 'b':
        return '♝';
      case 'r':
        return '♜';
      case 'q':
        return '♛';
      case 'k':
        return '♚';
      default:
        return type.toUpperCase();
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.fen != fen ||
      old.selectedSquares != selectedSquares ||
      old.validMoveSquares != validMoveSquares;

  static Map<String, ch.Piece?> _parseFen(String fen) {
    final board = <String, ch.Piece?>{};
    try {
      final game = ch.Chess.fromFEN(fen);
      const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
      for (int rank = 1; rank <= 8; rank++) {
        for (final file in files) {
          final sq = '$file$rank';
          board[sq] = game.get(sq);
        }
      }
    } catch (_) {}
    return board;
  }
}
