class Move {
  final String from;
  final String to;
  final String piece;
  final String notation;
  final bool isCapture;
  final DateTime timestamp;

  Move({
    required this.from,
    required this.to,
    required this.piece,
    required this.notation,
    required this.isCapture,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'piece': piece,
        'notation': notation,
        'isCapture': isCapture,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Move.fromJson(Map<String, dynamic> json) => Move(
        from: json['from'] as String,
        to: json['to'] as String,
        piece: json['piece'] as String,
        notation: json['notation'] as String,
        isCapture: json['isCapture'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  @override
  String toString() => notation;
}
