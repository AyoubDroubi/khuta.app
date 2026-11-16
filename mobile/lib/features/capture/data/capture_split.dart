/// Splits typed text into separate clauses, one per thing to do.
///
/// Conservative on purpose: it splits on clear separators and on a
/// conjunction followed by a marker word, never on a lone "و". When in doubt it
/// does not split, because a wrong split is worse than one editable item.
library;

const maxClauses = 20;

const _letters = r'؀-ۿa-z0-9';

// Commas inside numbers ("1,234") do not separate.
final _separators = RegExp(r'(?<![\d]),|,(?![\d])|[،;؛\n]|(?<=[.!؟?])\s+');

final _markerBefore = RegExp(
  r'\s+(?=(?:و(?:بدي|لازم|ذكرني|نبهني)|وبعدين|وبعدها|ثم|and\s+remind\s+me)'
  '(?![$_letters]))',
);

final _dropWhole = RegExp(r'^(?:وبعدين|وبعدها|ثم)\s+');
final _andRemind = RegExp(r'^and\s+(?=remind\s+me)', caseSensitive: false);
final _vavMarker = RegExp('^و(?=(?:بدي|لازم|ذكرني|نبهني)(?![$_letters]))');
final _vavAfterSeparator = RegExp(r'^و(?=[ء-ي])');

int _words(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

List<String> splitClauses(String text) {
  final pieces = <String>[];

  final parts = text.split(_separators);
  for (var p = 0; p < parts.length; p++) {
    final part = parts[p].trim();
    if (part.isEmpty) continue;

    final cuts = [for (final m in _markerBefore.allMatches(part)) m];
    var start = 0;
    final segments = <String>[];
    for (final m in cuts) {
      segments.add(part.substring(start, m.start));
      start = m.end;
    }
    segments.add(part.substring(start));

    for (var s = 0; s < segments.length; s++) {
      var seg = segments[s].trim();
      seg = seg
          .replaceFirst(_dropWhole, '')
          .replaceFirst(_andRemind, '')
          .replaceFirst(_vavMarker, '');
      if (s == 0 && p > 0) seg = seg.replaceFirst(_vavAfterSeparator, '');
      seg = seg.trim();
      if (seg.isNotEmpty) pieces.add(seg);
    }
    if (pieces.length > maxClauses * 3) break;
  }

  final out = <String>[];
  var pending = '';
  for (var seg in pieces) {
    if (pending.isNotEmpty) {
      seg = '$pending $seg';
      pending = '';
    }
    if (_words(seg) < 2) {
      if (out.isNotEmpty) {
        out[out.length - 1] = '${out.last} $seg';
      } else {
        pending = seg;
      }
    } else {
      out.add(seg);
    }
  }
  if (pending.isNotEmpty) {
    if (out.isNotEmpty) {
      out[out.length - 1] = '${out.last} $pending';
    } else {
      out.add(pending);
    }
  }
  return out.take(maxClauses).toList();
}
