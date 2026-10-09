import 'package:flutter/foundation.dart';
import 'package:game_kit/core/diagnostics/frame_safe_notifier.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';

enum RecoveryStage {
  connection,
  auth,
  identity,
  subscriptions,
  publicData,
  privateData,
  assets,
  screen,
  ready,
  barrier,
  input,
}

/// Debug-only monotonic episode and batch summaries, independent of the event ring.
class RecoveryMetrics extends ChangeNotifier with FrameSafeNotifier {
  RecoveryMetrics({Duration Function()? clock, this.enabled = kDebugMode})
    : _clock = clock ?? _monotonic;
  static final instance = RecoveryMetrics();
  static final Stopwatch _watch = Stopwatch()..start();
  static Duration _monotonic() => _watch.elapsed;
  final Duration Function() _clock;
  final bool enabled;
  int _episode = 0, _batch = 0;
  Duration? _episodeStarted, _batchStarted;
  final Map<RecoveryStage, Duration> _stages = {};
  final Set<RecoveryStage> _notApplicable = {};
  final List<RecoveryMetricSummary> _summaries = [];
  List<RecoveryMetricSummary> get summaries => List.unmodifiable(_summaries);
  bool get active => enabled && _batchStarted != null;
  void begin({bool newEpisode = true}) {
    if (!enabled) return;
    if (_batchStarted != null) finish(success: false);
    if (newEpisode || _episodeStarted == null) {
      _episode++;
      _episodeStarted = _clock();
      _stages.clear();
      _notApplicable.clear();
    }
    _batch++;
    _batchStarted = _clock();
    notifySafely();
  }

  void notApplicable(RecoveryStage stage) {
    if (!enabled || _episodeStarted == null) return;
    _notApplicable.add(stage);
  }

  void mark(RecoveryStage stage) {
    if (!enabled || _batchStarted == null || _stages.containsKey(stage)) return;
    _notApplicable.remove(stage);
    _stages[stage] = _clock() - _episodeStarted!;
    GameCommunicationLog.instance.add(
      level: GameCommunicationLevel.info,
      title: '복구 단계 완료',
      detail: '${stage.name} · ${_stages[stage]!.inMilliseconds}ms',
      operation: 'recovery',
      traceId: 'episode_$_episode/batch_$_batch',
    );
    notifySafely();
  }

  void finish({required bool success}) {
    if (!enabled || _batchStarted == null) return;
    _summaries.add(
      RecoveryMetricSummary(
        _episode,
        _batch,
        success,
        _clock() - _episodeStarted!,
        Map.unmodifiable(_stages),
        batchElapsed: _clock() - _batchStarted!,
        notApplicable: Set.unmodifiable(_notApplicable),
      ),
    );
    if (_summaries.length > 50) _summaries.removeAt(0);
    _batchStarted = null;
    if (success) _episodeStarted = null;
    notifySafely();
  }
}

@immutable
class RecoveryMetricSummary {
  const RecoveryMetricSummary(
    this.episode,
    this.batch,
    this.success,
    this.elapsed,
    this.stages, {
    this.batchElapsed = Duration.zero,
    this.notApplicable = const {},
  });
  final int episode, batch;
  final bool success;
  final Duration elapsed, batchElapsed;
  final Map<RecoveryStage, Duration> stages;
  final Set<RecoveryStage> notApplicable;
  String stageText(RecoveryStage stage) => notApplicable.contains(stage)
      ? 'N/A'
      : stages.containsKey(stage)
      ? '${stages[stage]!.inMilliseconds}ms'
      : '미완료';
}
