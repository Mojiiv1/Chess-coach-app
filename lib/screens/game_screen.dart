import 'package:flutter/material.dart';
import '../models/move.dart';
import '../services/game_service.dart';
import '../utils/constants.dart';
import '../widgets/chess_board.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _game = GameService();

  String? _selectedSquare;
  Set<String> _validMoves = {};
  String? _statusMessage;

  void _onSquareTapped(String square) {
    if (_game.isGameOver) return;

    setState(() {
      if (_selectedSquare == null) {
        // First tap: select a piece
        final moves = _game.getLegalMoves(square);
        if (moves.isNotEmpty) {
          _selectedSquare = square;
          _validMoves = moves.toSet();
          _statusMessage = null;
        } else {
          // Empty square or opponent piece with no moves — ignore
          _selectedSquare = null;
          _validMoves = {};
        }
      } else if (_selectedSquare == square) {
        // Tapped selected square again — deselect
        _selectedSquare = null;
        _validMoves = {};
      } else if (_validMoves.contains(square)) {
        // Second tap on a valid destination: execute move
        final move = _game.makeMove(_selectedSquare!, square);
        _selectedSquare = null;
        _validMoves = {};

        if (move != null) {
          _updateStatus();
        }
      } else {
        // Tapped a different square — try selecting it instead
        final moves = _game.getLegalMoves(square);
        if (moves.isNotEmpty) {
          _selectedSquare = square;
          _validMoves = moves.toSet();
          _statusMessage = null;
        } else {
          _selectedSquare = null;
          _validMoves = {};
        }
      }
    });
  }

  void _updateStatus() {
    if (_game.isCheckmate()) {
      final winner = _game.turn == 'white' ? 'Black' : 'White';
      _statusMessage = 'Checkmate! $winner wins.';
    } else if (_game.isDraw()) {
      _statusMessage = 'Draw!';
    } else if (_game.isInCheck()) {
      _statusMessage = 'Check!';
    } else {
      _statusMessage = null;
    }
  }

  void _reset() {
    setState(() {
      _game.reset();
      _selectedSquare = null;
      _validMoves = {};
      _statusMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWhiteTurn = _game.isWhiteTurn;
    final history = _game.history;

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
            tooltip: 'New game',
            onPressed: _reset,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Black player
            _PlayerBar(
              name: 'Black',
              isActive: !isWhiteTurn && !_game.isGameOver,
              color: Colors.black,
            ),

            const SizedBox(height: 6),

            // Board
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ChessBoard(
                fen: _game.fen,
                selectedSquare: _selectedSquare,
                validMoves: _validMoves,
                onSquareTapped: _onSquareTapped,
              ),
            ),

            const SizedBox(height: 6),

            // White player
            _PlayerBar(
              name: 'White',
              isActive: isWhiteTurn && !_game.isGameOver,
              color: Colors.white,
            ),

            const SizedBox(height: 10),

            // Status banner
            if (_statusMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: kAppPrimary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kAppPrimary.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Move history
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kAppSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: history.isEmpty
                    ? const Center(
                        child: Text(
                          'No moves yet',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      )
                    : _MoveHistoryList(moves: history),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PlayerBar extends StatelessWidget {
  final String name;
  final bool isActive;
  final Color color;

  const _PlayerBar({
    required this.name,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? kAppPrimary : Colors.white24,
                width: isActive ? 2.5 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: kAppPrimary.withValues(alpha: 0.6),
                        blurRadius: 6,
                      )
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white38,
              fontSize: 13,
              fontWeight:
                  isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 6),
            const Text(
              'to move',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoveHistoryList extends StatelessWidget {
  final List<Move> moves;
  const _MoveHistoryList({required this.moves});

  @override
  Widget build(BuildContext context) {
    // Group into pairs (white move, black move)
    final rows = <(int, Move, Move?)>[];
    for (int i = 0; i < moves.length; i += 2) {
      rows.add((
        i ~/ 2 + 1,
        moves[i],
        i + 1 < moves.length ? moves[i + 1] : null,
      ));
    }

    return ListView.builder(
      reverse: true,
      itemCount: rows.length,
      itemBuilder: (_, idx) {
        final (num, white, black) = rows[rows.length - 1 - idx];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$num.',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
              _MoveChip(notation: white.notation, isCapture: white.isCapture),
              const SizedBox(width: 6),
              if (black != null)
                _MoveChip(
                    notation: black.notation, isCapture: black.isCapture),
            ],
          ),
        );
      },
    );
  }
}

class _MoveChip extends StatelessWidget {
  final String notation;
  final bool isCapture;
  const _MoveChip({required this.notation, required this.isCapture});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCapture
            ? Colors.redAccent.withValues(alpha: 0.2)
            : kAppPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        notation,
        style: TextStyle(
          color: isCapture ? Colors.redAccent[100] : Colors.white70,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
