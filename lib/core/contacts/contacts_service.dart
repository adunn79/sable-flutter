import 'package:contacts_service/contacts_service.dart' as contacts_service;
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling device contacts integration
/// Provides permission management, contact search, and AI context formatting
class ContactsService {
  /// Request contacts permission from the user
  static Future<bool> requestPermission() async {
    try {
      final status = await Permission.contacts.request();
      debugPrint('👥 Contacts permission granted: ${status.isGranted}');
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Contacts permission request failed: $e');
      return false;
    }
  }
  
  /// Check if contacts permission has been granted
  static Future<bool> hasPermission() async {
    try {
      final status = await Permission.contacts.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Contacts permission check failed: $e');
      return false;
    }
  }
  
  /// Get all contacts from device
  static Future<List<Contact>> getAllContacts() async {
    try {
      if (!await hasPermission()) {
        debugPrint('⚠️ No contacts permission');
        return [];
      }
      
      // Use package's static method directly
      final Iterable<Contact> contacts = await contacts_service.ContactsService.getContacts();
      debugPrint('📇 Retrieved ${contacts.length} contacts');
      return contacts.toList();
    } catch (e) {
      debugPrint('❌ Failed to get contacts: $e');
      return [];
    }
  }
  
  /// Search contacts by name or phone
  static Future<List<Contact>> searchContacts(String query) async {
    try {
      if (!await hasPermission()) return [];
      
      final allContacts = await getAllContacts();
      final queryLower = query.toLowerCase();
      
      return allContacts.where((contact) {
        // Search in display name
        final displayName = contact.displayName?.toLowerCase() ?? '';
        if (displayName.contains(queryLower)) return true;
        
        // Search in given name
        final givenName = contact.givenName?.toLowerCase() ?? '';
        if (givenName.contains(queryLower)) return true;
        
        // Search in family name
        final familyName = contact.familyName?.toLowerCase() ?? '';
        if (familyName.contains(queryLower)) return true;
        
        // Search in phone numbers
        if (contact.phones != null) {
          for (final phone in contact.phones!) {
            if (phone.value != null && phone.value!.contains(query)) {
              return true;
            }
          }
        }
        
        return false;
      }).toList();
    } catch (e) {
      debugPrint('❌ Failed to search contacts: $e');
      return [];
    }
  }
  
  /// Get contact by exact name match
  static Future<Contact?> getContactByName(String name) async {
    try {
      final results = await searchContacts(name);
      if (results.isEmpty) return null;
      
      // Try exact match first
      final nameLower = name.toLowerCase();
      for (final contact in results) {
        if (contact.displayName?.toLowerCase() == nameLower) {
          return contact;
        }
      }
      
      // Return first result if no exact match
      return results.first;
    } catch (e) {
      debugPrint('❌ Failed to get contact by name: $e');
      return null;
    }
  }
  
  /// Pick a contact from the device contact list
  /// Returns a map with name, phone, and email if available
  static Future<Map<String, String>?> pickContact() async {
    try {
      if (!await hasPermission()) {
        debugPrint('⚠️ No contacts permission for picking');
        return null;
      }
      
      // Get all contacts and let the UI handle selection
      // In a real implementation, you'd use a contact picker plugin
      // For now, we'll return null to indicate feature not fully implemented
      debugPrint('📱 Contact picker not fully implemented - requires native picker plugin');
      return null;
    } catch (e) {
      debugPrint('❌ Failed to pick contact: $e');
      return null;
    }
  }
  
  /// Get primary phone number for a contact
  static String? getPhoneNumber(Contact contact) {
    if (contact.phones == null || contact.phones!.isEmpty) {
      return null;
    }
    return contact.phones!.first.value;
  }
  
  /// Get primary email for a contact
  static String? getEmail(Contact contact) {
    if (contact.emails == null || contact.emails!.isEmpty) {
      return null;
    }
    return contact.emails!.first.value;
  }
  
  /// Get formatted contacts summary for AI context
  static Future<String> getRecentContactsSummary() async {
    try {
      if (!await hasPermission()) {
        return '[CONTACTS]\nNo contacts access granted.\n[END CONTACTS]';
      }
      
      final contacts = await getAllContacts();
      
      final buffer = StringBuffer();
      buffer.writeln('[CONTACTS]');
      buffer.writeln('Total: ${contacts.length} contacts');
      
      if (contacts.isNotEmpty) {
        // Show a sample of contacts (first 10)
        buffer.writeln('\nSample contacts:');
        for (final contact in contacts.take(10)) {
          final name = contact.displayName ?? 'Unknown';
          final phone = getPhoneNumber(contact);
          
          if (phone != null) {
            buffer.writeln('- $name ($phone)');
          } else {
            buffer.writeln('- $name');
          }
        }
      }
      
      buffer.writeln('[END CONTACTS]');
      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Failed to generate contacts summary: $e');
      return '[CONTACTS]\nError loading contacts data.\n[END CONTACTS]';
    }
  }
  
  /// Format contact information for AI
  static String formatContactInfo(Contact contact) {
    final buffer = StringBuffer();
    
    buffer.writeln('Name: ${contact.displayName ?? 'Unknown'}');
    
    final phone = getPhoneNumber(contact);
    if (phone != null) {
      buffer.writeln('Phone: $phone');
    }
    
    final email = getEmail(contact);
    if (email != null) {
      buffer.writeln('Email: $email');
    }
    
    return buffer.toString();
  }
}
