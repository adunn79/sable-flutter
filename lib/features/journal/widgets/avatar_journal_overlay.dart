import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;

/// Avatar overlay widget for journal screens
/// Shows privacy state (observing/blind) and can expand to chat panel
class AvatarJournalOverlay extends StatefulWidget {
  /// Whether the current entry is private (Avatar is blind)
  final bool isPrivate;
  
  /// Callback when "Spark" prompt button is tapped
  final VoidCallback? onSparkTap;
  
  /// Callback when avatar is tapped (expand chat)
  final VoidCallback? onAvatarTap;
  
  /// Current avatar archetype (sable, kai, echo)
  final String archetype;
  
  const AvatarJournalOverlay({
    super.key,
    this.isPrivate = false,
    this.onSparkTap,
    this.onAvatarTap,
    this.archetype = 'sable',
  });

  @override
  State<AvatarJournalOverlay> createState() => _AvatarJournalOverlayState();
}

class _AvatarJournalOverlayState extends State<AvatarJournalOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
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
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  Color get _avatarColor {
    switch (widget.archetype.toLowerCase()) {
      case 'kai':
        return const Color(0xFF3B82F6); // Blue
      case 'echo':
        return const Color(0xFF10B981); // Green
      default:
        return const Color(0xFF8B5CF6); // Purple for Sable
    }
  }
  
  String get _avatarImagePath {
    switch (widget.archetype.toLowerCase()) {
      case 'kai':
        return 'assets/images/archetypes/kai.png';
      case 'echo':
        return 'assets/images/archetypes/echo.png';
      default:
        return 'assets/images/archetypes/sable.png';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    debugPrint('🎭 Building AvatarJournalOverlay: archetype=${widget.archetype}, isPrivate=${widget.isPrivate}');
    return Positioned(
      bottom: 200, // Higher above the keyboard/toolbar
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Spark button (AI prompt suggestion)
          if (widget.onSparkTap != null && !widget.isPrivate)
            GestureDetector(
              onTap: widget.onSparkTap,
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(LucideIcons.sparkles, color: Colors.black87, size: 22),
                ),
              ),
            ),
          
          // Avatar with privacy state
          GestureDetector(
            onTap: widget.onAvatarTap,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isPrivate ? 1.0 : _pulseAnimation.value,
                  child: child,
                );
              },
              child: Stack(
                children: [
                  // Main avatar circle with actual image
                  Container(
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
                        child: Image.asset(
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
      ),
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
