import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/core/theme/aureal_theme.dart';

/// Gallery screen to view and manage all saved avatar images
class AvatarGalleryScreen extends StatefulWidget {
  const AvatarGalleryScreen({super.key});

  @override
  State<AvatarGalleryScreen> createState() => _AvatarGalleryScreenState();
}

class _AvatarGalleryScreenState extends State<AvatarGalleryScreen> {
  OnboardingStateService? _stateService;
  List<String> _avatars = [];
  String? _currentAvatarUrl;
  bool _isLoading = true;

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
        _avatars = service.avatarGallery;
        _currentAvatarUrl = service.avatarUrl;
        _isLoading = false;
      });
    }
  }

  void _setAsActive(String url) async {
    await _stateService?.saveAvatarUrl(url);
    if (mounted) {
      setState(() => _currentAvatarUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Avatar updated!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _deleteAvatar(String url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AurealColors.carbon,
        title: Text('Delete Avatar?', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        content: Text('This avatar will be removed from your gallery.', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _stateService?.removeFromAvatarGallery(url);
      if (mounted) {
        setState(() => _avatars.remove(url));
      }
    }
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: url.startsWith('assets/')
                  ? Image.asset(url, fit: BoxFit.cover)
                  : Image.network(url, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _setAsActive(url);
                  },
                  icon: const Icon(LucideIcons.check),
                  label: const Text('Set Active'),
                  style: ElevatedButton.styleFrom(backgroundColor: AurealColors.plasmaCyan),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, color: Colors.white),
                  label: Text('Close', style: GoogleFonts.inter(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
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
                  content: Text('Tap to view, long-press to delete'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AurealColors.plasmaCyan))
          : _avatars.isEmpty
              ? _buildEmptyState()
              : _buildGalleryGrid(),
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
            'No avatars saved yet',
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
            '${_avatars.length} avatar${_avatars.length == 1 ? '' : 's'} saved',
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
              itemCount: _avatars.length,
              itemBuilder: (context, index) => _buildAvatarCard(_avatars[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCard(String url) {
    final isActive = url == _currentAvatarUrl;
    
    return GestureDetector(
      onTap: () => _showFullImage(url),
      onLongPress: () => _deleteAvatar(url),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AurealColors.plasmaCyan : Colors.white12,
            width: isActive ? 3 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: url.startsWith('assets/')
                  ? Image.asset(url, fit: BoxFit.cover)
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: AurealColors.carbon,
                        child: const Center(
                          child: Icon(LucideIcons.imageOff, color: Colors.white24),
                        ),
                      ),
                    ),
            ),
            if (isActive)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AurealColors.plasmaCyan,
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
          ],
        ),
      ),
    );
  }
}
