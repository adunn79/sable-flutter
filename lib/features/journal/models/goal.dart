import 'package:hive/hive.dart';

part 'goal.g.dart';

/// Goal model for tracking personal goals in journal
@HiveType(typeId: 10)
class Goal extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  GoalCategory category;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime? targetDate;

  @HiveField(6)
  bool isCompleted;

  @HiveField(7)
  DateTime? completedAt;

  @HiveField(8)
  List<Milestone> milestones;

  @HiveField(9)
  List<String> linkedEntryIds; // Journal entries tagged to this goal

  @HiveField(10)
  int progressPercent; // 0-100

  @HiveField(11)
  String? whyItMatters; // Motivation

  Goal({
    required this.id,
    required this.title,
    this.description,
    this.category = GoalCategory.personal,
    required this.createdAt,
    this.targetDate,
    this.isCompleted = false,
    this.completedAt,
    this.milestones = const [],
    this.linkedEntryIds = const [],
    this.progressPercent = 0,
    this.whyItMatters,
  });

  Goal copyWith({
    String? title,
    String? description,
    GoalCategory? category,
    DateTime? targetDate,
    bool? isCompleted,
    DateTime? completedAt,
    List<Milestone>? milestones,
    List<String>? linkedEntryIds,
    int? progressPercent,
    String? whyItMatters,
  }) {
    return Goal(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      createdAt: createdAt,
      targetDate: targetDate ?? this.targetDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      milestones: milestones ?? this.milestones,
      linkedEntryIds: linkedEntryIds ?? this.linkedEntryIds,
      progressPercent: progressPercent ?? this.progressPercent,
      whyItMatters: whyItMatters ?? this.whyItMatters,
    );
  }
}

@HiveType(typeId: 11)
enum GoalCategory {
  @HiveField(0)
  health,
  @HiveField(1)
  career,
  @HiveField(2)
  relationships,
  @HiveField(3)
  personal,
  @HiveField(4)
  hobbies,
  @HiveField(5)
  financial,
}

@HiveType(typeId: 12)
class Milestone {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isCompleted;

  @HiveField(3)
  DateTime? completedAt;

  Milestone({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.completedAt,
  });
}
