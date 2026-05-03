import 'dart:async';
import 'package:flutter/material.dart';
import '../models/saved_game.dart';
import '../services/game_service.dart';
import '../services/ai_service.dart';
import '../services/coach_service.dart';
import '../services/settings_service.dart';
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
  bool _coachAnalyzing = false;
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

  Future<void> _executePlayerMove(String from, String to) async {
    final beforeFen = _game.fen;
    final move = _game.makeMove(from, to);
    if (move == null) return;

    final newEval = AIService.evaluatePosition(_game.fen);
    final coachEnabled = SettingsService.coachFeedbackEnabled;

    // Show "Analyzing…" immediately; clear any stale feedback.
    setState(() {
      _evalBar = newEval;
      _lastFeedback = null;
      _coachAnalyzing =
          widget.gameMode != GameMode.localMultiplayer && coachEnabled;
    });

    _scrollHistoryToEnd();

    if (_game.isGameOver) {
      _handleGameOver();
    }

    if (widget.gameMode == GameMode.localMultiplayer) return;

    // Start the AI timer now — it runs concurrently with Stockfish analysis.
    _scheduleAIMove();

    if (!coachEnabled) return; // skip Stockfish analysis; panel stays hidden

    final feedback = await CoachService.analyzeMoveAsync(
      beforeFen: beforeFen,
      from: from,
      to: to,
      isPlayerWhite: true,
    );

    if (mounted) {
      setState(() {
        _lastFeedback = feedback;
        _coachAnalyzing = false;
      });
    }
  }

  void _scheduleAIMove() {
    if (_aiThinking) return;
    setState(() => _aiThinking = true);
    Timer(const Duration(milliseconds: 600), () {
      if (mounted) _executeAIMove();
    });
  }

  Future<void> _executeAIMove() async {
    if (!mounted) return;
    try {
      final (uciMove, _) =
          await AIService.getAIMove(_game.fen, _difficulty, _game.uciHistory);
      if (!mounted) return;

      // Brief pause so "Thinking…" is visible before the board updates.
      await Future.delayed(const Duration(milliseconds: 200));
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

  // ── Save game ──────────────────────────────────────────────────────────────

  Future<void> _saveGame() async {
    debugPrint('[SAVE] Save button tapped. fen=${_game.fen.substring(0, 20)}... moves=${_game.uciHistory.length}');
    final id = _savedGameId ??
        DateTime.now().millisecondsSinceEpoch.toString();
    _savedGameId = id;

    try {
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
      debugPrint('[SAVE] SaveGameService.saveGame completed without error');
    } catch (e, st) {
      debugPrint('[SAVE] ERROR in _saveGame: $e\n$st');
    }

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
            Navigator.of(context).popUntil((route) => route.isFirst);
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
      _coachAnalyzing = false;
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
            if (!isMulti && (_coachAnalyzing || _lastFeedback != null))
              _coachAnalyzing && _lastFeedback == null
                  ? const _AnalyzingPanel()
                  : _CoachPanel(feedback: _lastFeedback!),
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

class _AnalyzingPanel extends StatelessWidget {
  const _AnalyzingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white38,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Analyzing…',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CoachPanel extends StatelessWidget {
  final CoachFeedback feedback;
  const _CoachPanel({required this.feedback});

  static const _qualityMeta = {
    MoveQuality.brilliant: (
      bg: Color(0xFF0D3320),
      border: Color(0xFF2E7D32),
      icon: Icons.auto_awesome_rounded,
      iconColor: Color(0xFFFFD700),
    ),
    MoveQuality.excellent: (
      bg: Color(0xFF0D3320),
      border: Color(0xFF2E7D32),
      icon: Icons.star_rounded,
      iconColor: Color(0xFF69F0AE),
    ),
    MoveQuality.good: (
      bg: Color(0xFF0D1F3C),
      border: Color(0xFF1565C0),
      icon: Icons.thumb_up_rounded,
      iconColor: Color(0xFF42A5F5),
    ),
    MoveQuality.inaccuracy: (
      bg: Color(0xFF2A1E00),
      border: Color(0xFFF57F17),
      icon: Icons.info_rounded,
      iconColor: Color(0xFFFFB74D),
    ),
    MoveQuality.mistake: (
      bg: Color(0xFF2A0A00),
      border: Color(0xFFB71C1C),
      icon: Icons.warning_rounded,
      iconColor: Color(0xFFEF5350),
    ),
    MoveQuality.blunder: (
      bg: Color(0xFF2A0000),
      border: Color(0xFFD50000),
      icon: Icons.dangerous_rounded,
      iconColor: Color(0xFFFF5252),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _qualityMeta[feedback.quality]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: meta.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: meta.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Row(
            children: [
              Icon(meta.icon, color: meta.iconColor, size: 16),
              const SizedBox(width: 6),
              Text(
                feedback.qualityLabel,
                style: TextStyle(
                  color: meta.iconColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (feedback.tactics.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: feedback.tactics
                        .map((t) => _TacticChip(label: t, color: meta.iconColor))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // ── Main message ──────────────────────────────────────────────
          Text(
            feedback.message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          // ── Suggestion ────────────────────────────────────────────────
          if (feedback.suggestion != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 13, color: Color(0xFFFFD700)),
                const SizedBox(width: 5),
                Text(
                  'Try instead: ${feedback.suggestion}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFFFD700),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],

          // ── Tip ───────────────────────────────────────────────────────
          if (feedback.tip.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              feedback.tip,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withAlpha(160),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _TacticChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TacticChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(120), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
