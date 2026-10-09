import 'dart:async';

/// The outer automatic progress owner shares its deadline with every callable.
class GameCommandBatch {
  GameCommandBatch({
    this.budget = const Duration(seconds: 12),
    Map<String, Map<String, dynamic>>? commands,
    this.elapsed,
    this.ownsAttempts = true,
  }) : clock = Stopwatch()..start(),
       commands = commands ?? {};
  static final Object _zoneKey = Object();
  static GameCommandBatch? get current =>
      Zone.current[_zoneKey] as GameCommandBatch?;
  final Duration budget;
  final bool ownsAttempts;
  final Duration Function()? elapsed;
  final Stopwatch clock;
  final Map<String, Map<String, dynamic>> commands;
  Duration get remaining => budget - (elapsed?.call() ?? clock.elapsed);
  Future<T> run<T>(Future<T> Function() action) =>
      runZoned(action, zoneValues: {_zoneKey: this});
}
