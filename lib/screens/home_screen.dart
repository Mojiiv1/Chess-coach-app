import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/stats_service.dart';
import '../services/save_game_service.dart';
import '../models/game_stats.dart';
import '../utils/constants.dart';
import 'game_screen.dart';
import 'game_mode_selection_screen.dart';
import 'saved_games_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late GameStats _stats;
  bool _hasSavedGames = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _stats = StatsService.getStats();
    _hasSavedGames = SaveGameService.hasSavedGames;
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _refreshStats() {
    setState(() {
      _stats = StatsService.getStats();
      _hasSavedGames = SaveGameService.hasSavedGames;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C2E), Color(0xFF1A1040), Color(0xFF0D1A50)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildStatsCard(),
                  const SizedBox(height: 32),
                  _buildGameModeButtons(context),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSecondaryButton(
                          label: 'Statistics',
                          icon: Icons.bar_chart_rounded,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const StatsScreen()),
                            );
                            _refreshStats();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSecondaryButton(
                          label: 'Settings',
                          icon: Icons.settings_rounded,
                          onTap: null,
                        ),
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

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [kPrimaryAccent, kSecondaryAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimaryAccent.withAlpha(120),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.castle_rounded,
              size: 52, color: Colors.white),
        ),
        const SizedBox(height: 18),
        const Text(
          'Chess Coach AI',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Play. Learn. Improve.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withAlpha(160),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(40), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Stats',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  if (_stats.lastResult != null)
                    _ResultBadge(result: _stats.lastResult!),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatPill(
                      label: 'Wins',
                      value: '${_stats.wins}',
                      color: kGoodMove),
                  _StatPill(
                      label: 'Losses',
                      value: '${_stats.losses}',
                      color: kBadMove),
                  _StatPill(
                      label: 'Draws',
                      value: '${_stats.draws}',
                      color: Colors.white54),
                  _StatPill(
                      label: 'Win %',
                      value: '${_stats.winRatePercentage}%',
                      color: kPrimaryAccent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameModeButtons(BuildContext context) {
    return Column(
      children: [
        _GameModeButton(
          icon: Icons.play_arrow_rounded,
          title: 'Play vs AI',
          subtitle: 'Challenge the computer',
          gradientColors: const [Color(0xFF4158D0), Color(0xFF2196F3)],
          shadowColor: const Color(0xFF4158D0),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GameModeSelectionScreen(
                  gameMode: GameMode.playerVsAI,
                ),
              ),
            );
            _refreshStats();
          },
        ),
        const SizedBox(height: 12),
        _GameModeButton(
          icon: Icons.people_rounded,
          title: 'Local Multiplayer',
          subtitle: 'Player 1 vs Player 2',
          gradientColors: const [Color(0xFF00BCD4), Color(0xFF0097A7)],
          shadowColor: kSecondaryAccent,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GameModeSelectionScreen(
                  gameMode: GameMode.localMultiplayer,
                ),
              ),
            );
            _refreshStats();
          },
        ),
        if (_hasSavedGames) ...[
          const SizedBox(height: 12),
          _GameModeButton(
            icon: Icons.folder_open_rounded,
            title: 'Continue Game',
            subtitle: 'Resume a saved game',
            gradientColors: const [Color(0xFF2E7D32), Color(0xFF388E3C)],
            shadowColor: kGoodMove,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SavedGamesScreen()),
              );
              _refreshStats();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(14),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.white.withAlpha(30), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
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

// ── Game Mode Button ──────────────────────────────────────────────────────────

class _GameModeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color shadowColor;
  final VoidCallback onTap;

  const _GameModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withAlpha(90),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(190),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withAlpha(180), size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Stat Pill ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

// ── Result Badge ──────────────────────────────────────────────────────────────

class _ResultBadge extends StatelessWidget {
  final String result;
  const _ResultBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (result) {
      'win' => ('Last: Win', kGoodMove),
      'loss' => ('Last: Loss', kBadMove),
      _ => ('Last: Draw', Colors.white54),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Screen
// ─────────────────────────────────────────────────────────────────────────────

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  GameStats _stats = StatsService.getStats();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Statistics',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _showResetDialog(context),
            tooltip: 'Reset Stats',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildWinRateCircle(),
            const SizedBox(height: 32),
            _buildStatCard('Wins', _stats.wins, _stats.gamesPlayed,
                Icons.emoji_events, kGoodMove),
            const SizedBox(height: 12),
            _buildStatCard('Losses', _stats.losses, _stats.gamesPlayed,
                Icons.sentiment_dissatisfied, kBadMove),
            const SizedBox(height: 12),
            _buildStatCard('Draws', _stats.draws, _stats.gamesPlayed,
                Icons.handshake, Colors.white54),
            const SizedBox(height: 24),
            Text(
              'Total Games: ${_stats.gamesPlayed}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinRateCircle() {
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: _stats.winRatePercentage / 100,
              strokeWidth: 12,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryAccent),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_stats.winRatePercentage}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text('Win Rate',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, int value, int total, IconData icon, Color color) {
    final fraction = total == 0 ? 0.0 : value / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    Text('$value',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Reset Stats',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to reset all statistics? This cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await StatsService.reset();
              if (!ctx.mounted) return;
              setState(() => _stats = StatsService.getStats());
              Navigator.pop(ctx);
            },
            child: Text('Reset', style: TextStyle(color: kBadMove)),
          ),
        ],
      ),
    );
  }
}
