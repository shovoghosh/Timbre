import 'dart:math' as math;

/// "3:45" or "1:02:33".
String formatDuration(int milliseconds, {bool alwaysHours = false}) {
  final total = (milliseconds / 1000).round().clamp(0, 359999);
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final pad = seconds.toString().padLeft(2, '0');
  if (hours > 0 || alwaysHours) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$pad';
  }
  return '$minutes:$pad';
}

/// "2 hr 14 min", "48 min", "32 sec".
String formatTotal(int milliseconds) {
  if (milliseconds < 60000) {
    return '${math.max(1, (milliseconds / 1000).round())} sec';
  }
  final minutes = (milliseconds / 60000).round();
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }
  return '$minutes min';
}

/// "12 songs", "1 song".
String plural(int count, String singular, [String? pluralWord]) {
  return '$count ${count == 1 ? singular : (pluralWord ?? '${singular}s')}';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  final mb = bytes / (1024 * 1024);
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
  if (mb >= 10) return '${mb.round()} MB';
  return '${mb.toStringAsFixed(1)} MB';
}

/// Removes accents and lowers case so "Beyonce" finds "Beyoncé".
String normalizeForSearch(String value) {
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y', 'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
  };
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(accents[char] ?? char);
  }
  return buffer.toString().trim();
}

/// Case insensitive compare that understands numbers, so "Track 2" comes
/// before "Track 10".
int compareNatural(String a, String b) {
  final left = a.toLowerCase();
  final right = b.toLowerCase();
  if (left == right) return 0;
  var i = 0;
  var j = 0;
  while (i < left.length && j < right.length) {
    final ca = left.codeUnitAt(i);
    final cb = right.codeUnitAt(j);
    final aDigit = ca >= 48 && ca <= 57;
    final bDigit = cb >= 48 && cb <= 57;
    if (aDigit && bDigit) {
      var ni = i;
      var nj = j;
      while (ni < left.length && _isDigit(left.codeUnitAt(ni))) {
        ni++;
      }
      while (nj < right.length && _isDigit(right.codeUnitAt(nj))) {
        nj++;
      }
      final na = int.tryParse(left.substring(i, ni)) ?? 0;
      final nb = int.tryParse(right.substring(j, nj)) ?? 0;
      if (na != nb) return na.compareTo(nb);
      i = ni;
      j = nj;
      continue;
    }
    if (ca != cb) return ca.compareTo(cb);
    i++;
    j++;
  }
  return left.length.compareTo(right.length);
}

bool _isDigit(int code) => code >= 48 && code <= 57;

/// "Today", "Yesterday", "12 Nov".
String formatDay(int epochMs) {
  if (epochMs == 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  if (date.year == now.year) return '${date.day} ${months[date.month - 1]}';
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
