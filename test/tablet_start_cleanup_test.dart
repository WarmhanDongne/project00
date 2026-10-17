import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/tablet/tablet_start_cleanup.dart';

void main() {
  final target = <String, dynamic>{'gameInstanceId': 'started-game'};
  test(
    'lookup overlaps animation and a completed lookup adds no second read',
    () async {
      var reads = 0;
      final ready = Completer<Map<String, dynamic>?>();
      final lookup = TabletStartCleanup(
        capture: () {
          reads++;
          return ready.future;
        },
        isCurrent: () => true,
      );
      lookup.prefetch();
      lookup.prefetch(); // repeated build/notification
      expect(reads, 1);
      ready.complete(target); // lookup ends while animation is still running
      await Future<void>.delayed(Duration.zero);
      expect(await lookup.target(), same(target));
      expect(reads, 1);
    },
  );
  test(
    'animation finishing first waits for this attempt rather than another read',
    () async {
      final ready = Completer<Map<String, dynamic>?>();
      var completed = false;
      final lookup = TabletStartCleanup(
        capture: () => ready.future,
        isCurrent: () => true,
      );
      lookup.prefetch();
      final transition = lookup.target().then((value) {
        completed = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, false);
      ready.complete(target);
      expect(await transition, same(target));
    },
  );
  test(
    'failed prefetch is observed immediately and retries once at transition',
    () async {
      var reads = 0;
      final lookup = TabletStartCleanup(
        capture: () async {
          if (++reads == 1) throw StateError('read failed');
          return target;
        },
        isCurrent: () => true,
      );
      lookup.prefetch();
      await Future<void>.delayed(Duration.zero);
      expect(await lookup.target(), target);
      expect(reads, 2);
    },
  );
  test(
    'two failed reads preserve nullable cleanup, without repeated requests',
    () async {
      var reads = 0;
      final lookup = TabletStartCleanup(
        capture: () async {
          reads++;
          return null;
        },
        isCurrent: () => true,
      );
      lookup.prefetch();
      expect(await lookup.target(), isNull);
      expect(reads, 2);
    },
  );
  for (final reason in [
    'dispose',
    'account',
    'same-code new room',
    'connection',
    'new start',
  ]) {
    test(
      '$reason discards late target and never retries the latest room',
      () async {
        final ready = Completer<Map<String, dynamic>?>();
        var current = true, reads = 0;
        final old = TabletStartCleanup(
          capture: () {
            reads++;
            return ready.future;
          },
          isCurrent: () => current,
        );
        old.prefetch();
        final transition = old.target();
        if (reason == 'dispose' || reason == 'new start') {
          old.invalidate();
        } else {
          current = false;
        }
        ready.complete(target);
        expect(await transition, isNull);
        expect(await old.target(), isNull);
        expect(reads, 1);
        expect(old.current, false);
      },
    );
  }
  test('unknown identity uses only the original transition read', () async {
    var reads = 0;
    final lookup = TabletStartCleanup(
      capture: () async {
        reads++;
        return target;
      },
      isCurrent: () => true,
    );
    expect(reads, 0);
    expect(await lookup.target(), target);
    expect(reads, 1);
  });
}
