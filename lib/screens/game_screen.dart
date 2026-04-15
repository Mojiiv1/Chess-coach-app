import 'package:flutter/material.dart';
import '../models/move.dart';
import '../services/ai_service.dart';
import '../services/coach_service.dart';
import '../services/game_service.dart';
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
  String? _statusMessage;
  bool _aiThinking = false;
  AIDifficulty _difficulty = AIDifficulty.easy;
  CoachFeedback? _lastFeedback;

  // ── Player move handler ────────────────────────────────────────────────────

  void _onSquareTapped(String square) {
    // Block taps while AI is thinking or it's not the player's turn
    if (_aiThinking || _game.isGameOver || !_game.isWhiteTurn) return;

    setState(() {
      if (_selectedSquare == null) {
        final moves = _game.getLegalMoves(square);
        if (moves.isNotEmpty) {
          _selectedSquare = square;
          _validMoves = moves.toSet();
          _statusMessage = null;
        }
      } else if (_selectedSquare == square) {
        _selectedSquare = null;
        _validMoves = {};
      } else if (_validMoves.contains(square)) {
        final fenBefore = _game.fen;
        final move = _game.makeMove(_selectedSquare!, square);
        _selectedSquare = null;
        _validMoves = {};
        if (move != null) {
          _lastFeedback = CoachService.analyzeMove(
            beforeFen: fenBefore,
            move: move,
            isPlayerWhite: true,
          );
          _updateStatus();
          if (!_game.isGameOver) _scheduleAIMove();
        }
      } else {
        final moves = _game.getLegalMoves(square);
        if (moves.isNotEmpty) {
          _selectedSquare = square;
          _validMoves = moves.toSet();
          _statusMessage = null;
        } else {
          _selectedSquare = null;
          _validMoves = {};
        }
      }
    });
  }

  // ── AI move ────────────────────────────────────────────────────────────────

  void _scheduleAIMove() {
    setState(() => _aiThinking = true);
    Future.delayed(const Duration(milliseconds: 800), _executeAIMove);
  }

  void _executeAIMove() {
    if (!mounted || _game.isGameOver) {
      if (mounted) setState(() => _aiThinking = false);
      return;
    }

    final aiMove = AIService.getAIMove(_game.fen, _difficulty);
    if (aiMove != null) {
      _game.makeMove(aiMove['from']!, aiMove['to']!);
    }

    setState(() {
      _aiThinking = false;
      _updateStatus();
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _updateStatus() {
    if (_game.isCheckmate()) {
      final winner = _game.turn == 'white' ? 'Black (AI)' : 'White (You)';
      _statusMessage = 'Checkmate! $winner wins!';
    } else if (_game.isDraw()) {
      _statusMessage = 'Draw!';
    } else if (_game.isInCheck()) {
      _statusMessage = _game.turn == 'white' ? 'Check! Your king is in check.' : 'Check!';
    } else {
      _statusMessage = null;
    }
  }

  void _reset() {
    setState(() {
      _game.reset();
      _selectedSquare = null;
      _validMoves = {};
      _statusMessage = null;
      _aiThinking = false;
      _lastFeedback = null;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWhiteTurn = _game.isWhiteTurn;
    final history = _game.history;

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        backgroundColor: kAppSurface,
        title: const Text(
          'Chess Coach AI',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'New game',
            onPressed: _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Difficulty selector
            _DifficultySelector(
              selected: _difficulty,
              onChanged: (d) {
                setState(() {
                  _difficulty = d;
                  _reset();
                });
              },
            ),

            const SizedBox(height: 8),

            // Black / AI player
            _PlayerBar(
              name: _aiThinking ? 'AI thinking...' : 'Black (AI)',
              isActive: !isWhiteTurn && !_game.isGameOver,
              isThinking: _aiThinking,
              color: Colors.black,
            ),

            const SizedBox(height: 4),

            // Board
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: AbsorbPointer(
                    absorbing: _aiThinking || !_game.isWhiteTurn,
                    child: Opacity(
                      opacity: _aiThinking ? 0.85 : 1.0,
                      child: ChessBoard(
                        fen: _game.fen,
                        selectedSquare: _selectedSquare,
                        validMoves: _validMoves,
                        onSquareTapped: _onSquareTapped,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // White / Human player
            _PlayerBar(
              name: 'White (You)',
              isActive: isWhiteTurn && !_game.isGameOver,
              isThinking: false,
              color: Colors.white,
            ),

            const SizedBox(height: 8),

            // Status banner
            if (_statusMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: kAppPrimary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: kAppPrimary.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),

            const SizedBox(height: 6),

            // Coach feedback panel
            if (_lastFeedback != null)
              _CoachPanel(feedback: _lastFeedback!),

            const SizedBox(height: 6),

            // Move history
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kAppSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: history.isEmpty
                    ? const Center(
                        child: Text(
                          'Make a move to start',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      )
                    : _MoveHistoryList(moves: history),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _DifficultySelector extends StatelessWidget {
  final AIDifficulty selected;
  final ValueChanged<AIDifficulty> onChanged;

  const _DifficultySelector({
    required this.selected,
    required this.onChanged,
  });

  static const _labels = {
    AIDifficulty.beginner: 'Beginner',
    AIDifficulty.easy: 'Easy',
    AIDifficulty.intermediate: 'Intermediate',
    AIDifficulty.advanced: 'Advanced',
  };

  static const _colors = {
    AIDifficulty.beginner: Colors.green,
    AIDifficulty.easy: Colors.lightBlue,
    AIDifficulty.intermediate: Colors.orange,
    AIDifficulty.advanced: Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: AIDifficulty.values.map((d) {
          final isSelected = d == selected;
          final color = _colors[d]!;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : Colors.white24,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  _labels[d]!,
                  style: TextStyle(
                    color: isSelected ? color : Colors.white38,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
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
  final String name;
  final bool isActive;
  final bool isThinking;
  final Color color;

  const _PlayerBar({
    required this.name,
    required this.isActive,
    required this.isThinking,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? kAppPrimary : Colors.white24,
                width: isActive ? 2.5 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: kAppPrimary.withValues(alpha: 0.6),
                        blurRadius: 6,
                      )
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white38,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isThinking) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: kAppPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoveHistoryList extends StatelessWidget {
  final List<Move> moves;
  const _MoveHistoryList({required this.moves});

  @override
  Widget build(BuildContext context) {
    final rows = <(int, Move, Move?)>[];
    for (int i = 0; i < moves.length; i += 2) {
      rows.add((
        i ~/ 2 + 1,
        moves[i],
        i + 1 < moves.length ? moves[i + 1] : null,
      ));
    }

    return ListView.builder(
      reverse: true,
      itemCount: rows.length,
      itemBuilder: (_, idx) {
        final (num, white, black) = rows[rows.length - 1 - idx];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$num.',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              _MoveChip(
                  notation: white.notation, isCapture: white.isCapture),
              const SizedBox(width: 6),
              if (black != null)
                _MoveChip(
                    notation: black.notation, isCapture: black.isCapture),
            ],
          ),
        );
      },
    );
  }
}

class _MoveChip extends StatelessWidget {
  final String notation;
  final bool isCapture;
  const _MoveChip({required this.notation, required this.isCapture});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCapture
            ? Colors.redAccent.withValues(alpha: 0.2)
            : kAppPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        notation,
        style: TextStyle(
          color: isCapture ? Colors.redAccent[100] : Colors.white70,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _CoachPanel extends StatelessWidget {
  final CoachFeedback feedback;
  const _CoachPanel({required this.feedback});

  static const _qualityColors = {
    MoveQuality.blunder: Color(0xFFE53935),
    MoveQuality.mistake: Color(0xFFFF7043),
    MoveQuality.inaccuracy: Color(0xFFFFB300),
    MoveQuality.good: Color(0xFF66BB6A),
    MoveQuality.excellent: Color(0xFF29B6F6),
  };

  @override
  Widget build(BuildContext context) {
    final color = _qualityColors[feedback.quality]!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(feedback.qualityEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedback.qualityLabel,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feedback.message,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
