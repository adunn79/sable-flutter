import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/aureal_theme.dart';
import '../photo_service.dart';
import '../models/photo_entry.dart';

/// Bottom sheet for picking/taking photos
/// Options: Camera, Gallery, Recent photos
class PhotoPickerSheet extends StatefulWidget {
  final String? linkedJournalId;
  final Function(PhotoEntry photo)? onPhotoSelected;
  final bool showPrivateOption;

  const PhotoPickerSheet({
    super.key,
    this.linkedJournalId,
    this.onPhotoSelected,
    this.showPrivateOption = true,
  });

  /// Show as bottom sheet
  static Future<PhotoEntry?> show(BuildContext context, {
    String? linkedJournalId,
    bool showPrivateOption = true,
  }) async {
    return showModalBottomSheet<PhotoEntry>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PhotoPickerSheet(
        linkedJournalId: linkedJournalId,
        showPrivateOption: showPrivateOption,
        onPhotoSelected: (photo) => Navigator.pop(context, photo),
      ),
    );
  }

  @override
  State<PhotoPickerSheet> createState() => _PhotoPickerSheetState();
}

class _PhotoPickerSheetState extends State<PhotoPickerSheet> {
  final _picker = ImagePicker();
  bool _isPrivate = false;
  List<PhotoEntry> _recentPhotos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentPhotos();
  }

  Future<void> _loadRecentPhotos() async {
    final service = await PhotoService.getInstance();
    setState(() {
      _recentPhotos = service.getRecentPhotos(limit: 10);
    });
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image != null) {
        await _addPhoto(image.path);
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        await _addPhoto(image.path);
      }
    } catch (e) {
      debugPrint('Gallery error: $e');
    }
  }

  Future<void> _addPhoto(String path) async {
    setState(() => _isLoading = true);
    
    try {
      final service = await PhotoService.getInstance();
      final entry = await service.addPhoto(
        path,
        isPrivate: _isPrivate,
        linkedJournalId: widget.linkedJournalId,
      );
      
      if (entry != null) {
        widget.onPhotoSelected?.call(entry);
      }
    } catch (e) {
      debugPrint('Error adding photo: $e');
    }
    
    setState(() => _isLoading = false);
  }

  void _selectExisting(PhotoEntry photo) {
    if (widget.linkedJournalId != null && photo.linkedJournalId != widget.linkedJournalId) {
      // Link to journal
      PhotoService.getInstance().then((s) => s.linkToJournal(photo.id, widget.linkedJournalId!));
    }
    widget.onPhotoSelected?.call(photo);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AurealColors.carbon,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            'Add Photo',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              _buildActionButton(
                icon: LucideIcons.camera,
                label: 'Camera',
                onTap: _isLoading ? null : _takePhoto,
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: LucideIcons.image,
                label: 'Gallery',
                onTap: _isLoading ? null : _pickFromGallery,
              ),
            ],
          ),
          
          // Privacy toggle
          if (widget.showPrivateOption) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isPrivate ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPrivate ? Colors.red.withOpacity(0.3) : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPrivate ? LucideIcons.lock : LucideIcons.unlock,
                    color: _isPrivate ? Colors.red : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Private Photo',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _isPrivate 
                              ? 'Encrypted storage, hidden from AI'
                              : 'Visible to AI for context',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPrivate,
                    onChanged: (v) => setState(() => _isPrivate = v),
                    activeColor: Colors.red,
                  ),
                ],
              ),
            ),
          ],
          
          // Recent photos
          if (_recentPhotos.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Recent',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recentPhotos.length,
                itemBuilder: (context, index) {
                  final photo = _recentPhotos[index];
                  return GestureDetector(
                    onTap: () => _selectExisting(photo),
                    child: Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/images/placeholder.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AurealColors.obsidian,
                                child: const Icon(LucideIcons.image, color: Colors.white24),
                              ),
                            ),
                            if (photo.isPrivate)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.lock, size: 10, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          
          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AurealColors.plasmaCyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AurealColors.plasmaCyan, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: AurealColors.plasmaCyan,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
