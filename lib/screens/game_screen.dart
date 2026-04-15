import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../widgets/chess_board.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String _fen = kStartingFen;
  String? _lastTapped;
  final List<String> _tapLog = [];

  void _onSquareTapped(String square) {
    setState(() {
      _lastTapped = square;
      _tapLog.insert(0, square);
      if (_tapLog.length > 8) _tapLog.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        backgroundColor: kAppSurface,
        title: const Text(
          'Chess Coach',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reset board',
            onPressed: () => setState(() {
              _fen = kStartingFen;
              _lastTapped = null;
              _tapLog.clear();
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Player label (black)
            const _PlayerLabel(
              name: 'Black',
              color: Colors.black,
              textColor: Colors.white,
            ),

            const SizedBox(height: 8),

            // Board
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ChessBoard(
                fen: _fen,
                onSquareTapped: _onSquareTapped,
              ),
            ),

            const SizedBox(height: 8),

            // Player label (white)
            const _PlayerLabel(
              name: 'White',
              color: Colors.white,
              textColor: Colors.black,
            ),

            const SizedBox(height: 16),

            // Tap log
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kAppSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lastTapped != null
                          ? 'Selected: $_lastTapped'
                          : 'Tap a square to select',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _tapLog
                          .map((sq) => Chip(
                                label: Text(sq,
                                    style: const TextStyle(fontSize: 12)),
                                backgroundColor: kAppPrimary.withValues(alpha: 0.3),
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PlayerLabel extends StatelessWidget {
  final String name;
  final Color color;
  final Color textColor;

  const _PlayerLabel({
    required this.name,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
