/// One seating route owns one successful start's cleanup lookup.
/// Errors are observed immediately; only the same live attempt may retry.
class TabletStartCleanup {
  TabletStartCleanup({required this.capture, required this.isCurrent});
  final Future<Map<String, dynamic>?> Function() capture;
  final bool Function() isCurrent;
  Future<Map<String, dynamic>?>? _pending;
  bool _invalid = false;
  bool get current => !_invalid && isCurrent();

  void prefetch() {
    if (current) _pending ??= _read();
  }

  Future<Map<String, dynamic>?> _read() async {
    if (!current) return null;
    try {
      final value = await capture();
      return current ? value : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> target() async {
    if (!current) return null;
    final pending = _pending;
    // No prefetch (unknown identity): preserve the original transition lookup.
    if (pending == null) return _read();
    final value = await pending;
    if (!current) return null;
    return value ?? await _read();
  }

  void invalidate() => _invalid = true;
}
