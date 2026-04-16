import 'dart:async';
import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../services/ai_service.dart';
import '../services/coach_service.dart';
import '../services/stats_service.dart';
import '../models/move.dart';
import '../utils/constants.dart';
import '../widgets/chess_board.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _game = GameService();

  String? _selectedSquare;
  Set<String> _validMoves = {};

  String _difficulty = 'intermediate';
  CoachFeedback? _lastFeedback;
  bool _aiThinking = false;
  bool _gameOverShown = false;
  int _evalBar = 0; // centipawns, white-positive

  // Scroll controller for move history
  final _historyScrollCtrl = ScrollController();

  @override
  void dispose() {
    _historyScrollCtrl.dispose();
    super.dispose();
  }

  // ── Square tapping ─────────────────────────────────────────────────────────

  void _onSquareTapped(String square) {
    if (_aiThinking || _game.isGameOver) return;
    if (_game.turn != 'white') return;

    if (_selectedSquare == null) {
      // First tap — select a piece
      final moves = _game.getLegalMoves(square);
      if (moves.isNotEmpty) {
        setState(() {
          _selectedSquare = square;
          _validMoves = moves;
        });
      }
    } else if (_selectedSquare == square) {
      // Tap same square — deselect
      setState(() {
        _selectedSquare = null;
        _validMoves = {};
      });
    } else if (_validMoves.contains(square)) {
      // Valid destination — execute the move
      final from = _selectedSquare!;
      setState(() {
        _selectedSquare = null;
        _validMoves = {};
      });
      _executePlayerMove(from, square);
    } else {
      // Tap a different square — re-select if it has legal moves
      final moves = _game.getLegalMoves(square);
      setState(() {
        _selectedSquare = moves.isNotEmpty ? square : null;
        _validMoves = moves;
      });
    }
  }

  void _executePlayerMove(String from, String to) {
    final beforeFen = _game.fen;
    final move = _game.makeMove(from, to);
    if (move == null) return;

    // Evaluate position and get coach feedback synchronously
    final feedback = CoachService.analyzeMove(
      beforeFen: beforeFen,
      from: from,
      to: to,
      isPlayerWhite: true,
    );
    final newEval = AIService.evaluatePosition(_game.fen);

    // Single setState to reflect the completed player move
    setState(() {
      _lastFeedback = feedback;
      _evalBar = newEval;
      _aiThinking = !_game.isGameOver; // lock board for AI
    });

    _scrollHistoryToEnd();

    if (_game.isGameOver) {
      _handleGameOver();
      return;
    }

    Timer(const Duration(milliseconds: 700), _executeAIMove);
  }

  Future<void> _executeAIMove() async {
    if (!mounted) return;

    try {
      // Run AI on a Future so the 700ms delay frame can render first
      final (uciMove, _) = await Future(
        () => AIService.getAIMove(_game.fen, _difficulty, _game.uciHistory),
      );

      if (!mounted) return;

      if (uciMove.isNotEmpty) {
        final from = uciMove.substring(0, 2);
        final to = uciMove.substring(2, 4);
        _game.makeMove(from, to);
      }

      final newEval = AIService.evaluatePosition(_game.fen);

      setState(() {
        _aiThinking = false;
        _evalBar = newEval;
      });

      _scrollHistoryToEnd();
      if (_game.isGameOver) _handleGameOver();
    } catch (e) {
      // Always unblock the board even if AI fails
      if (mounted) setState(() => _aiThinking = false);
    }
  }

  void _handleGameOver() {
    if (_gameOverShown) return;
    _gameOverShown = true;

    String result;
    String title;
    String subtitle;

    if (_game.isCheckmate) {
      if (_game.turn == 'white') {
        // White to move but in checkmate → black won
        result = 'loss';
        title = 'Checkmate!';
        subtitle = 'The AI wins this time. Keep practicing!';
      } else {
        result = 'win';
        title = 'Checkmate!';
        subtitle = 'You won! Excellent play!';
      }
    } else {
      result = 'draw';
      title = 'Draw!';
      subtitle = _game.isStalemate ? 'Stalemate.' : 'The game is a draw.';
    }

    // Record stats
    Future(() async {
      if (result == 'win') await StatsService.recordWin();
      if (result == 'loss') await StatsService.recordLoss();
      if (result == 'draw') await StatsService.recordDraw();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _GameOverDialog(
          title: title,
          subtitle: subtitle,
          result: result,
          onPlayAgain: () {
            Navigator.pop(context);
            _resetGame();
          },
          onHome: () {
            Navigator.pop(context); // close dialog
            Navigator.pop(context); // go to home
          },
        ),
      );
    });
  }

  void _resetGame() {
    setState(() {
      _game.reset();
      _selectedSquare = null;
      _validMoves = {};
      _lastFeedback = null;
      _aiThinking = false;
      _gameOverShown = false;
      _evalBar = 0;
    });
  }

  void _scrollHistoryToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_historyScrollCtrl.hasClients) {
        _historyScrollCtrl.animateTo(
          _historyScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Difficulty ─────────────────────────────────────────────────────────────

  void _changeDifficulty(String diff) {
    if (diff == _difficulty) return;
    setState(() {
      _difficulty = diff;
    });
    _resetGame();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selected = _selectedSquare != null ? {_selectedSquare!} : <String>{};

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
        title: const Text('Chess Coach AI',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetGame,
            tooltip: 'New Game',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _DifficultySelector(
              current: _difficulty,
              onSelect: _changeDifficulty,
            ),
            _PlayerBar(
              label: 'AI (Black)',
              isActive: _game.turn == 'black' && !_game.isGameOver,
              isThinking: _aiThinking,
            ),
            _EvalBar(centipawns: _evalBar),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChessBoard(
                  fen: _game.fen,
                  selectedSquares: selected,
                  validMoveSquares: _validMoves,
                  onSquareTap: _onSquareTapped,
                ),
              ),
            ),
            _PlayerBar(
              label: 'You (White)',
              isActive: _game.turn == 'white' && !_game.isGameOver,
              isThinking: false,
            ),
            if (_lastFeedback != null)
              _CoachPanel(feedback: _lastFeedback!),
            _MoveHistoryList(
              history: _game.history,
              scrollController: _historyScrollCtrl,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DifficultySelector extends StatelessWidget {
  final String current;
  final void Function(String) onSelect;

  const _DifficultySelector({required this.current, required this.onSelect});

  static const _levels = [
    ('beginner', 'Beginner', Color(0xFF66BB6A)),
    ('easy', 'Easy', Color(0xFF4FC3F7)),
    ('intermediate', 'Intermediate', Color(0xFFFFA726)),
    ('advanced', 'Advanced', Color(0xFFEF5350)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: _levels.map((level) {
          final (id, label, color) = level;
          final isSelected = id == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isSelected ? color.withAlpha(200) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? color : color.withAlpha(80),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isThinking;

  const _PlayerBar(
      {required this.label, required this.isActive, required this.isThinking});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: isActive
          ? kPrimaryAccent.withAlpha(50)
          : kSurface.withAlpha(200),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 14,
            color: isActive ? kPrimaryAccent : Colors.white38,
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: isActive ? Colors.white : Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          if (isThinking)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(kPrimaryAccent),
              ),
            ),
          if (isThinking)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Text('Thinking...',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

class _EvalBar extends StatelessWidget {
  final int centipawns; // positive = white advantage

  const _EvalBar({required this.centipawns});

  @override
  Widget build(BuildContext context) {
    // Clamp to ±600cp for display
    final clamped = centipawns.clamp(-600, 600);
    final fraction = (clamped + 600) / 1200; // 0..1, 0.5 = equal

    return SizedBox(
      height: 8,
      child: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          children: [
            Container(color: const Color(0xFF2C2C2C)),
            // White advantage grows from left
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: constraints.maxWidth * fraction,
              color: Colors.white,
            ),
            // Center line
            Center(
              child: Container(width: 1, color: Colors.black45),
            ),
          ],
        );
      }),
    );
  }
}

class _CoachPanel extends StatelessWidget {
  final CoachFeedback feedback;

  const _CoachPanel({required this.feedback});

  Color get _bgColor {
    switch (feedback.quality) {
      case MoveQuality.brilliant:
      case MoveQuality.excellent:
        return const Color(0xFF1B5E20);
      case MoveQuality.good:
        return const Color(0xFF1A237E);
      case MoveQuality.inaccuracy:
        return const Color(0xFF4A3800);
      case MoveQuality.mistake:
        return const Color(0xFF6D1F00);
      case MoveQuality.blunder:
        return const Color(0xFF7F0000);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(feedback.qualityLabel,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feedback.message,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveHistoryList extends StatelessWidget {
  final List<Move> history;
  final ScrollController scrollController;

  const _MoveHistoryList(
      {required this.history, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    // Group into pairs
    final pairs = <(Move?, Move?)>[];
    for (int i = 0; i < history.length; i += 2) {
      final white = history[i];
      final black = i + 1 < history.length ? history[i + 1] : null;
      pairs.add((white, black));
    }

    return Container(
      height: 48,
      color: kSurface,
      child: pairs.isEmpty
          ? const Center(
              child: Text('No moves yet',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          : ListView.builder(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: pairs.length,
              itemBuilder: (context, index) {
                final (white, black) = pairs[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    children: [
                      Text('${index + 1}.',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                      const SizedBox(width: 4),
                      if (white != null) _MoveChip(move: white, isWhite: true),
                      const SizedBox(width: 3),
                      if (black != null) _MoveChip(move: black, isWhite: false),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final Move move;
  final bool isWhite;

  const _MoveChip({required this.move, required this.isWhite});

  @override
  Widget build(BuildContext context) {
    final bgColor = isWhite ? Colors.white12 : Colors.black26;
    final textColor = move.isCapture
        ? const Color(0xFFFFA726)
        : (isWhite ? Colors.white : Colors.white70);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        move.notation,
        style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _GameOverDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String result;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  const _GameOverDialog({
    required this.title,
    required this.subtitle,
    required this.result,
    required this.onPlayAgain,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (result) {
      'win' => (Icons.emoji_events, const Color(0xFFFFD700)),
      'loss' => (Icons.sentiment_dissatisfied, const Color(0xFFEF5350)),
      _ => (Icons.handshake, Colors.white54),
    };
    final (iconData, iconColor) = icon;

    return AlertDialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 56, color: iconColor),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onPlayAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Play Again'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onHome,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Home'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
