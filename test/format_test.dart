import 'package:flutter_test/flutter_test.dart';
import 'package:timbre/core/format.dart';

void main() {
  group('formatDuration', () {
    test('short values', () {
      expect(formatDuration(0), '0:00');
      expect(formatDuration(59000), '0:59');
      expect(formatDuration(125000), '2:05');
    });

    test('hours when needed', () {
      expect(formatDuration(3661000), '1:01:01');
      expect(formatDuration(3600000, alwaysHours: true), '1:00:00');
    });
  });

  group('formatTotal', () {
    test('reads naturally', () {
      expect(formatTotal(30 * 1000), '30 sec');
      expect(formatTotal(48 * 60000), '48 min');
      expect(formatTotal(134 * 60000), '2 hr 14 min');
      expect(formatTotal(120 * 60000), '2 hr');
    });
  });

  group('plural', () {
    test('one and many', () {
      expect(plural(1, 'song'), '1 song');
      expect(plural(0, 'song'), '0 songs');
      expect(plural(2, 'song'), '2 songs');
    });
  });

  group('search text', () {
    test('accents fold and case drops', () {
      expect(normalizeForSearch('Beyoncé'), 'beyonce');
      expect(normalizeForSearch('  SIGUR RÓS  '), 'sigur ros');
    });

    test('natural order puts 2 before 10', () {
      final values = ['Track 10', 'Track 2', 'Track 1'];
      values.sort(compareNatural);
      expect(values, ['Track 1', 'Track 2', 'Track 10']);
    });
  });

  group('formatDay', () {
    test('today and yesterday', () {
      final now = DateTime.now();
      expect(formatDay(now.millisecondsSinceEpoch), 'Today');
      expect(
        formatDay(now.subtract(const Duration(days: 1)).millisecondsSinceEpoch),
        'Yesterday',
      );
    });
  });
}
