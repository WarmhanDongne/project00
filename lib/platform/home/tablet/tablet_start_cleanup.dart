import 'package:game_kit/core/diagnostics/startup_measurements.dart';

/// One seating route owns one successful start's cleanup lookup.
/// Errors are observed immediately; only the same live attempt may retry.
class TabletStartCleanup {
  TabletStartCleanup({required this.capture, required this.isCurrent})
    : _measurement = StartupMeasurements.instance.beginSpan('cleanup_scope');
  final MeasurementSpan _measurement;
  final Future<Map<String, dynamic>?> Function() capture;
  final bool Function() isCurrent;
  Future<Map<String, dynamic>?>? _pending;
  bool _invalid = false;
  bool get current => !_invalid && isCurrent();

  void prefetch() {
    if (current && _pending == null) {
      _measurement.event('cleanup_prefetch');
      _pending = _read();
    }
  }

  Future<Map<String, dynamic>?> _read() async {
    if (!current) return null;
    final span = _measurement.child('cleanup_lookup');
    try {
      final value = await capture();
      span.end(
        !current
            ? 4
            : value == null
            ? 2
            : 1,
      );
      return current ? value : null;
    } catch (_) {
      span.end(3);
      return null;
    }
  }

  Future<Map<String, dynamic>?> target() async {
    if (!current) return null;
    final pending = _pending;
    // No prefetch (unknown identity): preserve the original transition lookup.
    if (pending == null) {
      final value = await _read();
      _measurement.end(current ? 1 : 4);
      return value;
    }
    final value = await pending;
    if (!current) return null;
    Map<String, dynamic>? result = value;
    if (result == null) {
      _measurement.event('cleanup_fallback');
      result = await _read();
    }
    _measurement.end(current ? 1 : 4);
    return result;
  }

  void invalidate() {
    _measurement.event('cleanup_invalidated');
    _measurement.end(4);
    _invalid = true;
  }
}
