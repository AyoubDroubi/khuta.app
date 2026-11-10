/// Per-habit Recovery settings (opt-in, off by default).
class RecoveryConfig {
  const RecoveryConfig({
    this.enabled = false,
    this.firstDelayHours = 0,
    this.fixedTime = false,
    this.repeatHours = 24,
    this.hour = 20,
    this.minute = 0,
    this.count = 3,
    this.enabledAt,
  });

  static const off = RecoveryConfig();
  static const maxCount = 10;
  static const maxHours = 24 * 30;

  final bool enabled;

  /// Hours after the habit becomes eligible until the first reminder.
  final int firstDelayHours;

  /// False: repeat every [repeatHours]; true: at [hour]:[minute] each later day.
  final bool fixedTime;
  final int repeatHours;
  final int hour;
  final int minute;

  /// Total reminders in one cycle; 0 = none (the habit is still listed).
  final int count;

  /// When Recovery was switched on. A cycle never starts before it, so
  /// enabling Recovery on an old, lapsed habit still gives a fresh sequence.
  final DateTime? enabledAt;

  RecoveryConfig copyWith({
    bool? enabled,
    int? firstDelayHours,
    bool? fixedTime,
    int? repeatHours,
    int? hour,
    int? minute,
    int? count,
    DateTime? enabledAt,
  }) =>
      RecoveryConfig(
        enabled: enabled ?? this.enabled,
        firstDelayHours: firstDelayHours ?? this.firstDelayHours,
        fixedTime: fixedTime ?? this.fixedTime,
        repeatHours: repeatHours ?? this.repeatHours,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        count: count ?? this.count,
        enabledAt: enabledAt ?? this.enabledAt,
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'firstDelayHours': firstDelayHours,
        'fixedTime': fixedTime,
        'repeatHours': repeatHours,
        'hour': hour,
        'minute': minute,
        'count': count,
        if (enabledAt != null) 'enabledAt': enabledAt!.toUtc().toIso8601String(),
      };

  /// Tolerant: missing or malformed values fall back to the defaults.
  factory RecoveryConfig.fromMap(Object? raw) {
    if (raw is! Map) return off;
    int number(String key, int fallback, int min, int max) {
      final value = raw[key];
      return value is num ? value.toInt().clamp(min, max) : fallback;
    }

    return RecoveryConfig(
      enabled: raw['enabled'] == true,
      firstDelayHours: number('firstDelayHours', 0, 0, maxHours),
      fixedTime: raw['fixedTime'] == true,
      repeatHours: number('repeatHours', 24, 1, maxHours),
      hour: number('hour', 20, 0, 23),
      minute: number('minute', 0, 0, 59),
      count: number('count', 3, 0, maxCount),
      enabledAt: DateTime.tryParse(raw['enabledAt']?.toString() ?? '')?.toLocal(),
    );
  }
}
