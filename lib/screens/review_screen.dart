import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;
import '../models/saved_game.dart';
import '../services/coach_service.dart';
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

  // ── Coach analysis state ──────────────────────────────────────────────────
  // Keyed by ply number. null value = analysis returned unavailable.
  final Map<int, CoachFeedback?> _feedbackCache = {};
  bool _analyzing = false;
  bool _analyzingAll = false;
  int _analysisDoneCount = 0;
  int _analysisTotalCount = 0;
  // Incremented on every navigation; stale async results compare against this
  // and discard themselves if the value has changed.
  int _analysisGeneration = 0;

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

  // ── Move data ─────────────────────────────────────────────────────────────

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

  // ── Human-ply detection ───────────────────────────────────────────────────
  // Human color inference:
  //   playerVsAI      → owner always plays White (odd plies: 1, 3, 5 …)
  //   localMultiplayer → both sides are the user; analyze every ply
  bool _isHumanPly(int ply) {
    if (ply == 0) return false;
    if (widget.game.gameMode == 'localMultiplayer') return true;
    return ply % 2 == 1; // white moves on odd plies
  }

  List<int> get _humanPlies => [
        for (int ply = 1; ply < _fenList.length; ply++)
          if (_isHumanPly(ply)) ply,
      ];

  int get _analyzedHumanCount =>
      _humanPlies.where(_feedbackCache.containsKey).length;

  Map<MoveQuality, int> _summaryCounts() {
    final counts = {
      for (final quality in MoveQuality.values) quality: 0,
    };

    for (final ply in _humanPlies) {
      final feedback = _feedbackCache[ply];
      if (feedback == null) continue;
      counts[feedback.quality] = counts[feedback.quality]! + 1;
    }
    return counts;
  }

  List<_CriticalMoment> get _criticalMoments {
    final moments = <_CriticalMoment>[];

    for (final ply in _humanPlies) {
      final feedback = _feedbackCache[ply];
      if (feedback == null || !_isCriticalQuality(feedback.quality)) {
        continue;
      }

      moments.add(_CriticalMoment(
        ply: ply,
        san: _sanList[ply - 1],
        quality: feedback.quality,
        qualityLabel: feedback.qualityLabel,
      ));
    }

    moments.sort((a, b) {
      final qualityCompare =
          _criticalRank(a.quality).compareTo(_criticalRank(b.quality));
      if (qualityCompare != 0) return qualityCompare;
      return a.ply.compareTo(b.ply);
    });

    return moments;
  }

  bool get _reviewAnalysisComplete =>
      _humanPlies.isNotEmpty && _analyzedHumanCount >= _humanPlies.length;

  bool _isCriticalQuality(MoveQuality quality) =>
      quality == MoveQuality.blunder ||
      quality == MoveQuality.mistake ||
      quality == MoveQuality.inaccuracy;

  int _criticalRank(MoveQuality quality) {
    return switch (quality) {
      MoveQuality.blunder => 0,
      MoveQuality.mistake => 1,
      MoveQuality.inaccuracy => 2,
      _ => 3,
    };
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _goToPly(int ply) {
    final clamped = ply.clamp(0, _fenList.length - 1);
    // Increment generation so any in-flight analysis result knows it's stale.
    ++_analysisGeneration;
    setState(() {
      _currentPly = clamped;
      _analyzing = false; // reset; _startAnalysisIfNeeded sets it back if needed
    });
    _scrollToChip(clamped);
    _startAnalysisIfNeeded();
  }

  void _scrollToChip(int ply) {
    if (ply == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listScroll.hasClients) return;
      final target = ((ply - 1) * 72.0)
          .clamp(0.0, _listScroll.position.maxScrollExtent);
      _listScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  // ── Coach analysis ────────────────────────────────────────────────────────

  Future<void> _startAnalysisIfNeeded() async {
    final ply = _currentPly;

    if (!_isHumanPly(ply)) return; // AI move or start position — skip
    if (_feedbackCache.containsKey(ply)) return; // already cached
    if (_analyzingAll) return; // full-game analysis will fill the cache

    final generation = _analysisGeneration; // capture before first await

    setState(() => _analyzing = true);

    final uci = widget.game.uciHistory[ply - 1];
    if (uci.length < 4) {
      // Malformed UCI — store null and stop.
      if (mounted && generation == _analysisGeneration) {
        setState(() {
          _feedbackCache[ply] = null;
          _analyzing = false;
        });
      }
      return;
    }

    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    // In localMultiplayer, white still plays odd plies.
    final isPlayerWhite = widget.game.gameMode != 'localMultiplayer'
        ? true         // playerVsAI: owner always plays White
        : ply % 2 == 1; // localMultiplayer: both are human; track by ply

    CoachFeedback? feedback;
    try {
      feedback = await CoachService.analyzeMoveAsync(
        beforeFen: _fenList[ply - 1],
        from: from,
        to: to,
        isPlayerWhite: isPlayerWhite,
      );
    } catch (e) {
      handleError(e, context: 'ReviewScreen._startAnalysisIfNeeded');
      // feedback stays null — panel shows "Analysis unavailable."
    }

    // Discard stale results (user navigated away while Stockfish was running).
    if (!mounted || generation != _analysisGeneration) return;

    setState(() {
      _feedbackCache[ply] = feedback; // null means unavailable
      _analyzing = false;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  Future<CoachFeedback?> _analyzePlyForFullReview(int ply) async {
    final uci = widget.game.uciHistory[ply - 1];
    if (uci.length < 4) return null;

    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final isPlayerWhite = widget.game.gameMode != 'localMultiplayer'
        ? true
        : ply % 2 == 1;

    try {
      return await CoachService.analyzeMoveAsync(
        beforeFen: _fenList[ply - 1],
        from: from,
        to: to,
        isPlayerWhite: isPlayerWhite,
      );
    } catch (e) {
      handleError(e, context: 'ReviewScreen._analyzePlyForFullReview');
      return null;
    }
  }

  Future<void> _analyzeGame() async {
    if (_analyzingAll || _analyzing) return;

    final humanPlies = _humanPlies;
    setState(() {
      _analyzingAll = true;
      _analysisTotalCount = humanPlies.length;
      _analysisDoneCount = _analyzedHumanCount;
    });

    for (final ply in humanPlies) {
      if (!mounted) return;
      if (_feedbackCache.containsKey(ply)) continue;

      final feedback = await _analyzePlyForFullReview(ply);
      if (!mounted) return;

      setState(() {
        _feedbackCache[ply] = feedback;
        _analysisDoneCount = _analyzedHumanCount;
      });
    }

    if (!mounted) return;
    setState(() {
      _analysisDoneCount = _analyzedHumanCount;
      _analyzingAll = false;
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
              feedbackCache: _feedbackCache,
              scrollController: _listScroll,
              isHumanPly: _isHumanPly,
              onTapPly: _goToPly,
            ),
            _ReviewSummaryPanel(
              analyzingAll: _analyzingAll,
              analyzedCount:
                  _analyzingAll ? _analysisDoneCount : _analyzedHumanCount,
              totalCount:
                  _analyzingAll ? _analysisTotalCount : _humanPlies.length,
              counts: _summaryCounts(),
              onAnalyzeGame: _analyzeGame,
            ),
            _CriticalMomentsPanel(
              moments: _criticalMoments,
              analysisComplete: _reviewAnalysisComplete,
              onTapPly: _goToPly,
            ),
            _buildFeedbackPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackPanel() {
    final ply = _currentPly;

    if (ply == 0) return const SizedBox.shrink();

    if (!_isHumanPly(ply)) {
      return _StatusPanel(
        child: const Text(
          'AI move — not analyzed.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    if (_analyzing) {
      return const _StatusPanel(
        child: Row(
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

    if (!_feedbackCache.containsKey(ply)) return const SizedBox.shrink();

    final feedback = _feedbackCache[ply];
    if (feedback == null) {
      return _StatusPanel(
        child: const Text(
          'Analysis unavailable.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return _ReviewCoachPanel(feedback: feedback);
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
  final Map<int, CoachFeedback?> feedbackCache;
  final ScrollController scrollController;
  final bool Function(int ply) isHumanPly;
  final void Function(int) onTapPly;

  const _MoveListBar({
    required this.sanList,
    required this.currentPly,
    required this.feedbackCache,
    required this.scrollController,
    required this.isHumanPly,
    required this.onTapPly,
  });

  Color? _feedbackColor(int ply) {
    if (!isHumanPly(ply)) return null;
    final feedback = feedbackCache[ply];
    if (feedback == null) return null;

    return switch (feedback.quality) {
      MoveQuality.brilliant => const Color(0xFFFFD54F),
      MoveQuality.excellent => const Color(0xFF69F0AE),
      MoveQuality.good => const Color(0xFF42A5F5),
      MoveQuality.inaccuracy => const Color(0xFFFFB74D),
      MoveQuality.mistake => const Color(0xFFEF6C00),
      MoveQuality.blunder => const Color(0xFFFF5252),
    };
  }

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
          final feedbackColor = _feedbackColor(ply);
          final chipColor = feedbackColor == null
              ? (isSelected
                  ? kPrimaryAccent.withAlpha(60)
                  : (isWhite ? Colors.white12 : Colors.black26))
              : feedbackColor.withAlpha(isSelected ? 70 : 42);
          final borderColor = isSelected
              ? kPrimaryAccent
              : feedbackColor?.withAlpha(150);

          return GestureDetector(
            onTap: () => onTapPly(ply),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(5),
                border: borderColor == null
                    ? null
                    : Border.all(
                        color: borderColor,
                        width: isSelected ? 1.5 : 0.8,
                      ),
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

/// Basic full-review progress and cached-feedback summary.
class _ReviewSummaryPanel extends StatelessWidget {
  final bool analyzingAll;
  final int analyzedCount;
  final int totalCount;
  final Map<MoveQuality, int> counts;
  final VoidCallback onAnalyzeGame;

  const _ReviewSummaryPanel({
    required this.analyzingAll,
    required this.analyzedCount,
    required this.totalCount,
    required this.counts,
    required this.onAnalyzeGame,
  });

  @override
  Widget build(BuildContext context) {
    final complete = totalCount > 0 && analyzedCount >= totalCount;
    final progressText = analyzingAll
        ? 'Analyzing $analyzedCount / $totalCount...'
        : complete
            ? 'Summary complete'
            : 'Analyze game to complete summary';

    return Container(
      width: double.infinity,
      color: kSurface,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  progressText,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed:
                    analyzingAll || totalCount == 0 ? null : onAnalyzeGame,
                child: const Text('Analyze Game'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _SummaryCount(
                  label: 'Brilliant',
                  value: counts[MoveQuality.brilliant] ?? 0),
              _SummaryCount(
                  label: 'Excellent',
                  value: counts[MoveQuality.excellent] ?? 0),
              _SummaryCount(
                  label: 'Good', value: counts[MoveQuality.good] ?? 0),
              _SummaryCount(
                  label: 'Inaccuracy',
                  value: counts[MoveQuality.inaccuracy] ?? 0),
              _SummaryCount(
                  label: 'Mistake',
                  value: counts[MoveQuality.mistake] ?? 0),
              _SummaryCount(
                  label: 'Blunder',
                  value: counts[MoveQuality.blunder] ?? 0),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCount extends StatelessWidget {
  final String label;
  final int value;

  const _SummaryCount({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(color: Colors.white70, fontSize: 11),
    );
  }
}

/// Simple cached list of the worst analyzed human moves.
class _CriticalMoment {
  final int ply;
  final String san;
  final MoveQuality quality;
  final String qualityLabel;

  const _CriticalMoment({
    required this.ply,
    required this.san,
    required this.quality,
    required this.qualityLabel,
  });
}

class _CriticalMomentsPanel extends StatelessWidget {
  final List<_CriticalMoment> moments;
  final bool analysisComplete;
  final void Function(int ply) onTapPly;

  const _CriticalMomentsPanel({
    required this.moments,
    required this.analysisComplete,
    required this.onTapPly,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (moments.isEmpty) {
      content = Text(
        analysisComplete
            ? 'No major mistakes found.'
            : 'Analyze game to find critical moments.',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      );
    } else {
      content = Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final moment in moments)
            _CriticalMomentChip(
              moment: moment,
              onTap: () => onTapPly(moment.ply),
            ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      color: kSurface,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Critical Moments',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          content,
        ],
      ),
    );
  }
}

class _CriticalMomentChip extends StatelessWidget {
  final _CriticalMoment moment;
  final VoidCallback onTap;

  const _CriticalMomentChip({
    required this.moment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final moveNumber = (moment.ply + 1) ~/ 2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          '$moveNumber. ${moment.san} - ${moment.qualityLabel}',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ),
    );
  }
}

/// Thin wrapper used for the "Analyzing…", "AI move", and "unavailable" states.
class _StatusPanel extends StatelessWidget {
  final Widget child;
  const _StatusPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}

/// Coach feedback panel for reviewed moves — mirrors _CoachPanel in
/// game_screen.dart but lives here so the two screens stay independent.
class _ReviewCoachPanel extends StatelessWidget {
  final CoachFeedback feedback;
  const _ReviewCoachPanel({required this.feedback});

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

    return Container(
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
            ],
          ),
          const SizedBox(height: 6),
          Text(
            feedback.message,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, height: 1.4),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (feedback.suggestion != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 13, color: Color(0xFFFFD700)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Try instead: ${feedback.suggestion}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFFFD700),
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
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
