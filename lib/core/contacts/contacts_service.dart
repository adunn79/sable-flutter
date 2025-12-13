import 'package:contacts_service/contacts_service.dart' as contacts_service;
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
        // Try requesting permission again
        final granted = await requestPermission();
        if (!granted) {
          debugPrint('❌ Permission denied after request');
          return null;
        }
      }
      
      // Get all contacts
      final contacts = await getAllContacts();
      if (contacts.isEmpty) {
        debugPrint('📱 No contacts found on device');
        return null;
      }
      
      // Return first contact with a phone number as a simple implementation
      // In production, you'd show a native picker UI
      for (final contact in contacts) {
        final phone = getPhoneNumber(contact);
        if (phone != null && phone.isNotEmpty) {
          debugPrint('📱 Picked contact: ${contact.displayName}');
          return {
            'name': contact.displayName ?? '',
            'phone': phone,
            'email': getEmail(contact) ?? '',
          };
        }
      }
      
      // If no contacts with phone, return first contact
      final first = contacts.first;
      return {
        'name': first.displayName ?? '',
        'phone': getPhoneNumber(first) ?? '',
        'email': getEmail(first) ?? '',
      };
    } catch (e) {
      debugPrint('❌ Failed to pick contact: $e');
      return null;
    }
  }
  
  /// Show a contact picker dialog with search
  /// Returns the picked contact's info as a map
  static Future<Map<String, String>?> showContactPicker(
    context, {
    String? initialQuery,
  }) async {
    try {
      if (!await hasPermission()) {
        final granted = await requestPermission();
        if (!granted) return null;
      }
      
      final contacts = await getAllContacts();
      if (contacts.isEmpty) return null;
      
      // Show picker dialog
      return await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _ContactPickerDialog(contacts: contacts),
      );
    } catch (e) {
      debugPrint('❌ Failed to show contact picker: $e');
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

/// Contact picker dialog with search functionality
class _ContactPickerDialog extends StatefulWidget {
  final List<Contact> contacts;
  
  const _ContactPickerDialog({required this.contacts});
  
  @override
  State<_ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<_ContactPickerDialog> {
  final _searchController = TextEditingController();
  List<Contact> _filteredContacts = [];
  
  @override
  void initState() {
    super.initState();
    _filteredContacts = widget.contacts;
  }
  
  void _filterContacts(String query) {
    if (query.isEmpty) {
      setState(() => _filteredContacts = widget.contacts);
      return;
    }
    
    final queryLower = query.toLowerCase();
    setState(() {
      _filteredContacts = widget.contacts.where((c) {
        final name = c.displayName?.toLowerCase() ?? '';
        return name.contains(queryLower);
      }).toList();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Text(
        'Select Contact',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                hintStyle: TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Contact list
            Expanded(
              child: ListView.builder(
                itemCount: _filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = _filteredContacts[index];
                  final phone = ContactsService.getPhoneNumber(contact);
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF00FFFF).withOpacity(0.2),
                      child: Text(
                        (contact.displayName?.isNotEmpty == true)
                            ? contact.displayName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Color(0xFF00FFFF)),
                      ),
                    ),
                    title: Text(
                      contact.displayName ?? 'Unknown',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: phone != null
                        ? Text(phone, style: TextStyle(color: Colors.white54))
                        : null,
                    onTap: () {
                      Navigator.of(context).pop({
                        'name': contact.displayName ?? '',
                        'phone': phone ?? '',
                        'email': ContactsService.getEmail(contact) ?? '',
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
