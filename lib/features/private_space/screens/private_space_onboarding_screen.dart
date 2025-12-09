import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/theme/aeliana_theme.dart';
import '../widgets/private_avatar_picker.dart';
import '../models/private_user_persona.dart';
import 'private_space_chat_screen.dart';
import 'private_avatar_customize_screen.dart';

/// Private Space onboarding - shows on first entry
/// Lets user choose companion and set up persona before chatting
class PrivateSpaceOnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  
  const PrivateSpaceOnboardingScreen({super.key, this.onComplete});

  @override
  State<PrivateSpaceOnboardingScreen> createState() => _PrivateSpaceOnboardingScreenState();
}

class _PrivateSpaceOnboardingScreenState extends State<PrivateSpaceOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Selected avatar
  String? _selectedAvatarId;
  PrivateAvatar? _selectedAvatar;
  
  // User persona
  final _nameController = TextEditingController();
  int? _age;
  String? _gender;
  
  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }
  
  void _selectAvatar(PrivateAvatar avatar) {
    setState(() {
      _selectedAvatarId = avatar.id;
      _selectedAvatar = avatar;
    });
  }
  
  void _nextPage() {
    if (_currentPage == 0 && _selectedAvatarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a companion first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save selected avatar
    await prefs.setString('private_space_avatar', _selectedAvatarId ?? 'luna');
    
    // Save persona if name provided
    if (_nameController.text.trim().isNotEmpty) {
      final persona = PrivateUserPersona.create(
        name: _nameController.text.trim(),
        age: _age,
        gender: _gender,
      );
      await prefs.setString('private_space_persona', jsonEncode({
        'name': persona.aliasName,
        'age': persona.aliasAge,
        'gender': persona.aliasGender,
      }));
    }
    
    // Mark onboarding complete
    await prefs.setBool('private_space_onboarding_complete', true);
    
    if (!mounted) return;
    
    // Call onComplete callback if provided (for lock screen integration)
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      // Navigate to chat directly
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PrivateSpaceChatScreen()),
      );
    }
  }
  
  void _openCustomAvatarCreator() {
    if (_selectedAvatar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a base companion first, then customize'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrivateAvatarCustomizeScreen(
          selectedAvatar: _selectedAvatar!,
          onComplete: () {
            Navigator.of(context).pop(); // Close customize screen
            _completeOnboarding();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildProgressDot(0),
                  Expanded(child: _buildProgressLine(0)),
                  _buildProgressDot(1),
                ],
              ),
            ),
            
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildAvatarSelectionPage(),
                  _buildPersonaSetupPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProgressDot(int index) {
    final isActive = _currentPage >= index;
    final isComplete = _currentPage > index;
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AelianaColors.hyperGold : AelianaColors.carbon,
        border: Border.all(
          color: isActive ? AelianaColors.hyperGold : Colors.white24,
          width: 2,
        ),
      ),
      child: Center(
        child: isComplete
            ? const Icon(LucideIcons.check, color: Colors.black, size: 16)
            : Text(
                '${index + 1}',
                style: GoogleFonts.spaceGrotesk(
                  color: isActive ? Colors.black : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
  
  Widget _buildProgressLine(int index) {
    final isComplete = _currentPage > index;
    
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isComplete ? AelianaColors.hyperGold : Colors.white24,
    );
  }
  
  // Page 1: Choose your companion
  Widget _buildAvatarSelectionPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Private Space',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your companion for this encrypted sanctuary',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 24),
          
          // Create Your Persona option - AT TOP
          _buildCreateYourOwnOption(),
          
          const SizedBox(height: 16),
          
          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white24)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR CHOOSE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white38,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.white24)),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Pre-made avatar options
          ...PrivateAvatar.all.map((avatar) => _buildAvatarOption(avatar)),
          
          const SizedBox(height: 24),
          
          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedAvatarId != null ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedAvatar?.accentColor ?? AelianaColors.hyperGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white38,
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAvatarOption(PrivateAvatar avatar) {
    final isSelected = _selectedAvatarId == avatar.id;
    
    return GestureDetector(
      onTap: () => _selectAvatar(avatar),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? avatar.accentColor.withOpacity(0.15)
              : AelianaColors.carbon,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? avatar.accentColor : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: avatar.accentColor.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ] : null,
        ),
        child: Row(
          children: [
            // Avatar image
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: avatar.accentColor, width: 3),
                image: avatar.imagePath != null
                    ? DecorationImage(
                        image: AssetImage(avatar.imagePath!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatar.imagePath == null
                  ? Center(child: Text(avatar.emoji, style: const TextStyle(fontSize: 32)))
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        avatar.name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        avatar.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    avatar.tagline,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: avatar.accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    avatar.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Selection indicator
            if (isSelected)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatar.accentColor,
                ),
                child: const Icon(LucideIcons.check, color: Colors.white, size: 18),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCreateYourOwnOption() {
    return GestureDetector(
      onTap: () {
        // Navigate to custom avatar creator with Luna as default base
        final baseAvatar = PrivateAvatar.getById('luna')!;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PrivateAvatarCustomizeScreen(
              selectedAvatar: baseAvatar,
              onComplete: () {
                Navigator.of(context).pop(); // Close customize screen
                setState(() {
                  _selectedAvatarId = 'luna';
                  _selectedAvatar = baseAvatar;
                });
                _nextPage(); // Move to persona setup page
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AelianaColors.hyperGold.withOpacity(0.15),
              AelianaColors.plasmaCyan.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AelianaColors.hyperGold.withOpacity(0.5), width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AelianaColors.hyperGold.withOpacity(0.3),
                    AelianaColors.plasmaCyan.withOpacity(0.2),
                  ],
                ),
                border: Border.all(color: AelianaColors.hyperGold, width: 2),
              ),
              child: const Center(
                child: Icon(LucideIcons.sparkles, color: AelianaColors.hyperGold, size: 32),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Your Persona',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AelianaColors.hyperGold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Design a custom companion with AI',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AelianaColors.hyperGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.chevronRight,
                color: AelianaColors.hyperGold,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Page 2: Introduce yourself
  Widget _buildPersonaSetupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: _previousPage,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.arrowLeft, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Back',
                  style: GoogleFonts.inter(color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Header with selected avatar
          Row(
            children: [
              if (_selectedAvatar != null) ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _selectedAvatar!.accentColor, width: 2),
                    image: _selectedAvatar!.imagePath != null
                        ? DecorationImage(
                            image: AssetImage(_selectedAvatar!.imagePath!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedAvatar!.imagePath == null
                      ? Center(child: Text(_selectedAvatar!.emoji, style: const TextStyle(fontSize: 24)))
                      : null,
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Introduce Yourself',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'to ${_selectedAvatar?.name ?? 'your companion'}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: _selectedAvatar?.accentColor ?? Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Name input
          Text(
            'What should I call you?',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Your name or alias...',
              hintStyle: GoogleFonts.inter(color: Colors.white30),
              filled: true,
              fillColor: AelianaColors.carbon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _selectedAvatar?.accentColor ?? AelianaColors.hyperGold),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),
          
          // Optional: Age
          Text(
            'Age (optional)',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [18, 25, 30, 40, 50].map((age) => 
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$age+'),
                  selected: _age == age,
                  onSelected: (selected) => setState(() => _age = selected ? age : null),
                  backgroundColor: AelianaColors.carbon,
                  selectedColor: _selectedAvatar?.accentColor ?? AelianaColors.hyperGold,
                  labelStyle: GoogleFonts.inter(
                    color: _age == age ? Colors.black : Colors.white54,
                  ),
                ),
              ),
            ).toList(),
          ),
          const SizedBox(height: 48),
          
          // Start chatting button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _completeOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedAvatar?.accentColor ?? AelianaColors.hyperGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Start Chatting with ${_selectedAvatar?.name ?? 'Companion'}',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.messageCircle, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Skip option
          Center(
            child: TextButton(
              onPressed: _completeOnboarding,
              child: Text(
                'Skip for now',
                style: GoogleFonts.inter(color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
