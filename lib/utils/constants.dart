import 'package:flutter/material.dart';

// Board colors
const Color kLightSquare = Color(0xFFF0D9B5);
const Color kDarkSquare = Color(0xFFB58863);
const Color kSelectedSquare = Color(0xFFFFFF00);
const Color kValidMoveColor = Color(0xFF44FF44);
const Color kLastMoveLight = Color(0xFFCDD16E);
const Color kLastMoveDark = Color(0xFFAAA23A);

// App colors
const Color kAppBackground = Color(0xFF1E1E2E);
const Color kAppSurface = Color(0xFF2A2A3E);
const Color kAppPrimary = Color(0xFF7C8BED);

/// Emoji chess pieces — keys match FEN piece letters (uppercase=white).
const Map<String, String> kPieceEmoji = {
  'P': '♙',
  'N': '♘',
  'B': '♗',
  'R': '♖',
  'Q': '♕',
  'K': '♔',
  'p': '♟',
  'n': '♞',
  'b': '♝',
  'r': '♜',
  'q': '♛',
  'k': '♚',
};

// Starting FEN
const String kStartingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

// Files and ranks
const List<String> kFiles = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
const List<String> kRanks = ['8', '7', '6', '5', '4', '3', '2', '1'];

// Valid move dot size as fraction of square size
const double kValidMoveDotFraction = 0.3;
