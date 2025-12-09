import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/contacts/contacts_service.dart' as app_contacts;

class ContactPickerSheet extends StatefulWidget {
  const ContactPickerSheet({super.key});

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await app_contacts.ContactsService.getAllContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredContacts = _contacts);
    } else {
      setState(() {
        _filteredContacts = _contacts.where((c) {
          final name = (c.displayName ?? '').toLowerCase();
          return name.contains(query);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AelianaColors.plasmaCyan.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(LucideIcons.users, color: AelianaColors.plasmaCyan),
                const SizedBox(width: 12),
                Text(
                  'SELECT CONTACT',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(LucideIcons.search, color: Colors.white54),
                hintText: 'Search contacts...',
                hintStyle: GoogleFonts.inter(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AelianaColors.plasmaCyan))
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Text(
                          _contacts.isEmpty ? 'No contacts found' : 'No matches',
                          style: GoogleFonts.inter(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final hasPhone = contact.phones != null && contact.phones!.isNotEmpty;
                          final phone = hasPhone ? contact.phones!.first.value : null;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AelianaColors.plasmaCyan.withOpacity(0.2),
                              child: Text(
                                (contact.initials() ?? '?').toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: AelianaColors.plasmaCyan,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              contact.displayName ?? 'Unknown',
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                            subtitle: phone != null
                                ? Text(
                                    phone,
                                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(context, contact);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
