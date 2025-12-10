/// Context passed to Room Brain when processing a query
class AgentContext {
  final String userId;
  final DateTime timestamp;
  final String? currentLocation;
  final Map<String, dynamic> metadata;

  AgentContext({
    required this.userId,
    DateTime? timestamp,
    this.currentLocation,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'timestamp': timestamp.toIso8601String(),
    'location': currentLocation,
    'metadata': metadata,
  };
}

/// Response from a Room Brain
class BrainResponse {
  final String content;
  final bool requiresToolExecution;
  final Map<String, dynamic>? toolCall;
  final Map<String, dynamic> metadata;

  BrainResponse({
    required this.content,
    this.requiresToolExecution = false,
    this.toolCall,
    this.metadata = const {},
  });

  factory BrainResponse.simple(String content) => BrainResponse(
    content: content,
  );

  factory BrainResponse.withToolCall({
    required String toolName,
    required Map<String, dynamic> params,
  }) => BrainResponse(
    content: '',  // Will be filled after tool execution
    requiresToolExecution: true,
    toolCall: {'name': toolName, 'params': params},
  );
}
