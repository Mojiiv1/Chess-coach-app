import 'package:flutter/material.dart';

// Board colors
const Color kLightSquare = Color(0xFFF0D9B5);
const Color kDarkSquare = Color(0xFFB58863);
const Color kSelectedSquare = Color(0xFFFFFF00);
const Color kValidMove = Color(0x8844FF44);

// App theme colors
const Color kBackground = Color(0xFF1E1E2E);
const Color kSurface = Color(0xFF2A2A3E);
const Color kPrimaryAccent = Color(0xFF7C8BED);
const Color kSecondaryAccent = Color(0xFF9D7FEA);

// Board layout
const List<String> kFiles = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
const List<String> kRanks = ['8', '7', '6', '5', '4', '3', '2', '1'];

const String kStartingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const double kValidMoveDotFraction = 0.3;
