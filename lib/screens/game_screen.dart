import 'dart:async';
import 'package:flutter/material.dart';
import '../models/saved_game.dart';
import '../services/game_service.dart';
import '../services/ai_service.dart';
import '../services/coach_service.dart';
import '../services/stats_service.dart';
import '../services/save_game_service.dart';
import '../models/move.dart';
import '../utils/constants.dart';
import '../widgets/chess_board.dart';

enum GameMode { playerVsAI, localMultiplayer }

class GameScreen extends StatefulWidget {
  final GameMode gameMode;
  final String difficulty;
  final SavedGame? resumeFrom;

  const GameScreen({
    super.key,
    this.gameMode = GameMode.playerVsAI,
    this.difficulty = 'intermediate',
    this.resumeFrom,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _game = GameService();

  String? _selectedSquare;
  Set<String> _validMoves = {};

  late String _difficulty;
  String? _savedGameId;
  CoachFeedback? _lastFeedback;
  bool _aiThinking = false;
  bool _gameOverShown = false;
  int _evalBar = 0;

  final _historyScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _difficulty = widget.difficulty;
    if (widget.resumeFrom != null) {
      final saved = widget.resumeFrom!;
      _game.loadFromFen(saved.fen, saved.uciHistory);
      _difficulty = saved.difficulty ?? widget.difficulty;
      _savedGameId = saved.id;
      _gameOverShown = saved.isComplete;
    }
  }

  @override
  void dispose() {
    _historyScrollCtrl.dispose();
    super.dispose();
  }

  // ── Square tapping ─────────────────────────────────────────────────────────

  void _onSquareTapped(String square) {
    if (_aiThinking || _game.isGameOver) return;
    if (widget.gameMode == GameMode.playerVsAI && _game.turn != 'white') return;

    if (_selectedSquare == null) {
      final moves = _game.getLegalMoves(square);
      if (moves.isNotEmpty) {
        setState(() {
          _selectedSquare = square;
          _validMoves = moves;
        });
      }
    } else if (_selectedSquare == square) {
      setState(() {
        _selectedSquare = null;
        _validMoves = {};
      });
    } else if (_validMoves.contains(square)) {
      final from = _selectedSquare!;
      setState(() {
        _selectedSquare = null;
        _validMoves = {};
      });
      _executePlayerMove(from, square);
    } else {
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

    final feedback = CoachService.analyzeMove(
      beforeFen: beforeFen,
      from: from,
      to: to,
      isPlayerWhite: true,
    );
    final newEval = AIService.evaluatePosition(_game.fen);

    setState(() {
      _lastFeedback = feedback;
      _evalBar = newEval;
      _aiThinking =
          widget.gameMode == GameMode.playerVsAI && !_game.isGameOver;
    });

    _scrollHistoryToEnd();

    if (_game.isGameOver) {
      _handleGameOver();
      return;
    }

    if (widget.gameMode == GameMode.localMultiplayer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPassDeviceDialog();
      });
      return;
    }

    Timer(const Duration(milliseconds: 700), _executeAIMove);
  }

  Future<void> _executeAIMove() async {
    if (!mounted) return;
    try {
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
      if (mounted) setState(() => _aiThinking = false);
    }
  }

  // ── Pass device dialog ─────────────────────────────────────────────────────

