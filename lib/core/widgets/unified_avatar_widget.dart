import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/widgets/active_avatar_ring.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';

/// Unified Avatar Widget for consistent appearance across all tabs
/// 
/// Displays the user's selected avatar in the top-right corner
/// with consistent sizing (56px), gradient ring, and status badge.
class UnifiedAvatarWidget extends ConsumerStatefulWidget {
  final double size;
  final bool showStatus;
  final String? statusText;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  
  const UnifiedAvatarWidget({
    super.key,
    this.size = 56,
    this.showStatus = true,
    this.statusText = 'Observing',
    this.onTap,
    this.margin,
  });
  
  @override
  ConsumerState<UnifiedAvatarWidget> createState() => _UnifiedAvatarWidgetState();
}

class _UnifiedAvatarWidgetState extends ConsumerState<UnifiedAvatarWidget> {
  String? _customAvatarUrl;
  String? _archetypeId;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadAvatarSettings();
  }
  
  Future<void> _loadAvatarSettings() async {
    try {
      final stateService = OnboardingStateService();
      await stateService.init();
      
      if (mounted) {
        setState(() {
          _customAvatarUrl = stateService.userAvatarUrl;
          _archetypeId = stateService.selectedArchetypeId?.toLowerCase() ?? 'sable';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading avatar settings: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
      );
    }
    
    // Get the correct avatar image based on archetype
    final avatarImage = _getAvatarImage();
    
    return Container(
      margin: widget.margin ?? const EdgeInsets.only(top: 8, right: 16),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with active ring
            ActiveAvatarRing(
              size: widget.size,
              borderWidth: 3,
              child: ClipOval(
                child: avatarImage,
              ),
            ),
            // Status badge
            if (widget.showStatus && widget.statusText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  widget.statusText!,
                  style: TextStyle(
                    color: AelianaColors.plasmaCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _getAvatarImage() {
    // Try custom avatar URL first (for Sable archetype with user-generated avatar)
    if (_customAvatarUrl != null && _archetypeId == 'sable') {
      return Image.network(
        _customAvatarUrl!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _getDefaultAvatar(),
      );
    }
    
    // Use archetype-specific avatar
    return _getDefaultAvatar();
  }
  
  Widget _getDefaultAvatar() {
    // Map archetype to asset path
    final assetPath = _getAvatarAssetPath(_archetypeId ?? 'sable');
    
    return Image.asset(
      assetPath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to colored circle with initial
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AelianaColors.hyperGold, AelianaColors.plasmaCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              (_archetypeId ?? 'S')[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: widget.size * 0.4,
              ),
            ),
          ),
        );
      },
    );
  }
  
  String _getAvatarAssetPath(String archetypeId) {
    switch (archetypeId.toLowerCase()) {
      case 'sable':
        return 'assets/avatars/sable_main.png';
      case 'kai':
        return 'assets/avatars/kai_main.png';
      case 'echo':
        return 'assets/avatars/echo_main.png';
      case 'marco':
        return 'assets/avatars/marco_main.png';
      case 'aeliana':
        return 'assets/avatars/aeliana_main.png';
      case 'imani':
        return 'assets/avatars/imani_main.png';
      case 'priya':
        return 'assets/avatars/priya_main.png';
      default:
        return 'assets/avatars/sable_main.png';
    }
  }
}
