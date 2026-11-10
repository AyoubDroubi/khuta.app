import 'package:intl/intl.dart';

/// Arabic uses Western digits (0–9) everywhere.
/// Material's Arabic date formats default to Eastern Arabic digits, so turn
/// native digits off for Arabic before any date is formatted.
void useWesternDigits() {
  DateFormat.useNativeDigitsByDefaultFor('ar', false);
}
