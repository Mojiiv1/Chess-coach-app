import 'package:hive_flutter/hive_flutter.dart';
import '../models/saved_game.dart';

class SaveGameService {
  static const _boxName = 'chess_saved_games';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Future<void> saveGame(SavedGame game) async {
    await _box.put(game.id, game.toMap());
  }

  static List<SavedGame> getAllSavedGames() {
    final games = <SavedGame>[];
    for (final key in _box.keys) {
      final data = _box.get(key);
      if (data != null) {
        try {
          games.add(SavedGame.fromMap(data as Map));
        } catch (_) {}
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
