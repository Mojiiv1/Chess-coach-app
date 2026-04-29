import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/stats_service.dart';
import 'services/save_game_service.dart';
import 'services/stockfish_service.dart';
import 'screens/home_screen.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await StatsService.init();
  await SaveGameService.init();

  // Temporary Stockfish smoke test — remove after integration is verified.
  if (kIsWeb) {
    const startingFen =
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    StockfishService.instance
        .evaluatePosition(startingFen, depth: 10)
        .then((r) => debugPrint('[Stockfish test] Starting position: $r'));
  }

  runApp(const ChessCoachApp());
}

class ChessCoachApp extends StatelessWidget {
  const ChessCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Coach AI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kPrimaryAccent,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: kSurface,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: kSurface,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
