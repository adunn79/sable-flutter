import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

/// Gallery screen to view and manage all saved avatar images
class AvatarGalleryScreen extends StatefulWidget {
  const AvatarGalleryScreen({super.key});

  @override
  State<AvatarGalleryScreen> createState() => _AvatarGalleryScreenState();
}

class _AvatarGalleryScreenState extends State<AvatarGalleryScreen> {
  OnboardingStateService? _stateService;
  List<SavedAvatar> _avatars = [];
  String? _currentAvatarUrl;
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'aeliana', 'sable', 'kai', 'marco', 'echo'

  final List<Map<String, String>> _filters = [
    {'id': 'all', 'name': 'All'},
    {'id': 'aeliana', 'name': 'Aeliana'},
    {'id': 'sable', 'name': 'Sable'},
    {'id': 'kai', 'name': 'Kai'},
    {'id': 'marco', 'name': 'Marco'},
    {'id': 'echo', 'name': 'Echo'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAvatars();
  }

  Future<void> _loadAvatars() async {
    final service = await OnboardingStateService.create();
    if (mounted) {
      setState(() {
        _stateService = service;
        _avatars = service.structuredAvatarGallery;
        _currentAvatarUrl = service.avatarUrl;
        _isLoading = false;
      });
    }
  }

  List<SavedAvatar> get _filteredAvatars {
    if (_selectedFilter == 'all') return _avatars;
    return _avatars.where((a) => a.archetypeId == _selectedFilter).toList();
  }

  void _setAsActive(SavedAvatar avatar) async {
    await _stateService?.saveAvatarUrl(avatar.url);
    if (mounted) {
      setState(() => _currentAvatarUrl = avatar.url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Avatar updated!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<bool> _deleteAvatar(SavedAvatar avatar) async {
    if (avatar.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔒 This avatar is locked. Unlock it first to delete.'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return false;
    }
    
    final deleted = await _stateService?.removeFromAvatarGallery(avatar.url) ?? false;
    if (deleted && mounted) {
      setState(() => _avatars.removeWhere((a) => a.url == avatar.url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar removed from gallery'),
          backgroundColor: Colors.grey,
        ),
      );
    }
    return deleted;
  }

  void _toggleLock(SavedAvatar avatar) async {
    await _stateService?.setAvatarLocked(avatar.url, !avatar.isLocked);
    if (mounted) {
      setState(() {
        final index = _avatars.indexWhere((a) => a.url == avatar.url);
        if (index >= 0) {
          _avatars[index] = _avatars[index].copyWith(isLocked: !avatar.isLocked);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(avatar.isLocked ? '🔓 Avatar unlocked' : '🔒 Avatar locked'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showAvatarActions(SavedAvatar avatar) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AelianaColors.carbon,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Preview image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 150,
                child: avatar.url.startsWith('assets/')
                    ? Image.asset(avatar.url, fit: BoxFit.cover)
                    : Image.network(avatar.url, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            
            // Archetype badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AelianaColors.obsidian,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Made for ${_capitalizeFirst(avatar.archetypeId)}',
                style: GoogleFonts.inter(
                  color: AelianaColors.plasmaCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Action buttons
            _buildActionTile(
              icon: LucideIcons.check,
              label: 'Set as Active',
              color: AelianaColors.plasmaCyan,
              onTap: () {
                Navigator.pop(context);
                _setAsActive(avatar);
              },
            ),
            _buildActionTile(
              icon: avatar.isLocked ? LucideIcons.unlock : LucideIcons.lock,
              label: avatar.isLocked ? 'Unlock Avatar' : 'Lock Avatar',
              color: avatar.isLocked ? Colors.orange : AelianaColors.hyperGold,
              onTap: () {
                Navigator.pop(context);
                _toggleLock(avatar);
              },
            ),
            if (!avatar.isLocked)
              _buildActionTile(
                icon: LucideIcons.trash2,
                label: 'Delete',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _deleteAvatar(avatar);
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: GoogleFonts.inter(color: Colors.white)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Avatar Gallery',
          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.info, color: Colors.white54),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tap to manage • Swipe to delete • Lock to protect'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AelianaColors.plasmaCyan))
          : Column(
              children: [
                // Filter tabs
                _buildFilterTabs(),
                
                // Gallery content
                Expanded(
                  child: _filteredAvatars.isEmpty
                      ? _buildEmptyState()
                      : _buildGalleryGrid(),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter['id'];
          final count = filter['id'] == 'all' 
              ? _avatars.length 
              : _avatars.where((a) => a.archetypeId == filter['id']).length;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter['id']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AelianaColors.plasmaCyan : AelianaColors.carbon,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? AelianaColors.plasmaCyan : Colors.white12,
                ),
              ),
              child: Center(
                child: Text(
                  '${filter['name']} ($count)',
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.imageOff, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'all' 
                ? 'No avatars saved yet'
                : 'No avatars for ${_capitalizeFirst(_selectedFilter)}',
            style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Generated avatars will appear here',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_filteredAvatars.length} avatar${_filteredAvatars.length == 1 ? '' : 's'}',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: _filteredAvatars.length,
              itemBuilder: (context, index) => _buildAvatarCard(_filteredAvatars[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCard(SavedAvatar avatar) {
    final isActive = avatar.url == _currentAvatarUrl;
    
    return Dismissible(
      key: Key(avatar.url),
      direction: avatar.isLocked ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (_) async => await _deleteAvatar(avatar),
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => _showAvatarActions(avatar),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? AelianaColors.plasmaCyan : Colors.white12,
              width: isActive ? 3 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: avatar.url.startsWith('assets/')
                    ? Image.asset(avatar.url, fit: BoxFit.cover)
                    : Image.network(
                        avatar.url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          color: AelianaColors.carbon,
                          child: const Center(
                            child: Icon(LucideIcons.imageOff, color: Colors.white24),
                          ),
                        ),
                      ),
              ),
              
              // Lock icon
              if (avatar.isLocked)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.lock, color: Colors.orange, size: 16),
                  ),
                ),
              
              // Active badge
              if (isActive)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AelianaColors.plasmaCyan,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              
              // Archetype indicator at bottom
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _capitalizeFirst(avatar.archetypeId),
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
