import 'package:hive_flutter/hive_flutter.dart';
import '../models/game_stats.dart';
import '../utils/error_handler.dart';

class StatsService {
  static const _boxName = 'chess_stats';
  static const _winsKey = 'wins';
  static const _lossesKey = 'losses';
  static const _drawsKey = 'draws';
  static const _lastResultKey = 'last_result';

  static late Box _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  static GameStats getStats() {
    try {
      final wins = _validated(_box.get(_winsKey, defaultValue: 0));
      final losses = _validated(_box.get(_lossesKey, defaultValue: 0));
      final draws = _validated(_box.get(_drawsKey, defaultValue: 0));
      final lastResult = _box.get(_lastResultKey) as String?;
      return GameStats(
          wins: wins, losses: losses, draws: draws, lastResult: lastResult);
    } catch (e) {
      handleError(e, context: 'getStats');
      return const GameStats();
    }
  }

  static Future<void> recordWin() => _record(_winsKey, 'win');
  static Future<void> recordLoss() => _record(_lossesKey, 'loss');
  static Future<void> recordDraw() => _record(_drawsKey, 'draw');

  static Future<void> reset() async {
    try {
      await _box.clear();
    } catch (e) {
      handleError(e, context: 'resetStats');
    }
  }

  static Future<void> _record(String key, String result) async {
    try {
      final current = _validated(_box.get(key, defaultValue: 0));
      await _box.put(key, current + 1);
      await _box.put(_lastResultKey, result);
    } catch (e) {
      handleError(e, context: 'record $key');
    }
  }

  /// Ensures stored value is a non-negative integer.
  static int _validated(dynamic value) {
    if (value is int && value >= 0) return value;
    return 0;
  }
}
