/// Splits typed text into separate clauses, one per thing to do.
///
/// Conservative on purpose: it splits on clear separators and on a
/// conjunction followed by a marker word, never on a lone "و". When in doubt it
/// does not split, because a wrong split is worse than one editable item.
library;

import 'package:khuta/features/capture/data/capture_normalize.dart';

const maxClauses = 20;

const _letters = captureLetters;

// Commas inside numbers ("1,234") do not separate.
// A sentence end needs two letters before it, so "د. أحمد" does not split;
// longer titles ("Dr.", "Mrs.") are protected by [_abbreviation].
final _separators = RegExp(
  r'(?<![\d]),|,(?![\d])|[،;؛\n]|(?<=[\p{L}\p{N}]{2}[.!؟?])\s+',
  unicode: true,
);

final _markerBefore = RegExp(
  r'\s+(?=(?:و(?:بدي|لازم|ذكرني|نبهني)|وبعدين|وبعدها|ثم|and\s+remind\s+me)'
  '(?![$_letters]))',
  caseSensitive: false,
);

// Common abbreviations whose dot does not end a sentence ("Mrs. Smith").
final _abbreviation = RegExp(
  // Titles only: "etc." and "no." usually do end a sentence.
  r'(?<![A-Za-z])(Mrs|Mr|Ms|Dr|Prof|Eng|Jr|Sr|Mt|St)\.',
  caseSensitive: false,
);
const _keptDot = '\u2024';

// Also a lone marker at the end ("اجتماع بكرة وبعدين"), which leaves nothing.
final _dropWhole = RegExp(r'^(?:وبعدين|وبعدها|ثم)(?:\s+|$)');
final _andRemind = RegExp(r'^and\s+(?=remind\s+me)', caseSensitive: false);
final _vavMarker = RegExp('^و(?=(?:بدي|لازم|ذكرني|نبهني)(?![$_letters]))');

// After a separator a leading "و" is "and" only when what follows is clearly a
// new word: "ال...", a hamza form ("وأحجز"), or a common verb ("وكلم"). Any
// other word keeps its و, because many words and names start with it (وليد،
// وحدة، وائل، ورق).
const _verbsAfterVav = {
  'كلم', 'اتصل', 'اشتري', 'اشتر', 'روح', 'رح', 'خلص', 'جيب', 'ابعت', 'احجز',
  'جدد', 'راجع', 'نظف', 'رتب', 'زور', 'حضر', 'اطبخ', 'اغسل', 'خذ', 'خد',
  'اخد', 'اخذ', 'ادفع', 'ذاكر', 'صلي', 'رد', 'سجل', 'ارجع', 'رجع', 'شوف',
  'اسال', 'اطلب', 'حط', 'نزل', 'طلع', 'بلش', 'ابدا', 'قول', 'دور', 'صلح',
  'غسل', 'نام', 'كمل', 'اكتب', 'اعمل', 'امشي',
};

String _stripVav(String seg) {
  if (!seg.startsWith('و') || seg.length < 2) return seg;
  final rest = seg.substring(1);
  final word = foldLetters(rest.split(RegExp(r'\s+')).first);
  final hamza = 'أإآ'.contains(rest[0]);
  final conjunction =
      // "والدتي" (my mother), "والدي" and "والله" are words, not "and" + ال.
      (word.startsWith('ال') && !word.startsWith('الد') && word != 'الله') ||
      hamza ||
      _verbsAfterVav.contains(word);
  return conjunction ? rest : seg;
}

int _words(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

/// The clauses of [text], in order.
List<String> splitClauses(String text) =>
    [for (final c in splitClauseLinks(text)) c.text];

/// The clauses of [text], each with whether it followed "and then"
/// (وبعدين، وبعدها، ثم): such a clause happens on the same day as the one
/// before it.
List<({String text, bool then})> splitClauseLinks(String text) {
  // `marker`: the piece began at a marker split (وبعدين، وبدي، ...), not at a
  // comma or a sentence end.
  final pieces = <({String text, bool then, bool marker})>[];

  final protected =
      text.replaceAllMapped(_abbreviation, (m) => '${m[1]}$_keptDot');
  final parts = protected.split(_separators);
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
      final then = _dropWhole.hasMatch(seg);
      seg = seg
          .replaceFirst(_dropWhole, '')
          .replaceFirst(_andRemind, '')
          .replaceFirst(_vavMarker, '');
      if (s == 0 && p > 0) seg = _stripVav(seg);
      seg = seg.replaceAll(RegExp(r'^[.!؟?\s]+|[.!؟?\s]+$'), '');
      if (seg.isNotEmpty) pieces.add((text: seg, then: then, marker: s > 0));
    }
    if (pieces.length > maxClauses * 3) break;
  }

  // A one-word piece after a comma joins its neighbour ("ملح، فلفل"). Across a
  // marker it is an item of its own ("سهرة وبعدين نوم").
  final out = <({String text, bool then})>[];
  ({String text, bool then})? pending;
  for (final piece in pieces) {
    var current = (text: piece.text, then: piece.then);
    if (pending != null) {
      if (piece.marker) {
        out.add(pending);
      } else {
        current = (text: '${pending.text} ${piece.text}', then: pending.then);
      }
      pending = null;
    }
    if (_words(current.text) < 2 && !piece.marker) {
      if (out.isNotEmpty) {
        out[out.length - 1] =
            (text: '${out.last.text} ${current.text}', then: out.last.then);
      } else {
        pending = current;
      }
    } else {
      out.add(current);
    }
  }
  if (pending != null) {
    if (out.isNotEmpty) {
      out[out.length - 1] =
          (text: '${out.last.text} ${pending.text}', then: out.last.then);
    } else {
      out.add(pending);
    }
  }
  return [
    for (final c in out.take(maxClauses))
      (text: c.text.replaceAll(_keptDot, '.'), then: c.then),
  ];
}
