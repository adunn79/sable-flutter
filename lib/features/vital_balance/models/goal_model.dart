import 'package:hive/hive.dart';

part 'goal_model.g.dart';

/// Status of a goal
@HiveType(typeId: 20)
enum GoalStatus {
  @HiveField(0)
  active,
  @HiveField(1)
  completed,
  @HiveField(2)
  abandoned,
}

/// A check-in entry for tracking goal progress
@HiveType(typeId: 21)
class GoalCheckIn extends HiveObject {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  String note;

  @HiveField(2)
  int progressUpdate; // 0-100

  GoalCheckIn({
    required this.date,
    required this.note,
    required this.progressUpdate,
  });
}

/// A user goal with timeframe and progress tracking
@HiveType(typeId: 22)
class Goal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime targetDate;

  @HiveField(5)
  GoalStatus status;

  @HiveField(6)
  int progressPercent; // 0-100

  @HiveField(7)
  List<GoalCheckIn> checkIns;

  @HiveField(8)
  String? aiTip; // AI-generated tip for this goal

  @HiveField(9)
  DateTime? lastCheckInReminder; // When AI last reminded about this goal

  @HiveField(10)
  int checkInFrequencyDays; // How often (in days) to remind about this goal

  Goal({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.targetDate,
    this.status = GoalStatus.active,
    this.progressPercent = 0,
    List<GoalCheckIn>? checkIns,
    this.aiTip,
    this.lastCheckInReminder,
    this.checkInFrequencyDays = 3, // Default: remind every 3 days
  }) : checkIns = checkIns ?? [];

  /// Days remaining until target date
  int get daysRemaining {
    final diff = targetDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Whether the target date has passed
  bool get isOverdue => DateTime.now().isAfter(targetDate) && status == GoalStatus.active;

  /// Days since last check-in
  int get daysSinceLastCheckIn {
    if (checkIns.isEmpty) {
      return DateTime.now().difference(createdAt).inDays;
    }
    final lastCheckIn = checkIns.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    return DateTime.now().difference(lastCheckIn.date).inDays;
  }

  /// Whether it's time for a check-in reminder (based on user-set frequency)
  bool get needsCheckInReminder => daysSinceLastCheckIn >= checkInFrequencyDays && status == GoalStatus.active;

  /// Copy with updated fields
  Goal copyWith({
    String? title,
    String? description,
    DateTime? targetDate,
    GoalStatus? status,
    int? progressPercent,
    List<GoalCheckIn>? checkIns,
    String? aiTip,
    DateTime? lastCheckInReminder,
    int? checkInFrequencyDays,
  }) {
    return Goal(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      checkIns: checkIns ?? this.checkIns,
      aiTip: aiTip ?? this.aiTip,
      lastCheckInReminder: lastCheckInReminder ?? this.lastCheckInReminder,
      checkInFrequencyDays: checkInFrequencyDays ?? this.checkInFrequencyDays,
    );
  }
}
