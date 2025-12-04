import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AppleIntelligenceService {
  static const MethodChannel _channel = MethodChannel('com.aureal.sable/apple_intelligence');

  /// Check if Apple Intelligence is available on this device
  /// Requires iOS 18+ / macOS 15+ and compatible hardware
  static Future<bool> isAvailable() async {
    try {
      final bool result = await _channel.invokeMethod('isAvailable');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error checking Apple Intelligence availability: ${e.message}');
      return false;
    }
  }

  /// Request text rewrite (proofread/friendly/professional)
  /// Note: This invokes native Writing Tools if available
  static Future<String?> rewrite(String text, {String style = 'standard'}) async {
    try {
      final String? result = await _channel.invokeMethod('rewrite', {
        'text': text,
        'style': style,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error rewriting text: ${e.message}');
      return null;
    }
  }

  /// Request text summarization
  static Future<String?> summarize(String text) async {
    try {
      final String? result = await _channel.invokeMethod('summarize', {
        'text': text,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error summarizing text: ${e.message}');
      return null;
    }
  }

  /// Launch Siri / Shortcuts
  static Future<bool> launchSiri() async {
    try {
      final bool result = await _channel.invokeMethod('launchSiri');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error launching Siri: ${e.message}');
      return false;
    }
  }
}
