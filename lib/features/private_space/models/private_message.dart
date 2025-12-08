import 'package:hive/hive.dart';

part 'private_message.g.dart';

/// Isolated message model for Private Space
/// NEVER indexed by UnifiedMemoryService or visible outside Private Space
@HiveType(typeId: 50) // Use high typeId to avoid conflicts
class PrivateMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final bool isUser;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String? avatarId; // 'luna', 'dante', 'storm'

  @HiveField(5)
  final List<String>? attachmentPaths; // Private photo paths

  @HiveField(6)
  final bool isBlocked; // If content was filtered

  PrivateMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.avatarId,
    this.attachmentPaths,
    this.isBlocked = false,
  });

  factory PrivateMessage.user(String content) {
    return PrivateMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory PrivateMessage.ai(String content, String avatarId) {
    return PrivateMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      avatarId: avatarId,
    );
  }

  factory PrivateMessage.blocked(String originalContent) {
    return PrivateMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: "I'm not comfortable exploring that direction. Let's try something else? 💜",
      isUser: false,
      timestamp: DateTime.now(),
      isBlocked: true,
    );
  }
}
