import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _stats = StatsService.getStats();
    _hasSavedGames = SaveGameService.hasSavedGames;
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  void _refreshStats() {
    setState(() {
      _stats = StatsService.getStats();
      _hasSavedGames = SaveGameService.hasSavedGames;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1B2A), Color(0xFF16213E), Color(0xFF0F3460)],
          stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildLogoSection(),
                const SizedBox(height: 32),
                _buildStatsCard()
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 500.ms)
                    .slideY(begin: 0.08, curve: Curves.easeOut),
                const SizedBox(height: 28),
                _buildGameModeButtons(context),
                const SizedBox(height: 24),
                _buildFooterButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo ───────────────────────────────────────────────────────────────────

  Widget _buildLogoSection() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, child) => Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withAlpha(
                      (120 + (_glowAnim.value * 100)).round()),
                  blurRadius: 28 + (_glowAnim.value * 22),
                  spreadRadius: 3 + (_glowAnim.value * 6),
                ),
                BoxShadow(
                  color: const Color(0xFF0EA5E9)
                      .withAlpha((60 + (_glowAnim.value * 60)).round()),
                  blurRadius: 14 + (_glowAnim.value * 10),
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
          child: const Icon(Icons.castle_rounded, size: 56, color: Colors.white),
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(begin: const Offset(0.7, 0.7), curve: Curves.elasticOut),
        const SizedBox(height: 20),
        const Text(
          'Chess Coach AI',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ).animate().fadeIn(delay: 150.ms, duration: 500.ms),
        const SizedBox(height: 6),
        Text(
          'Play. Learn. Improve.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withAlpha(155),
            letterSpacing: 1.4,
          ),
        ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
      ],
    );
  }

  // ── Stats card ─────────────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withAlpha(40), width: 1),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'YOUR STATS',
                    style: TextStyle(
                      color: Colors.white.withAlpha(140),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  if (_stats.lastResult != null)
                    _ResultBadge(result: _stats.lastResult!),
                ],
              ),
              const SizedBox(height: 18),
              IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem('Wins', '${_stats.wins}', kGoodMove),
                    _StatDivider(),
                    _StatItem('Losses', '${_stats.losses}', kBadMove),
                    _StatDivider(),
                    _StatItem('Draws', '${_stats.draws}', Colors.white54),
                    _StatDivider(),
                    _StatItem(
                        'Win %', '${_stats.winRatePercentage}%', kPrimaryAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Game mode buttons ──────────────────────────────────────────────────────

  Widget _buildGameModeButtons(BuildContext context) {
    final buttons = [
      _GameModeButtonData(
        icon: Icons.smart_toy_rounded,
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
      _GameModeButtonData(
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
      if (_hasSavedGames)
        _GameModeButtonData(
          icon: Icons.folder_open_rounded,
          title: 'Continue Game',
          subtitle: 'Resume a saved game',
          gradientColors: const [Color(0xFF2E7D32), Color(0xFF388E3C)],
          shadowColor: kGoodMove,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedGamesScreen()),
            );
            _refreshStats();
          },
        ),
    ];

    return Column(
      children: [
        for (int i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _GameModeButton(data: buttons[i])
              .animate()
              .fadeIn(delay: (300 + i * 80).ms, duration: 400.ms)
              .slideX(begin: 0.08, curve: Curves.easeOut),
        ],
      ],
    );
  }

  // ── Footer buttons ─────────────────────────────────────────────────────────

  Widget _buildFooterButtons() {
    return Row(
      children: [
        Expanded(
          child: _FooterButton(
            icon: Icons.bar_chart_rounded,
            label: 'Statistics',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              );
              _refreshStats();
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _FooterButton(
            icon: Icons.settings_rounded,
            label: 'Settings',
            onTap: _showSettingsDialog,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 400.ms)
        .slideY(begin: 0.08, curve: Curves.easeOut);
  }

  // ── Settings dialog ────────────────────────────────────────────────────────

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              _SettingItem(label: 'Sound Effects', initialValue: true),
              const SizedBox(height: 4),
              _SettingItem(label: 'Move Hints', initialValue: true),
              const SizedBox(height: 4),
              _SettingItem(label: 'Coach Feedback', initialValue: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Game Mode Button ──────────────────────────────────────────────────────────

class _GameModeButtonData {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color shadowColor;
  final VoidCallback onTap;

  const _GameModeButtonData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.shadowColor,
    required this.onTap,
  });
}

class _GameModeButton extends StatelessWidget {
  final _GameModeButtonData data;
  const _GameModeButton({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: data.gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: data.shadowColor.withAlpha(100),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(190),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withAlpha(180), size: 15),
          ],
        ),
      ),
    );
  }
}

// ── Footer Button ─────────────────────────────────────────────────────────────

class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FooterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(14),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.white.withAlpha(30), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white70, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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

// ── Setting Item ──────────────────────────────────────────────────────────────

class _SettingItem extends StatefulWidget {
  final String label;
  final bool initialValue;
  const _SettingItem({required this.label, required this.initialValue});

  @override
  State<_SettingItem> createState() => _SettingItemState();
}

class _SettingItemState extends State<_SettingItem> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.label,
            style: const TextStyle(color: Colors.white70, fontSize: 15)),
        Switch(
          value: _value,
          onChanged: (val) => setState(() => _value = val),
          activeThumbColor: kPrimaryAccent,
          activeTrackColor: kPrimaryAccent.withAlpha(120),
        ),
      ],
    );
  }
}

// ── Stat Item ─────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withAlpha(130), fontSize: 11)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      color: Colors.white.withAlpha(30),
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
