import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/aeliana_theme.dart';
import '../../../core/ai/room_brain/settings_agent_brain.dart';
import '../../../core/voice/voice_service.dart';

/// A chat message in the settings assistant
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Shows the settings chat sheet
void showSettingsChatSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const SettingsChatSheet(),
  );
}

/// Inline chat sheet for settings control - stays in More screen
class SettingsChatSheet extends StatefulWidget {
  const SettingsChatSheet({super.key});

  @override
  State<SettingsChatSheet> createState() => _SettingsChatSheetState();
}

class _SettingsChatSheetState extends State<SettingsChatSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SettingsAgentBrain _agent = SettingsAgentBrain();
  final VoiceService _voiceService = VoiceService();
  
  final List<_ChatMessage> _messages = [];
  bool _isProcessing = false;
  bool _isListening = false;
  String _avatarUrl = '';
  String _archetypeId = 'aeliana';
  String _userName = 'there';

  @override
  void initState() {
    super.initState();
    _initAgent();
    _loadUserSettings();
  }

  Future<void> _initAgent() async {
    await _agent.init();
    // Add greeting
    setState(() {
      _messages.add(_ChatMessage(
        text: "Hi! I can help you control settings. Try:\n• \"Turn on haptic feedback\"\n• \"What's enabled?\"\n• \"Find voice settings\"",
        isUser: false,
      ));
    });
  }

  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'there';
      _archetypeId = prefs.getString('archetype_id') ?? 'aeliana';
      _avatarUrl = prefs.getString('avatar_url') ?? '';
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    // Add user message
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isProcessing = true;
    });
    _textController.clear();
    _scrollToBottom();

    // Get AI response
    final response = await _agent.processCommand(text);
    
    setState(() {
      _messages.add(_ChatMessage(text: response.message, isUser: false));
      _isProcessing = false;
    });
    _scrollToBottom();

    // Haptic feedback on setting change
    if (response.action == SettingsAgentAction.settingChanged) {
      HapticFeedback.mediumImpact();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startVoiceInput() async {
    setState(() => _isListening = true);
    HapticFeedback.lightImpact();
    
    try {
      // Use speech-to-text
      final result = await _voiceService.listenForSpeech();
      if (result != null && result.isNotEmpty) {
        await _sendMessage(result);
      }
    } finally {
      setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final imagePath = _avatarUrl.isNotEmpty 
        ? _avatarUrl 
        : 'assets/images/archetypes/$_archetypeId.png';
    
    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: AelianaColors.obsidian,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AelianaColors.plasmaCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AelianaColors.stardust.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header with avatar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: imagePath.startsWith('http')
                      ? NetworkImage(imagePath) as ImageProvider
                      : AssetImage(imagePath),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings Assistant',
                        style: GoogleFonts.spaceGrotesk(
                          color: AelianaColors.hyperGold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Control app settings with voice or text',
                        style: GoogleFonts.inter(
                          color: AelianaColors.stardust,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, color: AelianaColors.stardust),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10),
          
          // Quick action chips
          _buildQuickActions(),
          
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isProcessing ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isProcessing && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          
          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final quickActions = [
      ("What's on?", "Show enabled settings"),
      ("Help", "What can you do?"),
      ("Haptics off", "Turn off haptic feedback"),
    ];
    
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: quickActions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, _) = quickActions[index];
          return ActionChip(
            label: Text(label),
            labelStyle: GoogleFonts.inter(
              color: AelianaColors.plasmaCyan,
              fontSize: 12,
            ),
            backgroundColor: AelianaColors.carbon,
            side: BorderSide(color: AelianaColors.plasmaCyan.withOpacity(0.3)),
            onPressed: () => _sendMessage(label),
          );
        },
      ),
    );
  }

  Widget _buildMessage(_ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser 
              ? AelianaColors.plasmaCyan.withOpacity(0.2)
              : AelianaColors.carbon,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: message.isUser 
                ? AelianaColors.plasmaCyan.withOpacity(0.3)
                : Colors.white10,
          ),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AelianaColors.carbon,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AelianaColors.plasmaCyan.withOpacity(0.5 + (value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: TextField(
              controller: _textController,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ask about settings...',
                hintStyle: GoogleFonts.inter(color: AelianaColors.stardust),
                filled: true,
                fillColor: AelianaColors.obsidian,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          
          // Mic button
          GestureDetector(
            onTap: _isListening ? null : _startVoiceInput,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isListening 
                    ? AelianaColors.hyperGold 
                    : AelianaColors.plasmaCyan,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isListening ? LucideIcons.micOff : LucideIcons.mic,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
