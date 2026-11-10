enum GoalState { active, completed, archived }

enum GoalSourceType { habit, todo, journey }

class GoalSourceLink {
  const GoalSourceLink({
    required this.type,
    required this.sourceId,
    required this.linkedAt,
    this.sourceTitle = '',
    this.available = true,
  });

  final GoalSourceType type;
  final String sourceId;
  final DateTime linkedAt;
  final String sourceTitle;
  final bool available;

  Map<String, dynamic> toMap() => {
        'sourceType': type.index,
        'sourceId': sourceId,
        'linkedAt': linkedAt.toUtc().toIso8601String(),
        if (sourceTitle.isNotEmpty) 'sourceTitle': sourceTitle,
        'available': available,
      };

  factory GoalSourceLink.fromMap(Map<String, dynamic> map) {
    final rawType = map['sourceType'] ?? map['type'] ?? 0;
    final typeIndex = rawType is num
        ? rawType.toInt()
        : switch (rawType.toString().toLowerCase()) {
            'habit' => GoalSourceType.habit.index,
            'todo' => GoalSourceType.todo.index,
            'journey' => GoalSourceType.journey.index,
            _ => -1,
          };
    if (typeIndex < 0 || typeIndex >= GoalSourceType.values.length) {
      throw FormatException('Unknown Goal source type: $rawType');
    }
    return GoalSourceLink(
      type: GoalSourceType.values[typeIndex],
      sourceId: map['sourceId']?.toString() ?? '',
      linkedAt: DateTime.tryParse(map['linkedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sourceTitle: map['sourceTitle']?.toString() ?? '',
      available: map['available'] != false,
    );
  }
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.targetDate = '',
    this.state = GoalState.active,
    this.parentGoalId,
    this.sources = const [],
    this.version = 0,
  });

  final String id;
  final String title;
  final String description;
  final String targetDate;
  final GoalState state;
  final String? parentGoalId;
  final List<GoalSourceLink> sources;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  bool get isArchived => state == GoalState.archived;

  Goal copyWith({
    String? title,
    String? description,
    String? targetDate,
    bool clearTargetDate = false,
    GoalState? state,
    String? parentGoalId,
    bool clearParentGoal = false,
    List<GoalSourceLink>? sources,
    DateTime? updatedAt,
    int? version,
  }) =>
      Goal(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        targetDate:
            clearTargetDate ? '' : (targetDate ?? this.targetDate),
        state: state ?? this.state,
        parentGoalId:
            clearParentGoal ? null : (parentGoalId ?? this.parentGoalId),
        sources: sources ?? this.sources,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version ?? this.version,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'targetDate': targetDate,
        'status': state.index,
        'parentGoalId': parentGoalId,
        'sources': sources.map((source) => source.toMap()).toList(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'version': version,
      };

  factory Goal.fromMap(Map<String, dynamic> map) {
    final rawState = map['status'] ?? map['state'] ?? 0;
    final stateIndex = rawState is num
        ? rawState.toInt()
        : switch (rawState.toString().toLowerCase()) {
            'active' => GoalState.active.index,
            'completed' => GoalState.completed.index,
            'archived' => GoalState.archived.index,
            _ => 0,
          };
    final safeStateIndex =
        stateIndex.clamp(0, GoalState.values.length - 1);
    final createdAt = DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return Goal(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      targetDate: map['targetDate']?.toString() ?? '',
      state: GoalState.values[safeStateIndex],
      parentGoalId: map['parentGoalId']?.toString(),
      sources: (map['sources'] as List? ?? map['links'] as List? ?? const [])
          .map(
            (item) => GoalSourceLink.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      createdAt: createdAt,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          createdAt,
      version: (map['version'] as num?)?.toInt() ?? 0,
    );
  }
}
