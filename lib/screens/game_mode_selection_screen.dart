import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'game_screen.dart';

class GameModeSelectionScreen extends StatefulWidget {
  final GameMode gameMode;
  const GameModeSelectionScreen({super.key, required this.gameMode});

  @override
  State<GameModeSelectionScreen> createState() =>
      _GameModeSelectionScreenState();
}

class _GameModeSelectionScreenState extends State<GameModeSelectionScreen> {
  String _difficulty = 'intermediate';

  static const _difficulties = [
    (
      id: 'beginner',
      label: 'Beginner',
      desc: 'Perfect for learning the basics',
      color: Color(0xFF66BB6A),
      icon: Icons.sentiment_satisfied_rounded,
    ),
    (
      id: 'easy',
      label: 'Easy',
      desc: 'A relaxed challenge',
      color: Color(0xFF4FC3F7),
      icon: Icons.sentiment_neutral_rounded,
    ),
    (
      id: 'intermediate',
      label: 'Intermediate',
      desc: 'A balanced opponent',
      color: Color(0xFFFFA726),
      icon: Icons.psychology_rounded,
    ),
    (
      id: 'advanced',
      label: 'Advanced',
      desc: 'For serious players only',
      color: Color(0xFFEF5350),
      icon: Icons.whatshot_rounded,
    ),
  ];

  void _startGame() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          gameMode: widget.gameMode,
          difficulty: _difficulty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAI = widget.gameMode == GameMode.playerVsAI;

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
          child: Column(
            children: [
              _buildHeader(isAI),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAI) ...[
                        _buildDifficultySection(),
                        const SizedBox(height: 32),
                      ] else ...[
                        _buildMultiplayerInfo(),
                        const SizedBox(height: 32),
                      ],
                      _buildStartButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isAI) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            isAI ? 'Play vs AI' : 'Local Multiplayer',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Select Difficulty',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a level that matches your skill',
          style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 14),
        ),
        const SizedBox(height: 20),
        for (final d in _difficulties)
          _DifficultyCard(
            label: d.label,
            desc: d.desc,
            color: d.color,
            icon: d.icon,
            isSelected: _difficulty == d.id,
            onTap: () => setState(() => _difficulty = d.id),
          ),
      ],
    );
  }

  Widget _buildMultiplayerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Local Multiplayer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withAlpha(40), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BCD4).withAlpha(40),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.people_rounded,
                        color: Color(0xFF00BCD4), size: 30),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Two Players, One Device',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Take turns passing the device. No AI involved.',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _startGame,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryAccent,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: kPrimaryAccent.withAlpha(100),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, size: 26),
            SizedBox(width: 8),
            Text(
              'Start Game',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Difficulty Card ───────────────────────────────────────────────────────────

class _DifficultyCard extends StatelessWidget {
  final String label;
  final String desc;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.label,
    required this.desc,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(40) : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white.withAlpha(30),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(isSelected ? 60 : 30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      color: isSelected ? Colors.white60 : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}
