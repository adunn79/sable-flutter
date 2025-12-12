import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// Service for handling device photos integration
/// Provides permission management, photo browsing, and AI context
class PhotosService {
  /// Request photos permission from the user
  static Future<bool> requestPermission() async {
    try {
      final result = await PhotoManager.requestPermissionExtend();
      debugPrint('📸 Photos permission granted: ${result.isAuth}');
      return result.isAuth;
    } catch (e) {
      debugPrint('❌ Photos permission request failed: $e');
      return false;
    }
  }
  
  /// Check if photos permission has been granted
  static Future<bool> hasPermission() async {
    try {
      final result = await PhotoManager.requestPermissionExtend();
      return result.isAuth;
    } catch (e) {
      debugPrint('❌ Photos permission check failed: $e');
      return false;
    }
  }
  
  /// Get recent photos (limited count)
  static Future<List<AssetEntity>> getRecentPhotos({int count = 20}) async {
    try {
      if (!await hasPermission()) {
        debugPrint('⚠️ No photos permission');
        return [];
      }
      
      // Get recent album (Camera Roll)
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      
      if (albums.isEmpty) return [];
      
      final recentAlbum = albums.first;
      final photos = await recentAlbum.getAssetListRange(
        start: 0,
        end: count,
      );
      
      debugPrint('📷 Retrieved ${photos.length} recent photos');
      return photos;
    } catch (e) {
      debugPrint('❌ Failed to get recent photos: $e');
      return [];
    }
  }
  
  /// Get photo count
  static Future<int> getPhotoCount() async {
    try {
      if (!await hasPermission()) return 0;
      
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      
      if (albums.isEmpty) return 0;
      
      final count = await albums.first.assetCountAsync;
      return count;
    } catch (e) {
      debugPrint('❌ Failed to get photo count: $e');
      return 0;
    }
  }
  
  /// Get photos from a specific date range
  static Future<List<AssetEntity>> getPhotosInDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      if (!await hasPermission()) return [];
      
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      
      if (albums.isEmpty) return [];
      
      final recentAlbum = albums.first;
      final allPhotos = await recentAlbum.getAssetListRange(
        start: 0,
        end: 1000, // Adjust as needed
      );
      
      // Filter by date range
      final filtered = allPhotos.where((photo) {
        final createDate = photo.createDateTime;
        return createDate.isAfter(start) && createDate.isBefore(end);
      }).toList();
      
      debugPrint('📅 Found ${filtered.length} photos in date range');
      return filtered;
    } catch (e) {
      debugPrint('❌ Failed to get photos in date range: $e');
      return [];
    }
  }
  
  /// Get formatted photos summary for AI context
  static Future<String> getPhotosSummary() async {
    try {
      if (!await hasPermission()) {
        return '[PHOTOS]\nNo photos access granted.\n[END PHOTOS]';
      }
      
      final photoCount = await getPhotoCount();
      final recentPhotos = await getRecentPhotos(count: 5);
      
      final buffer = StringBuffer();
      buffer.writeln('[PHOTOS]');
      buffer.writeln('Total photos: $photoCount');
      
      if (recentPhotos.isNotEmpty) {
        buffer.writeln('\nMost recent:');
        for (final photo in recentPhotos) {
          final date = photo.createDateTime;
          final dateStr = '${date.month}/${date.day}/${date.year}';
          buffer.writeln('- Photo from $dateStr');
        }
      }
      
      buffer.writeln('[END PHOTOS]');
      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Failed to generate photos summary: $e');
      return '[PHOTOS]\nError loading photos data.\n[END PHOTOS]';
    }
  }
  
  /// Get photo as bytes (for potential AI vision analysis in future)
  static Future<Uint8List?> getPhotoBytes(AssetEntity photo, {int quality = 80}) async {
    try {
      final bytes = await photo.originBytes;
      return bytes;
    } catch (e) {
      debugPrint('❌ Failed to get photo bytes: $e');
      return null;
    }
  }
}