  void _showPassDeviceDialog() {
    final nextIsWhite = _game.turn == 'white';
    final playerLabel =
        nextIsWhite ? 'Player 1 (White)' : 'Player 2 (Black)';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: kSurface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: 3.14159 / 4,
                child: const Icon(Icons.swap_horiz,
                    size: 52, color: kPrimaryAccent),
              ),
              const SizedBox(height: 20),
              Text(
                "$playerLabel's Turn",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Pass the device to your opponent',
                style: TextStyle(
                    fontSize: 14, color: Colors.white.withAlpha(180)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Ready',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save game ──────────────────────────────────────────────────────────────

  Future<void> _saveGame() async {
    final id = _savedGameId ??
        DateTime.now().millisecondsSinceEpoch.toString();
    _savedGameId = id;

    await SaveGameService.saveGame(SavedGame(
      id: id,
      fen: _game.fen,
      gameMode: widget.gameMode == GameMode.playerVsAI
          ? 'playerVsAI'
          : 'localMultiplayer',
      difficulty:
          widget.gameMode == GameMode.playerVsAI ? _difficulty : null,
      uciHistory: List<String>.from(_game.uciHistory),
      savedAt: DateTime.now(),
      isComplete: _game.isGameOver,
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Game saved!'),
          backgroundColor: kSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Game over ──────────────────────────────────────────────────────────────

  void _handleGameOver() {
    if (_gameOverShown) return;
    _gameOverShown = true;

    late String title;
    late String subtitle;
    late IconData icon;
    late Color iconColor;

    if (_game.isCheckmate) {
      final blackWon = _game.turn == 'white';
      title = 'Checkmate!';

      if (widget.gameMode == GameMode.playerVsAI) {
        if (blackWon) {
          subtitle = 'The AI wins this time. Keep practicing!';
          icon = Icons.sentiment_dissatisfied;
          iconColor = kBadMove;
          Future<void>(() => StatsService.recordLoss());
        } else {
          subtitle = 'You won! Excellent play!';
          icon = Icons.emoji_events;
          iconColor = const Color(0xFFFFD700);
          Future<void>(() => StatsService.recordWin());
        }
      } else {
        subtitle = blackWon
            ? 'Player 2 (Black) wins!'
            : 'Player 1 (White) wins!';
        icon = Icons.emoji_events;
        iconColor = const Color(0xFFFFD700);
      }
    } else {
      title = 'Draw!';
      subtitle = _game.isStalemate ? 'Stalemate.' : 'The game is a draw.';
      icon = Icons.handshake;
      iconColor = Colors.white54;
      if (widget.gameMode == GameMode.playerVsAI) {
        Future<void>(() => StatsService.recordDraw());
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _GameOverDialog(
          title: title,
          subtitle: subtitle,
          icon: icon,
          iconColor: iconColor,
          onPlayAgain: () {
            Navigator.pop(context);
            _resetGame();
          },
          onHome: () {
            Navigator.pop(context);
            Navigator.pop(context);
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
      _savedGameId = null;
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

  void _changeDifficulty(String diff) {
    if (diff == _difficulty) return;
    setState(() => _difficulty = diff);
    _resetGame();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selected = _selectedSquare != null ? {_selectedSquare!} : <String>{};
    final isMulti = widget.gameMode == GameMode.localMultiplayer;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
        title: Text(
          isMulti ? 'Local Multiplayer' : 'Chess Coach AI',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (!_game.isGameOver)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveGame,
              tooltip: 'Save Game',
            ),
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
            if (!isMulti)
              _DifficultySelector(
                  current: _difficulty, onSelect: _changeDifficulty),
            _PlayerBar(
              label: isMulti ? 'Player 2 (Black)' : 'AI (Black)',
              isActive: _game.turn == 'black' && !_game.isGameOver,
              isThinking: _aiThinking && !isMulti,
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
              label: isMulti ? 'Player 1 (White)' : 'You (White)',
              isActive: _game.turn == 'white' && !_game.isGameOver,
              isThinking: false,
            ),
            if (_lastFeedback != null && !isMulti)
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
      color: isActive ? kPrimaryAccent.withAlpha(50) : kSurface.withAlpha(200),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            isActive
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
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
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kPrimaryAccent.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kPrimaryAccent.withAlpha(160)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(kPrimaryAccent),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Thinking…',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EvalBar extends StatelessWidget {
  final int centipawns;

  const _EvalBar({required this.centipawns});

  @override
  Widget build(BuildContext context) {
    final clamped = centipawns.clamp(-600, 600);
    final fraction = (clamped + 600) / 1200;

    return SizedBox(
      height: 8,
      child: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          children: [
            Container(color: const Color(0xFF2C2C2C)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: constraints.maxWidth * fraction,
              color: Colors.white,
            ),
            Center(child: Container(width: 1, color: Colors.black45)),
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
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
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
    final pairs = <(Move?, Move?)>[];
    for (int i = 0; i < history.length; i += 2) {
      pairs.add((history[i], i + 1 < history.length ? history[i + 1] : null));
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
                      if (black != null)
                        _MoveChip(move: black, isWhite: false),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white12 : Colors.black26,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        move.notation,
        style: TextStyle(
            color: move.isCapture
                ? const Color(0xFFFFA726)
                : (isWhite ? Colors.white : Colors.white70),
            fontSize: 12,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _GameOverDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  const _GameOverDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onPlayAgain,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: iconColor),
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
