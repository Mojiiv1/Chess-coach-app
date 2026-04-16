class GameStats {
  final int wins;
  final int losses;
  final int draws;
  final String? lastResult; // 'win' | 'loss' | 'draw' | null

  const GameStats({
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.lastResult,
  });

  int get gamesPlayed => wins + losses + draws;

  int get winRatePercentage =>
      gamesPlayed == 0 ? 0 : (wins * 100 ~/ gamesPlayed);
}
