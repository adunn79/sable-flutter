import 'package:hive/hive.dart';

part 'chat_message.g.dart';

/// Chat message model for Hive storage
/// Stores conversation history with 500+ message capacity
@HiveType(typeId: 10)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String message;

  @HiveField(2)
  final bool isUser;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String? emotionalContext; // Optional: detected emotion

  ChatMessage({
    required this.id,
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.emotionalContext,
  });

  factory ChatMessage.create({
    required String message,
    required bool isUser,
    String? emotionalContext,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      isUser: isUser,
      timestamp: DateTime.now(),
      emotionalContext: emotionalContext,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'message': message,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'emotionalContext': emotionalContext,
  };
}
