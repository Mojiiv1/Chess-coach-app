import 'package:flutter/material.dart';

// Board colors
const Color kLightSquare = Color(0xFFF0D9B5);
const Color kDarkSquare = Color(0xFFB58863);
const Color kSelectedSquare = Color(0xFFFFFF00);
const Color kValidMove = Color(0x8844FF44);

// App theme colors
const Color kBackground = Color(0xFF0F1419);
const Color kSurface = Color(0xFF1A1F2E);
const Color kPrimaryAccent = Color(0xFF6B5BFF);
const Color kSecondaryAccent = Color(0xFF00D4FF);
const Color kAppAccent = Color(0xFFFF6B5B);

// Status colors
const Color kGoodMove = Color(0xFF66BB6A);
const Color kBadMove = Color(0xFFEF5350);
const Color kNeutralMove = Color(0xFF42A5F5);

// Board layout
const List<String> kFiles = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
const List<String> kRanks = ['8', '7', '6', '5', '4', '3', '2', '1'];

const String kStartingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const double kValidMoveDotFraction = 0.3;
