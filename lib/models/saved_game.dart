class SavedGame {
  final String id;
  final String fen;
  final String gameMode; // 'playerVsAI' | 'localMultiplayer'
  final String? difficulty;
  final List<String> uciHistory;
  final DateTime savedAt;
  final bool isComplete;

  const SavedGame({
    required this.id,
    required this.fen,
    required this.gameMode,
    this.difficulty,
    required this.uciHistory,
    required this.savedAt,
    required this.isComplete,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'fen': fen,
        'gameMode': gameMode,
        'difficulty': difficulty,
        'uciHistory': uciHistory,
        'savedAt': savedAt.toIso8601String(),
        'isComplete': isComplete,
      };

  factory SavedGame.fromMap(Map<dynamic, dynamic> map) => SavedGame(
        id: (map['id'] ?? '').toString(),
        fen: (map['fen'] ?? '').toString(),
        gameMode: (map['gameMode'] ?? 'playerVsAI').toString(),
        difficulty: map['difficulty']?.toString(),
        uciHistory: _parseStringList(map['uciHistory']),
        savedAt: _parseDateTime(map['savedAt']),
        isComplete: map['isComplete'] == true,
      );

  static List<String> _parseStringList(dynamic val) {
    if (val is List) return val.map((e) => e.toString()).toList();
    return [];
  }

  static DateTime _parseDateTime(dynamic val) {
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }
}
