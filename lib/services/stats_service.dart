import 'package:hive_flutter/hive_flutter.dart';
import '../models/game_stats.dart';

/// Persists win/loss/draw counts in a local Hive box.
/// Call [init] once in main() before runApp.
class StatsService {
  static const _boxName = 'chess_stats';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static GameStats getStats() => GameStats(
        wins: _box.get('wins', defaultValue: 0) as int,
        losses: _box.get('losses', defaultValue: 0) as int,
        draws: _box.get('draws', defaultValue: 0) as int,
        lastResult: _box.get('last_result') as String?,
      );

  static Future<void> recordWin() async {
    final cur = _box.get('wins', defaultValue: 0) as int;
    await _box.put('wins', cur + 1);
    await _box.put('last_result', 'win');
  }

  static Future<void> recordLoss() async {
    final cur = _box.get('losses', defaultValue: 0) as int;
    await _box.put('losses', cur + 1);
    await _box.put('last_result', 'loss');
  }

  static Future<void> recordDraw() async {
    final cur = _box.get('draws', defaultValue: 0) as int;
    await _box.put('draws', cur + 1);
    await _box.put('last_result', 'draw');
  }

  static Future<void> reset() async {
    await _box.putAll({'wins': 0, 'losses': 0, 'draws': 0, 'last_result': null});
  }
}
