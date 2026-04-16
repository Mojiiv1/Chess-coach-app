class GameStats {
  final int wins;
  final int losses;
  final int draws;
  final String? lastResult;

  const GameStats({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.lastResult,
  });

  int get gamesPlayed => wins + losses + draws;

  int get winRatePercentage {
    if (gamesPlayed == 0) return 0;
    return (wins * 100 ~/ gamesPlayed);
  }
}
