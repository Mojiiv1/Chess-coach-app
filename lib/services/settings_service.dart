import 'package:hive_flutter/hive_flutter.dart';

class SettingsService {
  static const _boxName = 'chess_settings';
  static const _coachKey = 'coachFeedbackEnabled';
  static const _hintsKey = 'moveHintsEnabled';
  static const _soundKey = 'soundEffectsEnabled';

  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static bool get coachFeedbackEnabled =>
      _box.get(_coachKey, defaultValue: true) as bool;

  static Future<void> setCoachFeedbackEnabled(bool value) =>
      _box.put(_coachKey, value);

  static bool get moveHintsEnabled =>
      _box.get(_hintsKey, defaultValue: true) as bool;

  static Future<void> setMoveHintsEnabled(bool value) =>
      _box.put(_hintsKey, value);

  static bool get soundEffectsEnabled =>
      _box.get(_soundKey, defaultValue: true) as bool;

  static Future<void> setSoundEffectsEnabled(bool value) =>
      _box.put(_soundKey, value);
}
