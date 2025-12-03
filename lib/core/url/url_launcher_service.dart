import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper service for launching URLs and Safari
/// Provides methods to open web links, maps, phone calls, etc.
class UrlLauncherService {
  /// Open a URL in Safari or default browser
  static Future<bool> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        debugPrint('🌐 Opening URL: $url');
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Opens in Safari
        );
      } else {
        debugPrint('⚠️ Cannot launch URL: $url');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to open URL: $e');
      return false;
    }
  }
  
  /// Open a phone number in the Phone app
  static Future<bool> makePhoneCall(String phoneNumber) async {
    try {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri.parse('tel:$cleanNumber');
      
      if (await canLaunchUrl(uri)) {
        debugPrint('📞 Opening phone call: $phoneNumber');
        return await launchUrl(uri);
      } else {
        debugPrint('⚠️ Cannot make phone call');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to make phone call: $e');
      return false;
    }
  }
  
  /// Open an email client with pre-filled fields
  static Future<bool> sendEmail({
    required String to,
    String? subject,
    String? body,
  }) async {
    try {
      String emailUrl = 'mailto:$to';
      
      final params = <String>[];
      if (subject != null) {
        params.add('subject=${Uri.encodeComponent(subject)}');
      }
      if (body != null) {
        params.add('body=${Uri.encodeComponent(body)}');
      }
      
      if (params.isNotEmpty) {
        emailUrl += '?${params.join('&')}';
      }
      
      final uri = Uri.parse(emailUrl);
      
      if (await canLaunchUrl(uri)) {
        debugPrint('📧 Opening email client');
        return await launchUrl(uri);
      } else {
        debugPrint('⚠️ Cannot open email client');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to open email client: $e');
      return false;
    }
  }
  
  /// Open SMS app with pre-filled message
  static Future<bool> sendSMS({
    required String phoneNumber,
    String? message,
  }) async {
    try {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      String smsUrl = 'sms:$cleanNumber';
      
      if (message != null) {
        smsUrl += '?body=${Uri.encodeComponent(message)}';
      }
      
      final uri = Uri.parse(smsUrl);
      
      if (await canLaunchUrl(uri)) {
        debugPrint('💬 Opening SMS app');
        return await launchUrl(uri);
      } else {
        debugPrint('⚠️ Cannot open SMS app');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to open SMS app: $e');
      return false;
    }
  }
  
  /// Open Maps app with a location or search query
  static Future<bool> openMaps({
    String? query,
    double? latitude,
    double? longitude,
  }) async {
    try {
      String mapsUrl;
      
      if (latitude != null && longitude != null) {
        // Open with coordinates
        mapsUrl = 'https://maps.apple.com/?ll=$latitude,$longitude';
      } else if (query != null) {
        // Search for location
        mapsUrl = 'https://maps.apple.com/?q=${Uri.encodeComponent(query)}';
      } else {
        debugPrint('⚠️ No location or query provided for maps');
        return false;
      }
      
      final uri = Uri.parse(mapsUrl);
      
      if (await canLaunchUrl(uri)) {
        debugPrint('🗺️ Opening Maps');
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint('⚠️ Cannot open Maps');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to open Maps: $e');
      return false;
    }
  }
  
  /// Open Settings app (iOS)
  static Future<bool> openSettings() async {
    try {
      final uri = Uri.parse('app-settings:');
      
      if (await canLaunchUrl(uri)) {
        debugPrint('⚙️ Opening Settings');
        return await launchUrl(uri);
      } else {
        debugPrint('⚠️ Cannot open Settings');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to open Settings: $e');
      return false;
    }
  }
}
