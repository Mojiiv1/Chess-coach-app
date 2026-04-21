import 'package:flutter/material.dart';
import '../models/saved_game.dart';
import '../services/save_game_service.dart';
import '../utils/constants.dart';
import 'game_screen.dart';

class SavedGamesScreen extends StatefulWidget {
  const SavedGamesScreen({super.key});

  @override
  State<SavedGamesScreen> createState() => _SavedGamesScreenState();
}

class _SavedGamesScreenState extends State<SavedGamesScreen> {
  List<SavedGame> _games = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _games = SaveGameService.getAllSavedGames());
  }

  Future<void> _delete(String id) async {
    await SaveGameService.deleteGame(id);
    _load();
  }

  Future<void> _resume(SavedGame game) async {
    final mode = game.gameMode == 'playerVsAI'
        ? GameMode.playerVsAI
        : GameMode.localMultiplayer;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(gameMode: mode, resumeFrom: game),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Saved Games',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _games.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.save_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('No saved games',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Tap the save icon during a game\nto continue it later.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _games.length,
      itemBuilder: (context, i) => _buildCard(_games[i]),
    );
  }

  Widget _buildCard(SavedGame game) {
    final isVsAI = game.gameMode == 'playerVsAI';
    final icon = isVsAI ? Icons.smart_toy_rounded : Icons.people_rounded;
    final modeLabel = isVsAI ? 'vs AI' : 'Local Multiplayer';
    final diffLabel =
        isVsAI && game.difficulty != null ? ' · ${_cap(game.difficulty!)}' : '';
    final statusColor = game.isComplete ? Colors.white38 : kGoodMove;
    final statusLabel = game.isComplete ? 'Completed' : 'Ongoing';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: game.isComplete ? null : () => _resume(game),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kPrimaryAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: kPrimaryAccent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$modeLabel$diffLabel',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: statusColor.withAlpha(80), width: 1),
                          ),
                          child: Text(statusLabel,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(game.savedAt),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!game.isComplete)
                    IconButton(
                      icon:
                          const Icon(Icons.play_arrow_rounded, color: kPrimaryAccent),
                      onPressed: () => _resume(game),
                      tooltip: 'Resume',
                    ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: kBadMove.withAlpha(180)),
                    onPressed: () => _confirmDelete(game.id),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Delete saved game?',
            style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _delete(id);
            },
            child: Text('Delete', style: TextStyle(color: kBadMove)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
