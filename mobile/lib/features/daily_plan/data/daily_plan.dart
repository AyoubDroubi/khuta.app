class DailyPlan {
  const DailyPlan({
    required this.date,
    this.items = const [],
    this.updatedAt,
    this.version = 0,
  });

  static const maxItems = 3;

  final String date;
  final List<DailyPlanItem> items;
  final DateTime? updatedAt;
  final int version;

  DailyPlan copyWith({
    List<DailyPlanItem>? items,
    DateTime? updatedAt,
    int? version,
  }) =>
      DailyPlan(
        date: date,
        items: items ?? this.items,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version ?? this.version,
      );

  Map<String, dynamic> toMap() => {
        'date': date,
        'items': [for (final item in items) item.toMap()],
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        'version': version,
      };

  factory DailyPlan.fromMap(Map<String, dynamic> map) {
    final items = (map['items'] as List? ?? const [])
        .map(
          (value) => DailyPlanItem.fromMap(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    if (items.length > maxItems) {
      throw const FormatException(
        'Daily Plan contains more than three priorities.',
      );
    }

    return DailyPlan(
      date: (map['date'] ?? '') as String,
      items: items,
      updatedAt: DateTime.tryParse('${map['updatedAt'] ?? ''}'),
      version: (map['version'] as num?)?.toInt() ?? 0,
    );
  }
}

enum DailyPlanSourceType { habit, todo, journeyMilestone }

class DailyPlanItem {
  const DailyPlanItem({
    required this.type,
    required this.sourceId,
    this.milestoneId,
  });

  final DailyPlanSourceType type;
  final String sourceId;
  final String? milestoneId;

  String get key => '${type.name}:$sourceId:${milestoneId ?? ''}';

  Map<String, dynamic> toMap() => {
        'type': type.index,
        'sourceId': sourceId,
        if (milestoneId != null) 'milestoneId': milestoneId,
      };

  factory DailyPlanItem.fromMap(Map<String, dynamic> map) {
    final type = (map['type'] as num?)?.toInt();
    if (type == null ||
        type < 0 ||
        type >= DailyPlanSourceType.values.length) {
      throw const FormatException('Invalid Daily Plan source type.');
    }

    final sourceId = '${map['sourceId'] ?? ''}'.trim();
    if (sourceId.isEmpty) {
      throw const FormatException('Daily Plan source ID is required.');
    }

    final milestoneId = map['milestoneId'] == null
        ? null
        : '${map['milestoneId']}'.trim();
    final sourceType = DailyPlanSourceType.values[type];

    if (sourceType == DailyPlanSourceType.journeyMilestone) {
      if (milestoneId == null || milestoneId.isEmpty) {
        throw const FormatException(
          'Journey milestone Daily Plan source requires a milestone ID.',
        );
      }
    } else if (milestoneId != null && milestoneId.isNotEmpty) {
      throw const FormatException(
        'Only Journey milestone sources can include a milestone ID.',
      );
    }

    return DailyPlanItem(
      type: sourceType,
      sourceId: sourceId,
      milestoneId: milestoneId,
    );
  }
}
