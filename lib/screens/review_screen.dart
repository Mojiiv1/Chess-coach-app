import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;
import '../models/saved_game.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../widgets/chess_board.dart';

class ReviewScreen extends StatefulWidget {
  final SavedGame game;
  const ReviewScreen({super.key, required this.game});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _currentPly = 0;

  // _fenList[i]  = FEN after i plies (index 0 = start position)
  // _sanList[i]  = SAN notation for ply i+1
  List<String> _fenList = [];
  List<String> _sanList = [];

  final _listScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _buildMoveData();
  }

  @override
  void dispose() {
    _listScroll.dispose();
    super.dispose();
  }

  // Precompute every FEN and SAN up-front so navigation is instant.
  void _buildMoveData() {
    final chess = ch.Chess();
    _fenList = [chess.fen];
    _sanList = [];

    for (final uci in widget.game.uciHistory) {
      if (uci.length < 4) break;
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      final moveMap = <String, String>{'from': from, 'to': to};
      if (uci.length > 4) moveMap['promotion'] = uci[4];

      try {
        final ok = chess.move(moveMap);
        if (!ok) break;

        String san = to;
        final verbose = chess.getHistory({'verbose': true});
        if (verbose.isNotEmpty) {
          final last = verbose.last as Map;
          san = last['san']?.toString() ?? to;
        }
        _sanList.add(san);
        _fenList.add(chess.fen);
      } catch (e) {
        handleError(e, context: 'ReviewScreen._buildMoveData');
        break;
      }
    }
  }

  void _goToPly(int ply) {
    final clamped = ply.clamp(0, _fenList.length - 1);
    setState(() => _currentPly = clamped);
    _scrollToChip(clamped);
  }

  void _scrollToChip(int ply) {
    if (ply == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listScroll.hasClients) return;
      // Approximate each chip at 72px wide (text + padding + margin).
      final target = ((ply - 1) * 72.0)
          .clamp(0.0, _listScroll.position.maxScrollExtent);
      _listScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.game.uciHistory.isEmpty) {
      return Scaffold(
        backgroundColor: kBackground,
        appBar: _buildAppBar(),
        body: const Center(
          child: Text(
            'No moves to review.',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    final totalPlies = _fenList.length - 1;
    final atStart = _currentPly == 0;
    final atEnd = _currentPly == totalPlies;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.game.gameMode == 'playerVsAI' &&
                widget.game.difficulty != null)
              _DifficultyPill(difficulty: widget.game.difficulty!),
            _PlyLabel(currentPly: _currentPly, totalPlies: totalPlies),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: ChessBoard(
                  fen: _fenList[_currentPly],
                  selectedSquares: const <String>{},
                  validMoveSquares: const <String>{},
                  onSquareTap: (_) {},
                ),
              ),
            ),
            _NavRow(
              atStart: atStart,
              atEnd: atEnd,
              onStart: () => _goToPly(0),
              onPrev: () => _goToPly(_currentPly - 1),
              onNext: () => _goToPly(_currentPly + 1),
              onEnd: () => _goToPly(totalPlies),
            ),
            _MoveListBar(
              sanList: _sanList,
              currentPly: _currentPly,
              scrollController: _listScroll,
              onTapPly: _goToPly,
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
        title: const Text(
          'Review',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _DifficultyPill extends StatelessWidget {
  final String difficulty;
  const _DifficultyPill({required this.difficulty});

  static const _colors = {
    'beginner': Color(0xFF66BB6A),
    'easy': Color(0xFF4FC3F7),
    'intermediate': Color(0xFFFFA726),
    'advanced': Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[difficulty] ?? Colors.white54;
    final label = difficulty[0].toUpperCase() + difficulty.substring(1);
    return Container(
      height: 36,
      color: kSurface,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(120), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PlyLabel extends StatelessWidget {
  final int currentPly;
  final int totalPlies;
  const _PlyLabel({required this.currentPly, required this.totalPlies});

  @override
  Widget build(BuildContext context) {
    final String text;
    if (currentPly == 0) {
      text = 'Start position';
    } else {
      final moveNum = (currentPly + 1) ~/ 2;
      final totalMoves = (totalPlies + 1) ~/ 2;
      final side = currentPly % 2 == 1 ? 'White' : 'Black';
      text = 'Move $moveNum of $totalMoves  ·  $side just moved';
    }
    return Container(
      height: 30,
      color: kSurface,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final bool atStart;
  final bool atEnd;
  final VoidCallback onStart;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onEnd;

  const _NavRow({
    required this.atStart,
    required this.atEnd,
    required this.onStart,
    required this.onPrev,
    required this.onNext,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSurface,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavBtn(
            icon: Icons.first_page_rounded,
            label: 'Start',
            onPressed: atStart ? null : onStart,
          ),
          _NavBtn(
            icon: Icons.chevron_left_rounded,
            label: 'Prev',
            onPressed: atStart ? null : onPrev,
          ),
          _NavBtn(
            icon: Icons.chevron_right_rounded,
            label: 'Next',
            onPressed: atEnd ? null : onNext,
          ),
          _NavBtn(
            icon: Icons.last_page_rounded,
            label: 'End',
            onPressed: atEnd ? null : onEnd,
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _NavBtn({required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled ? kPrimaryAccent : Colors.white24,
              size: 28,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: enabled ? Colors.white54 : Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveListBar extends StatelessWidget {
  final List<String> sanList;
  final int currentPly;
  final ScrollController scrollController;
  final void Function(int) onTapPly;

  const _MoveListBar({
    required this.sanList,
    required this.currentPly,
    required this.scrollController,
    required this.onTapPly,
  });

  @override
  Widget build(BuildContext context) {
    if (sanList.isEmpty) return const SizedBox(height: 56);
    return Container(
      height: 56,
      color: kSurface,
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: sanList.length,
        itemBuilder: (_, i) {
          final ply = i + 1;
          final isWhite = i % 2 == 0;
          final isSelected = currentPly == ply;
          final moveNum = i ~/ 2 + 1;

          return GestureDetector(
            onTap: () => onTapPly(ply),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? kPrimaryAccent.withAlpha(60)
                    : (isWhite ? Colors.white12 : Colors.black26),
                borderRadius: BorderRadius.circular(5),
                border: isSelected
                    ? Border.all(color: kPrimaryAccent, width: 1.5)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWhite)
                    Text(
                      '$moveNum. ',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                  Text(
                    sanList[i],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isWhite ? Colors.white : Colors.white70),
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
