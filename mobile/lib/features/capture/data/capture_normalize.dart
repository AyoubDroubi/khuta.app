/// Removes diacritics (U+064B-U+065F, U+0670) and tatweel (U+0640).
/// Changes the length, so apply it once, first, to the original text.
String stripMarks(String s) {
  final out = StringBuffer();
  for (final unit in s.codeUnits) {
    final mark = (unit >= 0x064B && unit <= 0x065F) ||
        unit == 0x0670 ||
        unit == 0x0640;
    if (!mark) out.writeCharCode(unit);
  }
  return out.toString();
}

/// Folds spelling variants so text can be matched: lower-case, alef forms to
/// ا, ى to ي, ة to ه, Arabic-Indic and Persian digits to 0-9.
///
/// Always returns a string of the same length, so an index found in the folded
/// text points at the same place in the unfolded text.
String foldLetters(String s) {
  final out = StringBuffer();
  for (final unit in s.codeUnits) {
    out.writeCharCode(_fold(unit));
  }
  return out.toString();
}

int _fold(int unit) {
  switch (unit) {
    case 0x0623: // أ
    case 0x0625: // إ
    case 0x0622: // آ
    case 0x0671: // ٱ
      return 0x0627;
    case 0x0649: // ى
      return 0x064A;
    case 0x0629: // ة
      return 0x0647;
  }
  if (unit >= 0x41 && unit <= 0x5A) return unit + 0x20; // A-Z only: keeps length
  if (unit >= 0x0660 && unit <= 0x0669) return 0x30 + (unit - 0x0660);
  if (unit >= 0x06F0 && unit <= 0x06F9) return 0x30 + (unit - 0x06F0);
  return unit;
}

/// Characters that make up a word for matching: the Arabic block, a-z, 0-9.
/// Text is folded first, so upper-case letters never appear.
const captureLetters = r'\u0600-\u06FFa-z0-9';

/// [body] as a whole word: not preceded or followed by a word character.
String wordBounded(String body) =>
    '(?<![$captureLetters])(?:$body)(?![$captureLetters])';
