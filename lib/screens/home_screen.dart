import 'package:flutter/material.dart';
import '../models/game_stats.dart';
import '../services/stats_service.dart';
import '../utils/constants.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameStats _stats = StatsService.getStats();

  void _refresh() => setState(() => _stats = StatsService.getStats());

  Future<void> _startNewGame() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
    _refresh();
  }

  void _showStatistics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StatsScreen(onReset: _refresh)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo / title ──────────────────────────────────────────
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: kAppPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: kAppPrimary.withValues(alpha: 0.4), width: 2),
                    ),
                    child: const Icon(Icons.psychology,
                        color: kAppPrimary, size: 44),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Chess Coach AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Play. Learn. Improve.',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),

                  const SizedBox(height: 32),

                  // ── Quick stats card ──────────────────────────────────────
                  _QuickStatsCard(stats: _stats),

                  const SizedBox(height: 28),

                  // ── New Game ──────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _startNewGame,
                      icon: const Icon(Icons.play_arrow_rounded, size: 26),
                      label: const Text('New Game',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAppPrimary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: kAppPrimary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Statistics ────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _showStatistics,
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: const Text('Statistics'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Settings (placeholder) ────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Settings  (coming soon)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white24,
                        side: const BorderSide(color: Colors.white12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Quick stats card ──────────────────────────────────────────────────────────

class _QuickStatsCard extends StatelessWidget {
  final GameStats stats;
  const _QuickStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final lastResult = stats.lastResult;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kAppSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatPill(label: 'Wins', value: stats.wins,
                  color: const Color(0xFF66BB6A)),
              _StatPill(label: 'Losses', value: stats.losses,
                  color: const Color(0xFFEF5350)),
              _StatPill(label: 'Draws', value: stats.draws,
                  color: Colors.white54),
              _StatPill(label: 'Win rate',
                  value: stats.gamesPlayed == 0
                      ? null
                      : stats.winRatePercentage,
                  suffix: '%',
                  color: kAppPrimary),
            ],
          ),
          if (lastResult != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Last game: ',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
                _lastResultBadge(lastResult),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _lastResultBadge(String result) {
    final (label, color) = switch (result) {
      'win'  => ('Victory', const Color(0xFF66BB6A)),
      'loss' => ('Defeat', const Color(0xFFEF5350)),
      _      => ('Draw', Colors.white54),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int? value;
  final String suffix;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    this.suffix = '',
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value == null ? '—' : '${value!}$suffix',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

// ── Statistics screen ─────────────────────────────────────────────────────────

class StatsScreen extends StatefulWidget {
  final VoidCallback onReset;
  const StatsScreen({super.key, required this.onReset});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  GameStats _stats = StatsService.getStats();

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kAppSurface,
        title: const Text('Reset Stats',
            style: TextStyle(color: Colors.white)),
        content: const Text('This will clear all your game history.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset',
                  style: TextStyle(color: Color(0xFFEF5350)))),
        ],
      ),
    );
    if (confirmed == true) {
      await StatsService.reset();
      setState(() => _stats = StatsService.getStats());
      widget.onReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _stats.gamesPlayed;
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        backgroundColor: kAppSurface,
        title: const Text('Statistics',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white54),
            tooltip: 'Reset stats',
            onPressed: _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Win rate circle
                  _WinRateCircle(stats: _stats),

                  const SizedBox(height: 32),

                  // Stats breakdown
                  _StatsRow(
                    label: 'Wins',
                    value: _stats.wins,
                    total: total,
                    color: const Color(0xFF66BB6A),
                    icon: Icons.emoji_events_outlined,
                  ),
                  const SizedBox(height: 12),
                  _StatsRow(
                    label: 'Losses',
                    value: _stats.losses,
                    total: total,
                    color: const Color(0xFFEF5350),
                    icon: Icons.sentiment_dissatisfied_outlined,
                  ),
                  const SizedBox(height: 12),
                  _StatsRow(
                    label: 'Draws',
                    value: _stats.draws,
                    total: total,
                    color: Colors.white54,
                    icon: Icons.handshake_outlined,
                  ),
                  const SizedBox(height: 20),

                  Divider(color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Total games played: ',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 14),
                      ),
                      Text(
                        '$total',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WinRateCircle extends StatelessWidget {
  final GameStats stats;
  const _WinRateCircle({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kAppSurface,
        border: Border.all(color: kAppPrimary.withValues(alpha: 0.4), width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            stats.gamesPlayed == 0 ? '—' : '${stats.winRatePercentage}%',
            style: const TextStyle(
              color: kAppPrimary,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text('Win Rate',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  final IconData icon;

  const _StatsRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAppSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    Text('$value',
                        style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
