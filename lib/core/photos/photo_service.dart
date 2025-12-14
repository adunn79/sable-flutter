import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'models/photo_entry.dart';

/// Central photo management service
/// - References device photos by default
/// - Copies to encrypted storage only when marked Private
/// - Generates thumbnails, extracts EXIF, manages lifecycle
class PhotoService {
  static PhotoService? _instance;
  static const String _boxName = 'photo_library';
  static const String _privateBoxName = 'private_photos_data';
  static const String _encryptionKeyName = 'photo_library_encryption_key';
  static const String _thumbnailDir = 'photo_thumbnails';

  Box<PhotoEntry>? _photoBox;
  Box<Uint8List>? _privateDataBox; // Stores encrypted photo bytes
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final _uuid = const Uuid();
  String? _thumbnailPath;

  PhotoService._();

  static Future<PhotoService> getInstance() async {
    if (_instance == null) {
      _instance = PhotoService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    try {
      // Set up thumbnail directory
      final appDir = await getApplicationDocumentsDirectory();
      _thumbnailPath = '${appDir.path}/$_thumbnailDir';
      await Directory(_thumbnailPath!).create(recursive: true);

      // Get or create encryption key for private photos
      String? encryptionKeyString = await _secureStorage.read(key: _encryptionKeyName);
      if (encryptionKeyString == null) {
        final key = Hive.generateSecureKey();
        encryptionKeyString = base64Encode(key);
        await _secureStorage.write(key: _encryptionKeyName, value: encryptionKeyString);
      }
      final encryptionKey = base64Decode(encryptionKeyString);

      // Register adapter if needed
      if (!Hive.isAdapterRegistered(60)) {
        Hive.registerAdapter(PhotoEntryAdapter());
      }

      // Open boxes
      _photoBox = await Hive.openBox<PhotoEntry>(_boxName);
      _privateDataBox = await Hive.openBox<Uint8List>(
        _privateBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );

      debugPrint('📷 PhotoService initialized: ${_photoBox?.length ?? 0} photos');
    } catch (e) {
      debugPrint('❌ PhotoService init error: $e');
    }
  }

  // ============================================
  // PHOTO MANAGEMENT
  // ============================================

  /// Add a photo to the library
  /// [path] - Path to the photo file
  /// [isPrivate] - If true, copies to encrypted storage
  Future<PhotoEntry?> addPhoto(String path, {
    bool isPrivate = false,
    String? caption,
    List<String>? tags,
    String? linkedJournalId,
  }) async {
    try {
      final id = _uuid.v4();
      final file = File(path);
      
      if (!await file.exists()) {
        debugPrint('❌ Photo file not found: $path');
        return null;
      }

      String? privatePath;
      
      // If private, copy to encrypted storage
      if (isPrivate) {
        final bytes = await file.readAsBytes();
        await _privateDataBox?.put(id, bytes);
        privatePath = 'encrypted:$id'; // Marker that it's in encrypted storage
        debugPrint('🔒 Photo copied to encrypted storage');
      }

      // Generate thumbnail
      final thumbnailPath = await _generateThumbnail(path, id);

      // Extract EXIF data
      DateTime? takenAt;
      String? location;
      String? cameraInfo;
      
      try {
        final exifData = await _extractExifData(file);
        takenAt = exifData['dateTime'] as DateTime?;
        location = exifData['location'] as String?;
        cameraInfo = exifData['camera'] as String?;
        
        // Fallback to file modification time if no EXIF date
        if (takenAt == null) {
          final stat = await file.stat();
          takenAt = stat.modified;
        }
        
        debugPrint('📷 EXIF extracted: date=$takenAt, location=$location, camera=$cameraInfo');
      } catch (e) {
        debugPrint('⚠️ EXIF extraction failed: $e');
        try {
          final stat = await file.stat();
          takenAt = stat.modified;
        } catch (_) {}
      }

      final entry = PhotoEntry(
        id: id,
        originalPath: path,
        privatePath: privatePath,
        thumbnailPath: thumbnailPath,
        isPrivate: isPrivate,
        createdAt: DateTime.now(),
        takenAt: takenAt,
        location: location,
        caption: caption,
        tags: tags,
        linkedJournalId: linkedJournalId,
      );

      await _photoBox?.put(id, entry);
      debugPrint('📷 Photo added: $id (private: $isPrivate)');
      
      return entry;
    } catch (e) {
      debugPrint('❌ Error adding photo: $e');
      return null;
    }
  }

  /// Get a photo by ID
  PhotoEntry? getPhoto(String id) => _photoBox?.get(id);

  /// Get all photos
  List<PhotoEntry> getAllPhotos() => _photoBox?.values.toList() ?? [];

  /// Get photos that can be sent to AI (non-private only)
  List<PhotoEntry> getPhotosForAI() => 
      getAllPhotos().where((p) => !p.isPrivate).toList();

  /// Get photos linked to a journal entry
  List<PhotoEntry> getPhotosForJournal(String journalId) =>
      getAllPhotos().where((p) => p.linkedJournalId == journalId).toList();

  /// Get recent photos
  List<PhotoEntry> getRecentPhotos({int limit = 20}) {
    final photos = getAllPhotos();
    photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return photos.take(limit).toList();
  }

  // ============================================
  // PRIVACY MANAGEMENT
  // ============================================

  /// Mark a photo as private (copies to encrypted storage)
  Future<void> markAsPrivate(String id) async {
    final entry = _photoBox?.get(id);
    if (entry == null || entry.isPrivate) return;

    try {
      // Copy photo data to encrypted storage
      final file = File(entry.originalPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        await _privateDataBox?.put(id, bytes);
      }

      // Update entry
      entry.isPrivate = true;
      entry.privatePath = 'encrypted:$id';
      entry.aiDescription = null; // Clear AI description for privacy
      await entry.save();
      
      debugPrint('🔒 Photo marked as private: $id');
    } catch (e) {
      debugPrint('❌ Error marking photo private: $e');
    }
  }

  /// Mark a photo as public (removes from encrypted storage)
  Future<void> markAsPublic(String id) async {
    final entry = _photoBox?.get(id);
    if (entry == null || !entry.isPrivate) return;

    try {
      // Remove from encrypted storage
      await _privateDataBox?.delete(id);

      // Update entry
      entry.isPrivate = false;
      entry.privatePath = null;
      await entry.save();
      
      debugPrint('🔓 Photo marked as public: $id');
    } catch (e) {
      debugPrint('❌ Error marking photo public: $e');
    }
  }

  /// Get encrypted photo bytes (for private photos)
  Uint8List? getPrivatePhotoBytes(String id) => _privateDataBox?.get(id);

  // ============================================
  // DELETE & CLEANUP
  // ============================================

  /// Delete a photo
  Future<void> deletePhoto(String id) async {
    final entry = _photoBox?.get(id);
    if (entry == null) return;

    try {
      // Delete from encrypted storage if private
      if (entry.isPrivate) {
        await _privateDataBox?.delete(id);
      }

      // Delete thumbnail
      if (entry.thumbnailPath != null) {
        try {
          await File(entry.thumbnailPath!).delete();
        } catch (_) {}
      }

      // Remove from box
      await _photoBox?.delete(id);
      debugPrint('🗑️ Photo deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting photo: $e');
    }
  }

  /// Clear all photos
  Future<void> clearAll() async {
    await _photoBox?.clear();
    await _privateDataBox?.clear();
    
    // Clear thumbnails
    try {
      final dir = Directory(_thumbnailPath!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }
    } catch (_) {}
    
    debugPrint('🗑️ All photos cleared');
  }

  // ============================================
  // HELPERS
  // ============================================

  Future<String?> _generateThumbnail(String sourcePath, String id) async {
    try {
      final thumbPath = '$_thumbnailPath/$id.jpg';
      
      // Read and decode image in isolate for performance
      final bytes = await File(sourcePath).readAsBytes();
      final thumbnail = await compute(_generateThumbnailIsolate, {
        'bytes': bytes,
        'path': thumbPath,
      });
      
      if (thumbnail != null) {
        await File(thumbPath).writeAsBytes(thumbnail);
        debugPrint('📷 Thumbnail generated: $thumbPath');
        return thumbPath;
      }
      
      return null;
    } catch (e) {
      debugPrint('⚠️ Thumbnail generation failed: $e');
      return null;
    }
  }
  
  /// Generate thumbnail in isolate to avoid blocking UI
  static Uint8List? _generateThumbnailIsolate(Map<String, dynamic> params) {
    try {
      final bytes = params['bytes'] as Uint8List;
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      // Resize to 300px width, maintaining aspect ratio
      const thumbnailWidth = 300;
      final thumbnail = img.copyResize(
        image,
        width: thumbnailWidth,
        interpolation: img.Interpolation.linear,
      );
      
      // Encode as JPEG with quality 85
      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 85));
    } catch (e) {
      return null;
    }
  }
  
  /// Extract EXIF metadata from photo
  /// Note: Uses simplified extraction compatible with current image package
  Future<Map<String, dynamic>> _extractExifData(File file) async {
    final result = <String, dynamic>{};
    
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return result;
      
      // Try to extract EXIF data if available
      // Wrap in try/catch since EXIF may not be present
      try {
        final exif = image.exif;
        
        // Get EXIF IFD data
        final exifIfd = exif.exifIfd;
        
        // DateTimeOriginal is tag 0x9003
        final dateTimeOriginal = exifIfd[0x9003];
        if (dateTimeOriginal != null) {
          try {
            // EXIF date format: "YYYY:MM:DD HH:MM:SS"
            final dateStr = dateTimeOriginal.toString();
            final parts = dateStr.split(' ');
            if (parts.length >= 2) {
              final dateParts = parts[0].split(':');
              final timeParts = parts[1].split(':');
              if (dateParts.length >= 3 && timeParts.length >= 3) {
                result['dateTime'] = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                  int.parse(timeParts[0]),
                  int.parse(timeParts[1]),
                  int.parse(timeParts[2].split('.')[0]),
                );
              }
            }
          } catch (_) {}
        }
        
        // Get IFD0 for camera info
        final ifd0 = exif.imageIfd;
        
        // Make is tag 0x010F, Model is tag 0x0110
        final make = ifd0[0x010F];
        final model = ifd0[0x0110];
        if (make != null || model != null) {
          result['camera'] = '${make ?? ''} ${model ?? ''}'.trim();
        }
        
        // GPS data - simplified approach
        final gpsIfd = exif.gpsIfd;
        // GPSLatitudeRef is 0x0001, GPSLatitude is 0x0002
        // GPSLongitudeRef is 0x0003, GPSLongitude is 0x0004
        final lat = gpsIfd[0x0002];
        final lon = gpsIfd[0x0004];
        
        if (lat != null && lon != null) {
          result['location'] = 'GPS data available';
        }
      } catch (exifError) {
        // EXIF data not available or parsing failed - this is expected for some images
        debugPrint('📷 No EXIF data or parse failed: $exifError');
      }
    } catch (e) {
      debugPrint('⚠️ EXIF extraction error: $e');
    }
    
    return result;
  }

  /// Update photo caption
  Future<void> updateCaption(String id, String caption) async {
    final entry = _photoBox?.get(id);
    if (entry != null) {
      entry.caption = caption;
      await entry.save();
    }
  }

  /// Update AI description (only for non-private photos)
  Future<void> updateAIDescription(String id, String description) async {
    final entry = _photoBox?.get(id);
    if (entry != null && !entry.isPrivate) {
      entry.aiDescription = description;
      await entry.save();
    }
  }

  /// Link photo to journal entry
  Future<void> linkToJournal(String photoId, String journalId) async {
    final entry = _photoBox?.get(photoId);
    if (entry != null) {
      entry.linkedJournalId = journalId;
      await entry.save();
    }
  }

  // Stats
  int get totalPhotos => _photoBox?.length ?? 0;
  int get privatePhotos => getAllPhotos().where((p) => p.isPrivate).length;
  int get publicPhotos => totalPhotos - privatePhotos;
}
