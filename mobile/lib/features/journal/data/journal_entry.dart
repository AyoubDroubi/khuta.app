enum JournalEntryKind { moment, reflection }

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.date,
    required this.kind,
    required this.text,
    this.minutes,
    this.photos = const [],
    required this.createdAt,
  });

  final String id;
  final String date;
  final JournalEntryKind kind;
  final String text;
  final int? minutes;
  final List<String> photos;
  final DateTime createdAt;

  JournalEntry copyWith({
    String? date,
    JournalEntryKind? kind,
    String? text,
    int? minutes,
    bool clearMinutes = false,
    List<String>? photos,
  }) =>
      JournalEntry(
        id: id,
        date: date ?? this.date,
        kind: kind ?? this.kind,
        text: text ?? this.text,
        minutes: clearMinutes ? null : (minutes ?? this.minutes),
        photos: photos ?? this.photos,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'kind': kind.index,
        'text': text,
        'minutes': minutes,
        'photos': photos,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    final kindIndex = (map['kind'] as num?)?.toInt() ?? 0;
    return JournalEntry(
      id: '${map['id'] ?? ''}',
      date: _localDayKey('${map['date'] ?? ''}'),
      kind: JournalEntryKind.values[
          kindIndex.clamp(0, JournalEntryKind.values.length - 1)],
      text: '${map['text'] ?? ''}',
      minutes: (map['minutes'] as num?)?.toInt(),
      photos: (map['photos'] as List? ?? const [])
          .map((value) => '$value')
          .toList(),
      createdAt: DateTime.tryParse('${map['createdAt'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class JournalActivity {
  const JournalActivity({
    required this.id,
    required this.type,
    required this.date,
    required this.occurredAt,
    this.habitId = '',
    this.habitName = '',
    this.journeyId = '',
    this.journeyTitle = '',
    this.milestoneId = '',
    this.milestoneTitle = '',
    this.todoId = '',
    this.todoTitle = '',
    this.text = '',
    this.amount,
    this.seconds,
  });

  final String id;
  final String type;
  final String date;
  final DateTime occurredAt;
  final String habitId;
  final String habitName;
  final String journeyId;
  final String journeyTitle;
  final String milestoneId;
  final String milestoneTitle;
  final String todoId;
  final String todoTitle;
  final String text;
  final double? amount;
  final int? seconds;

  factory JournalActivity.fromMap(Map<String, dynamic> map) => JournalActivity(
        id: '${map['id'] ?? ''}',
        type: '${map['type'] ?? ''}',
        date: '${map['date'] ?? ''}',
        occurredAt: DateTime.tryParse('${map['occurredAtUtc'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        habitId: '${map['habitId'] ?? ''}',
        habitName: '${map['habitName'] ?? ''}',
        journeyId: '${map['journeyId'] ?? ''}',
        journeyTitle: '${map['journeyTitle'] ?? ''}',
        milestoneId: '${map['milestoneId'] ?? ''}',
        milestoneTitle: '${map['milestoneTitle'] ?? ''}',
        todoId: '${map['todoId'] ?? ''}',
        todoTitle: '${map['todoTitle'] ?? ''}',
        text: '${map['text'] ?? ''}',
        amount: (map['amount'] as num?)?.toDouble(),
        seconds: (map['seconds'] as num?)?.toInt(),
      );
}

String _localDayKey(String value) {
  if (value.length != 10) return value;
  final parts = value.split('-');
  if (parts.length != 3 || parts.first.length != 4) return value;
  return '${parts[2]}-${parts[1]}-${parts[0]}';
}
