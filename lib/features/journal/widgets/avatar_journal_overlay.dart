import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';

class AvatarJournalOverlay extends StatefulWidget {
  final bool isPrivate;
  final String archetype;
  final VoidCallback? onSparkTap;
  final VoidCallback? onAvatarTap;

  const AvatarJournalOverlay({
    super.key,
    required this.isPrivate,
    required this.archetype,
    this.onSparkTap,
    this.onAvatarTap,
  });

  @override
  State<AvatarJournalOverlay> createState() => _AvatarJournalOverlayState();
}

class _AvatarJournalOverlayState extends State<AvatarJournalOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String? _customAvatarUrl;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _loadCustomAvatar();
  }
  
  Future<void> _loadCustomAvatar() async {
    final service = await OnboardingStateService.create();
    if (mounted) {
      setState(() {
        _customAvatarUrl = service.avatarUrl;
      });
    }
  }

  Color get _avatarColor {
    switch (widget.archetype.toLowerCase()) {
      case 'kai': return Colors.blueAccent; 
      case 'echo': return AurealColors.plasmaCyan;
      case 'sable': default: return AurealColors.hyperGold;
    }
  }

  String get _avatarImagePath {
    final arch = widget.archetype.toLowerCase();
    final safeArch = (arch.isEmpty) ? 'sable' : arch;
    return 'assets/images/archetypes/$safeArch.png';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stack with avatar + pulse + privacy eye
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                   // Pulse animation
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isPrivate 
                            ? Colors.grey.withOpacity(0.1)
                            : _avatarColor.withOpacity(0.2),
                      ),
                    ),
                  ),

                  // Main avatar circle with actual image
                  GestureDetector(
                    onTap: widget.onAvatarTap,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isPrivate 
                              ? Colors.grey 
                              : _avatarColor,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isPrivate 
                                ? Colors.grey.withOpacity(0.2)
                                : _avatarColor.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: ColorFiltered(
                          colorFilter: widget.isPrivate
                              ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                              : const ColorFilter.mode(Colors.transparent, BlendMode.overlay),
                          child: (_customAvatarUrl != null && _customAvatarUrl!.startsWith('http'))
                            ? Image.network(
                                _customAvatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) => Image.asset(
                                  _avatarImagePath,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                _avatarImagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) {
                                  // Fallback to colored circle with initial
                                  return Container(
                                    color: _avatarColor,
                                    child: Center(
                                      child: Text(
                                        widget.archetype.isNotEmpty 
                                            ? widget.archetype[0].toUpperCase() 
                                            : 'S',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Privacy indicator (eye icon)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: widget.isPrivate ? Colors.red[900] : Colors.green[700],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF050505),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          widget.isPrivate ? LucideIcons.eyeOff : LucideIcons.eye,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // State label
          const SizedBox(height: 6),
          Text(
            widget.isPrivate ? 'Blind' : 'Observing',
            style: TextStyle(
              color: widget.isPrivate 
                  ? Colors.red[400] 
                  : Colors.green[400],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
    );
  }
}

/// Half-sheet chat panel that expands from avatar
class AvatarChatPanel extends StatelessWidget {
  final String archetype;
  final VoidCallback onClose;
  final Widget child; // Chat content
  
  const AvatarChatPanel({
    super.key,
    required this.archetype,
    required this.onClose,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      archetype.isNotEmpty 
                          ? archetype[0].toUpperCase() + archetype.substring(1)
                          : 'Sable',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(LucideIcons.x, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              
              const Divider(color: Colors.white12),
              
              // Content
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
