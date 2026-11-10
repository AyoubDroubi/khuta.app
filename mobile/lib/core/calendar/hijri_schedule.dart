/// App-wide Hijri day adjustment (−2…+2) used by habit schedules. Set from settings at startup and whenever the user changes it, so
/// `Habit.isScheduledOn` stays a pure model method.
abstract final class HijriSchedule {
  static int _adjust = 0;

  static int get adjust => _adjust;

  static set adjust(int days) => _adjust = days.clamp(-2, 2);
}
