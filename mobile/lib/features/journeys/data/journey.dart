enum JourneyStatus { planned, active, completed, archived }

class JourneyMilestone {
  const JourneyMilestone({
    required this.id,
    required this.title,
    required this.completed,
    required this.order,
    this.completedAt,
  });

  final String id;
  final String title;
  final bool completed;
  final int order;
  final DateTime? completedAt;

  JourneyMilestone copyWith({
    String? title,
    bool? completed,
    int? order,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) =>
      JourneyMilestone(
        id: id,
        title: title ?? this.title,
        completed: completed ?? this.completed,
        order: order ?? this.order,
        completedAt:
            clearCompletedAt ? null : (completedAt ?? this.completedAt),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'completed': completed,
        'order': order,
        if (completedAt != null)
          'completedAt': completedAt!.toUtc().toIso8601String(),
      };

  factory JourneyMilestone.fromMap(Map<String, dynamic> map) =>
      JourneyMilestone(
        id: '${map['id'] ?? ''}',
        title: '${map['title'] ?? ''}',
        completed: map['completed'] == true,
        order: (map['order'] as num?)?.toInt() ?? 0,
        completedAt: DateTime.tryParse('${map['completedAt'] ?? ''}'),
      );
}

class Journey {
  const Journey({
    required this.id,
    required this.title,
    this.description = '',
    this.icon = 'route',
    this.coverPath = '',
    this.startDate = '',
    this.targetDate = '',
    this.status = JourneyStatus.planned,
    this.focusTargetMinutes,
    this.milestones = const [],
    this.habitIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final String coverPath;
  final String startDate;
  final String targetDate;
  final JourneyStatus status;
  final int? focusTargetMinutes;
  final List<JourneyMilestone> milestones;
  final List<String> habitIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  double get progress {
    if (milestones.isEmpty) return status == JourneyStatus.completed ? 1 : 0;
    final done = milestones.where((item) => item.completed).length;
    return done / milestones.length;
  }

  Journey copyWith({
    String? title,
    String? description,
    String? icon,
    String? coverPath,
    String? startDate,
    String? targetDate,
    JourneyStatus? status,
    int? focusTargetMinutes,
    bool clearFocusTarget = false,
    List<JourneyMilestone>? milestones,
    List<String>? habitIds,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) =>
      Journey(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        icon: icon ?? this.icon,
        coverPath: coverPath ?? this.coverPath,
        startDate: startDate ?? this.startDate,
        targetDate: targetDate ?? this.targetDate,
        status: status ?? this.status,
        focusTargetMinutes:
            clearFocusTarget ? null : (focusTargetMinutes ?? this.focusTargetMinutes),
        milestones: milestones ?? this.milestones,
        habitIds: habitIds ?? this.habitIds,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        completedAt:
            clearCompletedAt ? null : (completedAt ?? this.completedAt),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'coverPath': coverPath,
        'startDate': startDate,
        'targetDate': targetDate,
        'status': status.index,
        'focusTargetMinutes': focusTargetMinutes,
        'milestones': milestones.map((item) => item.toMap()).toList(),
        'habitIds': habitIds,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (completedAt != null)
          'completedAt': completedAt!.toUtc().toIso8601String(),
      };

  factory Journey.fromMap(Map<String, dynamic> map) {
    final statusIndex = (map['status'] as num?)?.toInt() ?? 0;
    return Journey(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? ''}',
      description: '${map['description'] ?? ''}',
      icon: '${map['icon'] ?? 'route'}',
      coverPath: '${map['coverPath'] ?? ''}',
      startDate: _localDayKey('${map['startDate'] ?? ''}'),
      targetDate: _localDayKey('${map['targetDate'] ?? ''}'),
      status: JourneyStatus.values[
          statusIndex.clamp(0, JourneyStatus.values.length - 1)],
      focusTargetMinutes: (map['focusTargetMinutes'] as num?)?.toInt(),
      milestones: (map['milestones'] as List? ?? const [])
          .map((item) =>
              JourneyMilestone.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      habitIds: (map['habitIds'] as List? ?? const [])
          .map((value) => '$value')
          .toList(),
      createdAt: DateTime.tryParse('${map['createdAt'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse('${map['updatedAt'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      completedAt: DateTime.tryParse('${map['completedAt'] ?? ''}'),
    );
  }
}

String _localDayKey(String value) {
  if (value.length != 10) return value;
  final parts = value.split('-');
  if (parts.length != 3 || parts.first.length != 4) return value;
  return '${parts[2]}-${parts[1]}-${parts[0]}';
}
