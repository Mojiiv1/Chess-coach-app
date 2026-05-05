import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/saved_game.dart';

class SaveGameService {
  static const _boxName = 'chess_saved_games';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Future<void> saveGame(SavedGame game) async {
    try {
      await _box.put(game.id, game.toMap());
    } catch (e, st) {
      debugPrint('[SAVE] ERROR during _box.put: $e\n$st');
      rethrow;
    }
  }

  static List<SavedGame> getAllSavedGames() {
    final games = <SavedGame>[];
    for (final key in _box.keys) {
      final data = _box.get(key);
      if (data != null) {
        try {
          games.add(SavedGame.fromMap(data as Map));
        } catch (e, st) {
          debugPrint('[LIST] fromMap FAILED key=$key: $e\n$st');
        }
      }
    }
    games.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return games;
  }

  static Future<void> deleteGame(String id) async {
    await _box.delete(id);
  }

  static bool get hasSavedGames => _box.isNotEmpty;
}
