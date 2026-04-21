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
        id: map['id'] as String,
        fen: map['fen'] as String,
        gameMode: map['gameMode'] as String,
        difficulty: map['difficulty'] as String?,
        uciHistory: List<String>.from(map['uciHistory'] as List? ?? []),
        savedAt: DateTime.parse(map['savedAt'] as String),
        isComplete: map['isComplete'] as bool? ?? false,
      );
}
