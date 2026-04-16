import 'package:logger/logger.dart';

final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 80,
    colors: false,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/// Validates a FEN string for basic correctness.
bool validateFen(String fen) {
  if (fen.isEmpty) return false;
  final parts = fen.trim().split(' ');
  if (parts.length < 4) return false;

  final ranks = parts[0].split('/');
  if (ranks.length != 8) return false;

  for (final rank in ranks) {
    int count = 0;
    for (final ch in rank.runes) {
      final c = String.fromCharCode(ch);
      if (RegExp(r'[1-8]').hasMatch(c)) {
        count += int.parse(c);
      } else if (RegExp(r'[pnbrqkPNBRQK]').hasMatch(c)) {
        count++;
      } else {
        return false;
      }
    }
    if (count != 8) return false;
  }

  final turn = parts[1];
  if (turn != 'w' && turn != 'b') return false;

  return true;
}

/// Returns a user-friendly error message and logs the underlying error.
String handleError(Object error, {String context = ''}) {
  _logger.e('Chess app error${context.isNotEmpty ? " [$context]" : ""}',
      error: error);
  if (error is FormatException) {
    return 'Invalid game data format. Please start a new game.';
  }
  if (error.toString().contains('illegal')) {
    return 'That move is not allowed. Try a different move.';
  }
  return 'Something went wrong. Please try again.';
}

void logInfo(String message) => _logger.i(message);
void logWarning(String message) => _logger.w(message);
void logDebug(String message) => _logger.d(message);
