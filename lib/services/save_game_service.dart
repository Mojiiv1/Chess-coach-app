import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/saved_game.dart';

class SaveGameService {
  static const _boxName = 'chess_saved_games';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    debugPrint('[SAVE] init complete. Box "$_boxName" open. Length: ${_box.length}');
  }

  static Future<void> saveGame(SavedGame game) async {
    debugPrint('[SAVE] saveGame id=${game.id} fen=${game.fen.substring(0, 20)}... moves=${game.uciHistory.length}');
    debugPrint('[SAVE] Box length BEFORE: ${_box.length}. Keys: ${_box.keys.toList()}');
    try {
      await _box.put(game.id, game.toMap());
      debugPrint('[SAVE] Box length AFTER: ${_box.length}. Keys: ${_box.keys.toList()}');
    } catch (e, st) {
      debugPrint('[SAVE] ERROR during _box.put: $e\n$st');
      rethrow;
    }
  }

  static List<SavedGame> getAllSavedGames() {
    debugPrint('[LIST] getAllSavedGames. Box length: ${_box.length}. Keys: ${_box.keys.toList()}');
    final games = <SavedGame>[];
    for (final key in _box.keys) {
      final data = _box.get(key);
      debugPrint('[LIST] key=$key type=${data.runtimeType}');
      if (data != null) {
        try {
          games.add(SavedGame.fromMap(data as Map));
          debugPrint('[LIST] fromMap OK for key=$key');
        } catch (e, st) {
          debugPrint('[LIST] fromMap FAILED key=$key: $e\n$st');
        }
      }
    }
    games.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    debugPrint('[LIST] returning ${games.length} games');
    return games;
  }

  static Future<void> deleteGame(String id) async {
    await _box.delete(id);
  }

  static bool get hasSavedGames => _box.isNotEmpty;
}
