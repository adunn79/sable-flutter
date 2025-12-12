import 'package:flutter/foundation.dart';

/// Result of a tool execution
class ToolResult {
  final bool success;
  final dynamic data;
  final String? error;
  final String? userMessage;  // User-friendly message
  final String? missingField; // Field needed to continue
  final bool needsInput;  // True if we need user input before executing

  ToolResult.success(this.data, {this.userMessage})
      : success = true,
        error = null,
        missingField = null,
        needsInput = false;

  ToolResult.error(this.error, {this.userMessage})
      : success = false,
        data = null,
        missingField = null,
        needsInput = false;

  ToolResult.needsMoreInfo(this.missingField, {this.userMessage})
      : success = false,
        data = null,
        error = null,
        needsInput = true;

  @override
  String toString() => success 
    ? 'ToolResult.success: $data' 
    : needsInput 
      ? 'ToolResult.needsMoreInfo: $missingField'
      : 'ToolResult.error: $error';
}

/// A tool function signature
typedef ToolFunction = Future<ToolResult> Function(Map<String, dynamic> params);

/// Metadata about a tool
class ToolMetadata {
  final String name;
  final String description;
  final Map<String, dynamic> schema;  // JSON Schema
  final List<String> allowedBrains;  // Which room brains can use this tool
  final ToolFunction execute;

  ToolMetadata({
    required this.name,
    required this.description,
    required this.schema,
    required this.allowedBrains,
    required this.execute,
  });
}

/// Registry for all available tools
class ToolRegistry {
  final Map<String, ToolMetadata> _tools = {};

  /// Register a new tool
  void register(ToolMetadata tool) {
    if (_tools.containsKey(tool.name)) {
      debugPrint('⚠️ Tool ${tool.name} already registered, overwriting');
    }
    _tools[tool.name] = tool;
    debugPrint('✅ Tool registered: ${tool.name}');
  }

  /// Check if a tool exists
  bool has(String toolName) => _tools.containsKey(toolName);

  /// Get tool metadata
  ToolMetadata? getMetadata(String toolName) => _tools[toolName];

  /// Execute a tool
  Future<ToolResult> execute(
    String toolName,
    Map<String, dynamic> params, {
    required String callingBrain,  // Which brain is calling this
  }) async {
    final tool = _tools[toolName];
    
    if (tool == null) {
      return ToolResult.error(
        'Tool not found: $toolName',
        userMessage: 'I don\'t have that capability yet.',
      );
    }

    // Check permissions
    if (!tool.allowedBrains.contains(callingBrain) && 
        !tool.allowedBrains.contains('*')) {
      return ToolResult.error(
        'Brain $callingBrain not allowed to use tool $toolName',
        userMessage: 'I can\'t do that from this context.',
      );
    }

    // Validate parameters against schema (basic validation)
    final validation = _validateParams(params, tool.schema);
    if (!validation.isValid) {
      return ToolResult.error(
        'Invalid parameters: ${validation.error}',
        userMessage: 'Something went wrong with that request.',
      );
    }

    try {
      debugPrint('🔧 Executing tool: $toolName with params: $params');
      final result = await tool.execute(params);
      debugPrint('✅ Tool result: $result');
      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ Tool execution error: $e\n$stackTrace');
      return ToolResult.error(
        'Tool execution failed: $e',
        userMessage: 'I encountered an error. Please try again.',
      );
    }
  }

  /// Get all available tools for a specific brain
  List<ToolMetadata> getToolsForBrain(String brainName) {
    return _tools.values
        .where((tool) => 
          tool.allowedBrains.contains(brainName) || 
          tool.allowedBrains.contains('*'))
        .toList();
  }

  /// Get list of all tool names
  List<String> getAllToolNames() => _tools.keys.toList();

  // Basic parameter validation
  _ValidationResult _validateParams(
    Map<String, dynamic> params,
    Map<String, dynamic> schema,
  ) {
    // Check required fields
    final required = schema['required'] as List<dynamic>? ?? [];
    for (final field in required) {
      if (!params.containsKey(field)) {
        return _ValidationResult(
          false,
          'Missing required field: $field',
        );
      }
    }

    // TODO: Add type validation, format validation, etc.
    return _ValidationResult(true, null);
  }
}

class _ValidationResult {
  final bool isValid;
  final String? error;

  _ValidationResult(this.isValid, this.error);
}

/// Helper to create tool metadata
ToolMetadata createTool({
  required String name,
  required String description,
  required Map<String, dynamic> schema,
  required List<String> allowedBrains,
  required ToolFunction function,
}) {
  return ToolMetadata(
    name: name,
    description: description,
    schema: schema,
    allowedBrains: allowedBrains,
    execute: function,
  );
}
