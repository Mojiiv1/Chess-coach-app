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

// ── SVG chess piece shapes (shared between white/black) ────────────────────

const String _pPaths = // pawn
    '<circle cx="22.5" cy="10.5" r="5"/>'
    '<path d="M20 15.5 C18 21 16 25 15 30 L30 30 C29 25 27 21 25 15.5 Z"/>'
    '<rect x="11" y="30" width="23" height="6" rx="2"/>';

const String _rPaths = // rook
    '<rect x="11" y="8" width="6" height="7"/>'
    '<rect x="19.5" y="8" width="5" height="7"/>'
    '<rect x="28" y="8" width="6" height="7"/>'
    '<rect x="14" y="15" width="17" height="15"/>'
    '<rect x="11" y="30" width="23" height="6" rx="2"/>';

const String _nPaths = // knight
    '<path d="M15 30 L15 27 C12 24 11 20 12 15 C13 11 16 8 20 8'
    ' L20 12 C22 9 26 8 28 11 C31 14 31 19 29 23 C27 26 25 28 24 30 Z"/>'
    '<path d="M20 8 L18 4 L23 8 Z"/>'
    '<circle cx="23" cy="14" r="1.5" fill="none"/>'
    '<rect x="11" y="30" width="23" height="6" rx="2"/>';

const String _bPaths = // bishop
    '<circle cx="22.5" cy="9" r="4.5"/>'
    '<line x1="22.5" y1="4" x2="22.5" y2="14" stroke-width="1"/>'
    '<line x1="18" y1="9" x2="27" y2="9" stroke-width="1"/>'
    '<path d="M16 30 Q16 15 22.5 13 Q29 15 29 30 Z"/>'
    '<rect x="11" y="30" width="23" height="6" rx="2"/>';

const String _qPaths = // queen
    '<circle cx="13" cy="9" r="3"/>'
    '<circle cx="22.5" cy="7.5" r="3"/>'
    '<circle cx="32" cy="9" r="3"/>'
    '<path d="M11 13 Q13 9 22.5 10.5 Q32 9 34 13 L32 28 L13 28 Z"/>'
    '<rect x="11" y="28" width="23" height="8" rx="2"/>';

const String _kPaths = // king
    '<rect x="21" y="5" width="3" height="12"/>'
    '<rect x="17" y="8" width="11" height="3"/>'
    '<path d="M14 19 Q22.5 15 31 19 L30 30 L15 30 Z"/>'
    '<rect x="11" y="30" width="23" height="6" rx="2"/>';

String _svg(String paths, bool white) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 45 45">'
    '<g fill="${white ? "#fff" : "#111"}" stroke="${white ? "#000" : "#ccc"}"'
    ' stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round">'
    '$paths</g></svg>';

/// SVG chess pieces — keys match FEN piece letters (uppercase=white).
final Map<String, String> kPieceSVG = {
  'P': _svg(_pPaths, true),
  'p': _svg(_pPaths, false),
  'R': _svg(_rPaths, true),
  'r': _svg(_rPaths, false),
  'N': _svg(_nPaths, true),
  'n': _svg(_nPaths, false),
  'B': _svg(_bPaths, true),
  'b': _svg(_bPaths, false),
  'Q': _svg(_qPaths, true),
  'q': _svg(_qPaths, false),
  'K': _svg(_kPaths, true),
  'k': _svg(_kPaths, false),
};

// Starting FEN
const String kStartingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

// Files and ranks
const List<String> kFiles = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
const List<String> kRanks = ['8', '7', '6', '5', '4', '3', '2', '1'];

// Valid move dot size as fraction of square size
const double kValidMoveDotFraction = 0.3;
