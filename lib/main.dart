import 'package:flutter/material.dart';
import 'screens/game_screen.dart';
import 'utils/constants.dart';

void main() {
  runApp(const ChessCoachApp());
}

class ChessCoachApp extends StatelessWidget {
  const ChessCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Coach',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kAppPrimary),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAppPrimary,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: kAppBackground,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const GameScreen(),
      },
    );
  }
}
