import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/memory/unified_memory_service.dart';
import 'package:sable/core/memory/models/extracted_memory.dart';
import 'package:sable/core/emotion/weather_service.dart';
import 'package:sable/core/media/now_playing_service.dart';
import 'package:geolocator/geolocator.dart';
import 'memory_category_detail_screen.dart';

/// Knowledge Center - AI Memory Management Dashboard
/// Gives users complete visibility and control over what the AI knows about them
class KnowledgeCenterScreen extends StatefulWidget {
  const KnowledgeCenterScreen({super.key});

  @override
  State<KnowledgeCenterScreen> createState() => _KnowledgeCenterScreenState();
}

class _KnowledgeCenterScreenState extends State<KnowledgeCenterScreen> {
  final UnifiedMemoryService _memoryService = UnifiedMemoryService();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = true;
  List<ExtractedMemory> _allMemories = [];
  List<ExtractedMemory> _filteredMemories = [];
  Map<String, dynamic> _stats = {};
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    await _memoryService.initialize();
    final memories = _memoryService.getAllMemories();
    final stats = _memoryService.getMemoriesStats();
    
    setState(() {
      _allMemories = memories;
      _filteredMemories = memories;
      _stats = stats;
      _isLoading = false;
    });
  }
  
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredMemories = _allMemories;
        _isSearching = false;
      });
    } else {
      setState(() {
        _filteredMemories = _allMemories.where((m) => m.matchesQuery(query)).toList();
        _isSearching = true;
      });
    }
  }
  
  void _openCategoryDetail(MemoryCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemoryCategoryDetailScreen(
          category: category,
          onMemoriesChanged: _loadData,
        ),
      ),
    );
  }
  
  Future<void> _exportMemories() async {
    try {
      final jsonExport = await _memoryService.exportAllMemoriesToJson();
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/knowledge_export_$timestamp.json');
      await file.writeAsString(jsonExport);
      
      // Get the render box for positioning the share sheet (required on iPad)
      final box = context.findRenderObject() as RenderBox?;
      
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Sable Knowledge Export',
        sharePositionOrigin: box != null 
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 100, 100),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Knowledge exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _clearAllMemories() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        title: Text(
          'Clear All Knowledge?',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete all ${_stats['total'] ?? 0} memories the AI has learned about you. This cannot be undone.',
          style: GoogleFonts.inter(color: AelianaColors.ghost),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AelianaColors.ghost)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _memoryService.clearMemories();
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All knowledge cleared'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  Future<void> _addManualMemory() async {
    final contentController = TextEditingController();
    final summaryController = TextEditingController();
    MemoryCategory selectedCategory = MemoryCategory.misc;
    int importance = 3;
    int energyLevel = 5;
    String? vibeColor; // Hex color for vibe gradient
    
    // Auto-capture current location (GPS only)
    String? locationName;
    double? latitude;
    double? longitude;
    String? weather;
    
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      latitude = position.latitude;
      longitude = position.longitude;
      locationName = '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
      
      // Fetch weather for location
      final weatherCondition = await WeatherService.getWeatherByCoords(latitude, longitude);
      if (weatherCondition != null) {
        weather = '${weatherCondition.description}, ${weatherCondition.temperature.round()}°F';
      }
    } catch (e) {
      debugPrint('📍 Location/weather capture failed: $e');
    }
    
    // Capture now playing music
    String? nowPlayingTrack;
    String? nowPlayingService;
    try {
      final nowPlaying = await NowPlayingService.getCurrentTrack();
      if (nowPlaying != null) {
        nowPlayingTrack = '${nowPlaying.title} - ${nowPlaying.artist}';
        nowPlayingService = nowPlaying.source;
      }
    } catch (e) {
      debugPrint('🎵 Now playing capture failed: $e');
    }
    
    // People tagging state
    List<String> taggedPeople = [];
    bool isGroupActivity = false;
    final peopleController = TextEditingController();
    
    // Recent people for quick tagging (could be loaded from previous memories)
    final recentPeople = ['Mom', 'Dad', 'Best Friend', 'Partner', 'Coworker'];
    
    // Headlines capture (World + National/Local)
    String? worldHeadline;
    String? localHeadline;
    // TODO: Integrate with news API - for now these are populated via user input
    // Future: NewsAPI or similar to auto-fetch current headlines
    
    // Vibe color options
    final vibeColors = [
      {'name': 'Sunny', 'color': '#FFD700', 'gradient': [Colors.yellow, Colors.orange]},
      {'name': 'Calm', 'color': '#4CAF50', 'gradient': [Colors.green, Colors.teal]},
      {'name': 'Melancholy', 'color': '#607D8B', 'gradient': [Colors.blueGrey, Colors.grey]},
      {'name': 'Electric', 'color': '#E91E63', 'gradient': [Colors.pink, Colors.purple]},
      {'name': 'Cozy', 'color': '#8D6E63', 'gradient': [Colors.brown, Colors.orange.shade900]},
      {'name': 'Fresh', 'color': '#00BCD4', 'gradient': [Colors.cyan, Colors.blue]},
    ];
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AelianaColors.carbon,
          title: Row(
            children: [
              Icon(LucideIcons.plus, color: AelianaColors.hyperGold, size: 20),
              const SizedBox(width: 8),
              Text('Add Memory', style: GoogleFonts.inter(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // One-sentence summary (title)
                TextField(
                  controller: summaryController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Title (e.g. "The day I got promoted")',
                    hintStyle: TextStyle(color: AelianaColors.ghost),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'What should I remember about you?',
                    hintStyle: TextStyle(color: AelianaColors.ghost),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AelianaColors.ghost.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AelianaColors.ghost.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AelianaColors.hyperGold),
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                  ),
                ),
                
                // Location and Weather indicator
                if (locationName != null || weather != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (locationName != null)
                          Row(
                            children: [
                              Icon(LucideIcons.mapPin, size: 14, color: AelianaColors.plasmaCyan),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  locationName,
                                  style: GoogleFonts.inter(fontSize: 11, color: AelianaColors.plasmaCyan),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        if (weather != null) ...[
                          if (locationName != null) const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(LucideIcons.cloud, size: 14, color: Colors.blueGrey.shade300),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  weather,
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.blueGrey.shade300),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (nowPlayingTrack != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(LucideIcons.music, size: 14, color: Colors.green.shade400),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  nowPlayingTrack,
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.green.shade400),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                // Vibe Color Picker
                const SizedBox(height: 16),
                Text('Vibe', style: GoogleFonts.inter(color: AelianaColors.ghost, fontSize: 12)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: vibeColors.length,
                    itemBuilder: (context, index) {
                      final vibe = vibeColors[index];
                      final isSelected = vibeColor == vibe['color'];
                      final gradient = vibe['gradient'] as List<Color>;
                      return GestureDetector(
                        onTap: () => setDialogState(() {
                          vibeColor = isSelected ? null : vibe['color'] as String;
                        }),
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected 
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              vibe['name'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // People Tagging Section
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Who was there?', style: GoogleFonts.inter(color: AelianaColors.ghost, fontSize: 12)),
                    // Group toggle
                    Row(
                      children: [
                        Text('Group', style: GoogleFonts.inter(color: AelianaColors.ghost, fontSize: 11)),
                        const SizedBox(width: 4),
                        Switch(
                          value: isGroupActivity,
                          onChanged: (v) => setDialogState(() => isGroupActivity = v),
                          activeColor: AelianaColors.hyperGold,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Quick add chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...recentPeople.map((person) {
                      final isAdded = taggedPeople.contains(person);
                      return GestureDetector(
                        onTap: () => setDialogState(() {
                          if (isAdded) {
                            taggedPeople.remove(person);
                          } else {
                            taggedPeople.add(person);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAdded ? Colors.blue.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isAdded ? Colors.blue : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAdded) Icon(LucideIcons.check, size: 12, color: Colors.blue),
                              if (isAdded) const SizedBox(width: 4),
                              Text(person, style: GoogleFonts.inter(fontSize: 11, color: isAdded ? Colors.blue : AelianaColors.ghost)),
                            ],
                          ),
                        ),
                      );
                    }),
                    // Add custom person
                    GestureDetector(
                      onTap: () async {
                        final result = await showDialog<String>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AelianaColors.carbon,
                            title: Text('Add Person', style: GoogleFonts.inter(color: Colors.white)),
                            content: TextField(
                              controller: peopleController,
                              style: GoogleFonts.inter(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Name',
                                hintStyle: TextStyle(color: AelianaColors.ghost),
                              ),
                              autofocus: true,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('Cancel', style: TextStyle(color: AelianaColors.ghost)),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx, peopleController.text.trim());
                                  peopleController.clear();
                                },
                                child: Text('Add', style: TextStyle(color: AelianaColors.hyperGold)),
                              ),
                            ],
                          ),
                        );
                        if (result != null && result.isNotEmpty) {
                          setDialogState(() => taggedPeople.add(result));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AelianaColors.ghost.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.plus, size: 12, color: AelianaColors.ghost),
                            const SizedBox(width: 4),
                            Text('Add', style: GoogleFonts.inter(fontSize: 11, color: AelianaColors.ghost)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Headlines Section (World + Local)
                const SizedBox(height: 16),
                Text('What was happening?', style: GoogleFonts.inter(color: AelianaColors.ghost, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(LucideIcons.globe, size: 14, color: Colors.orange.shade300),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'World headline (optional)',
                          hintStyle: TextStyle(color: AelianaColors.ghost.withOpacity(0.5), fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) => worldHeadline = v.isEmpty ? null : v,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(LucideIcons.mapPin, size: 14, color: Colors.purple.shade300),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Local/national headline (optional)',
                          hintStyle: TextStyle(color: AelianaColors.ghost.withOpacity(0.5), fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) => localHeadline = v.isEmpty ? null : v,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                Text('Category', style: GoogleFonts.inter(color: AelianaColors.ghost, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MemoryCategory.values.map((cat) {
                    final isSelected = cat == selectedCategory;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AelianaColors.hyperGold.withOpacity(0.2) : Colors.black26,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AelianaColors.hyperGold : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(cat),
                              size: 14,
                              color: isSelected ? AelianaColors.hyperGold : AelianaColors.ghost,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cat.name,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isSelected ? AelianaColors.hyperGold : AelianaColors.ghost,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),
                Text('Importance', style: GoogleFonts.inter(color: AelianaColors.ghost, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starValue = i + 1;
                    return GestureDetector(
                      onTap: () => setDialogState(() => importance = starValue),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          starValue <= importance ? LucideIcons.star : Icons.star_border,
                          color: starValue <= importance ? AelianaColors.hyperGold : AelianaColors.ghost,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ),
                
                // Energy Level (Vibe)
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Energy Level', style: GoogleFonts.inter(color: AelianaColors.ghost, fontSize: 12)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getEnergyColor(energyLevel).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getEnergyLabel(energyLevel),
                        style: GoogleFonts.inter(fontSize: 11, color: _getEnergyColor(energyLevel), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    activeTrackColor: _getEnergyColor(energyLevel),
                    inactiveTrackColor: Colors.white10,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: energyLevel.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (v) => setDialogState(() => energyLevel = v.round()),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Exhausted', style: GoogleFonts.inter(color: Colors.blue[300], fontSize: 10)),
                    Text('Wired', style: GoogleFonts.inter(color: Colors.orange[300], fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AelianaColors.ghost)),
            ),
            TextButton(
              onPressed: () {
                if (contentController.text.trim().isNotEmpty) {
                  // Combine headlines as "World: X | Local: Y"
                  String? topHeadline;
                  if (worldHeadline != null || localHeadline != null) {
                    final parts = <String>[];
                    if (worldHeadline != null) parts.add('🌍 $worldHeadline');
                    if (localHeadline != null) parts.add('📍 $localHeadline');
                    topHeadline = parts.join(' | ');
                  }
                  
                  Navigator.pop(context, {
                    'content': contentController.text.trim(),
                    'category': selectedCategory,
                    'importance': importance,
                    'energyLevel': energyLevel,
                    'summary': summaryController.text.trim(),
                    'locationName': locationName,
                    'latitude': latitude,
                    'longitude': longitude,
                    'weather': weather,
                    'vibeColor': vibeColor,
                    'nowPlayingTrack': nowPlayingTrack,
                    'nowPlayingService': nowPlayingService,
                    'taggedPeople': taggedPeople,
                    'isGroupActivity': isGroupActivity,
                    'topHeadline': topHeadline,
                  });
                }
              },
              child: Text('Add', style: TextStyle(color: AelianaColors.hyperGold)),
            ),
          ],
        ),
      ),
    );
    
    if (result != null) {
      await _memoryService.addMemory(
        content: result['content'],
        category: result['category'],
        importance: result['importance'],
        energyLevel: result['energyLevel'],
        oneSentenceSummary: result['summary']?.isNotEmpty == true ? result['summary'] : null,
        locationName: result['locationName'],
        latitude: result['latitude'],
        longitude: result['longitude'],
        weather: result['weather'],
        vibeColor: result['vibeColor'],
        nowPlayingTrack: result['nowPlayingTrack'],
        nowPlayingService: result['nowPlayingService'],
        taggedPeople: result['taggedPeople'] ?? [],
        isGroupActivity: result['isGroupActivity'] ?? false,
        topHeadline: result['topHeadline'],
      );
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Memory added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  Color _getEnergyColor(int energy) {
    if (energy <= 3) return Colors.blue[400]!;
    if (energy <= 6) return Colors.green;
    return Colors.orange[400]!;
  }
  
  String _getEnergyLabel(int energy) {
    if (energy <= 2) return 'Exhausted';
    if (energy <= 4) return 'Low';
    if (energy <= 6) return 'Balanced';
    if (energy <= 8) return 'Energetic';
    return 'Wired';
  }
  
  IconData _getCategoryIcon(MemoryCategory category) {
    switch (category) {
      case MemoryCategory.people: return LucideIcons.users;
      case MemoryCategory.preferences: return LucideIcons.heart;
      case MemoryCategory.dates: return LucideIcons.calendar;
      case MemoryCategory.life: return LucideIcons.home;
      case MemoryCategory.emotional: return LucideIcons.smile;
      case MemoryCategory.goals: return LucideIcons.target;
      case MemoryCategory.misc: return LucideIcons.folder;
    }
  }
  
  Color _getCategoryColor(MemoryCategory category) {
    switch (category) {
      case MemoryCategory.people: return Colors.blue;
      case MemoryCategory.preferences: return Colors.pink;
      case MemoryCategory.dates: return Colors.purple;
      case MemoryCategory.life: return Colors.green;
      case MemoryCategory.emotional: return Colors.orange;
      case MemoryCategory.goals: return AelianaColors.hyperGold;
      case MemoryCategory.misc: return AelianaColors.ghost;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: _buildHeader(),
                  ),
                  
                  // Search Bar
                  SliverToBoxAdapter(
                    child: _buildSearchBar(),
                  ),
                  
                  // Stats Overview
                  if (!_isSearching)
                    SliverToBoxAdapter(
                      child: _buildStatsOverview(),
                    ),
                  
                  // Category Grid or Search Results
                  _isSearching
                      ? _buildSearchResults()
                      : SliverToBoxAdapter(
                          child: _buildCategoryGrid(),
                        ),
                  
                  // Recent Memories
                  if (!_isSearching && _allMemories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildRecentMemories(),
                    ),
                  
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addManualMemory,
        backgroundColor: AelianaColors.hyperGold,
        child: const Icon(LucideIcons.plus, color: Colors.black),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Knowledge Center',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'What I know about you',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AelianaColors.ghost,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(LucideIcons.moreVertical, color: AelianaColors.ghost),
                color: AelianaColors.carbon,
                onSelected: (value) {
                  switch (value) {
                    case 'export':
                      _exportMemories();
                      break;
                    case 'clear':
                      _clearAllMemories();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(LucideIcons.download, size: 18, color: AelianaColors.ghost),
                        const SizedBox(width: 12),
                        Text('Export All', style: GoogleFonts.inter(color: Colors.white)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        const Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                        const SizedBox(width: 12),
                        Text('Clear All', style: GoogleFonts.inter(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search memories...',
            hintStyle: GoogleFonts.inter(color: AelianaColors.ghost),
            prefixIcon: Icon(LucideIcons.search, color: AelianaColors.ghost, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(LucideIcons.x, color: AelianaColors.ghost, size: 18),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatsOverview() {
    final total = _stats['total'] ?? 0;
    final lastExtracted = _stats['lastExtracted'] as DateTime?;
    final totalTags = _stats['totalTags'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AelianaColors.hyperGold.withOpacity(0.15),
            AelianaColors.hyperGold.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AelianaColors.hyperGold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: LucideIcons.brain,
            value: total.toString(),
            label: 'Memories',
          ),
          Container(width: 1, height: 40, color: AelianaColors.ghost.withOpacity(0.3)),
          _buildStatItem(
            icon: LucideIcons.tag,
            value: totalTags.toString(),
            label: 'Tags',
          ),
          Container(width: 1, height: 40, color: AelianaColors.ghost.withOpacity(0.3)),
          _buildStatItem(
            icon: LucideIcons.clock,
            value: lastExtracted != null 
                ? DateFormat('MMM d').format(lastExtracted)
                : 'Never',
            label: 'Last Update',
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: AelianaColors.hyperGold, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AelianaColors.ghost,
          ),
        ),
      ],
    );
  }
  
  Widget _buildCategoryGrid() {
    final categoryStats = _stats['categoryStats'] as Map<MemoryCategory, int>? ?? {};
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATEGORIES',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AelianaColors.ghost,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: MemoryCategory.values.length,
            itemBuilder: (context, index) {
              final category = MemoryCategory.values[index];
              final count = categoryStats[category] ?? 0;
              
              return _buildCategoryCard(category, count);
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryCard(MemoryCategory category, int count) {
    final color = _getCategoryColor(category);
    final icon = _getCategoryIcon(category);
    
    return GestureDetector(
      onTap: () => _openCategoryDetail(category),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(
                  count.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              category.name.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentMemories() {
    // Sort by extraction date, most recent first
    final recentMemories = List<ExtractedMemory>.from(_allMemories)
      ..sort((a, b) => b.extractedAt.compareTo(a.extractedAt));
    final displayMemories = recentMemories.take(5).toList();
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENT MEMORIES',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AelianaColors.ghost,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...displayMemories.map((memory) => _buildMemoryTile(memory)),
        ],
      ),
    );
  }
  
  Widget _buildMemoryTile(ExtractedMemory memory) {
    final color = _getCategoryColor(memory.category);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getCategoryIcon(memory.category), color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memory.content,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy').format(memory.extractedAt),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AelianaColors.ghost,
                  ),
                ),
              ],
            ),
          ),
          // Importance stars
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(memory.importance, (i) => 
              Icon(LucideIcons.star, size: 10, color: AelianaColors.hyperGold),
            ),
          ),
        ],
      ),
    );
  }
  
  SliverList _buildSearchResults() {
    if (_filteredMemories.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(LucideIcons.searchX, size: 48, color: AelianaColors.ghost),
                const SizedBox(height: 16),
                Text(
                  'No memories found',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AelianaColors.ghost,
                  ),
                ),
              ],
            ),
          ),
        ]),
      );
    }
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final memory = _filteredMemories[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: _buildMemoryTile(memory),
          );
        },
        childCount: _filteredMemories.length,
      ),
    );
  }
}
