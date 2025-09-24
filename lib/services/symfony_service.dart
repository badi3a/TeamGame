import 'dart:convert';
import 'package:http/http.dart' as http;

class SymfonyService {
  // Symfony backend URL - only for badge operations
  static const String baseUrl = 'http://127.0.0.1:8001/api';
  
  // Headers for all requests
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ========== BADGE SYSTEM METHODS ONLY ==========

  /// Save badges earned by a user for a specific category
  static Future<bool> saveBadges({
    required String userId,
    required List<Map<String, dynamic>> badges,
    required String categoryId,
    required double score,
    String? quizId,
  }) async {
    try {
      print('🏆 SymfonyService: Saving ${badges.length} badges for user $userId, category $categoryId');
      
      final requestBody = {
        'userId': userId,
        'badges': badges,
        'categoryId': categoryId,
        'score': score,
      };
      
      if (quizId != null) {
        requestBody['quizId'] = quizId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/badges/save'),
        headers: defaultHeaders,
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📡 SymfonyService: Save badges response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        bool success = data['success'] == true;
        print('✅ SymfonyService: Badge saving result: $success');
        if (success) {
          print('🎉 SymfonyService: Saved ${data['badgeCount']} badges successfully');
        }
        return success;
      } else {
        print('❌ SymfonyService: Save badges failed with status: ${response.statusCode}');
        final errorData = json.decode(response.body);
        print('❌ SymfonyService: Error details: ${errorData['error']}');
        return false;
      }
    } catch (e) {
      print('❌ SymfonyService: Error saving badges: $e');
      return false;
    }
  }

  /// Get all badges earned by a user
  static Future<List<Map<String, dynamic>>?> getUserBadges(String userId) async {
    try {
      print('🌐 SymfonyService: Getting badges for user $userId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/badges/user/$userId'),
        headers: defaultHeaders,
      ).timeout(const Duration(seconds: 30));

      print('📡 SymfonyService: Get user badges response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<Map<String, dynamic>> badges = List<Map<String, dynamic>>.from(data['badges']);
          print('✅ SymfonyService: Loaded ${badges.length} badge records for user');
          return badges;
        } else {
          throw Exception(data['error'] ?? 'Failed to get user badges');
        }
      } else if (response.statusCode == 404) {
        print('ℹ️ SymfonyService: No badges found for user $userId');
        return [];
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ SymfonyService: Error getting user badges: $e');
      return null;
    }
  }

  /// Get badges for a specific category
  static Future<Map<String, dynamic>?> getCategoryBadges(String userId, String categoryId) async {
    try {
      print('🌐 SymfonyService: Getting badges for user $userId, category $categoryId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/badges/user/$userId/category/$categoryId'),
        headers: defaultHeaders,
      ).timeout(const Duration(seconds: 30));

      print('📡 SymfonyService: Get category badges response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ SymfonyService: Loaded badges for category $categoryId');
          return data['badges'];
        } else {
          throw Exception(data['error'] ?? 'Failed to get category badges');
        }
      } else if (response.statusCode == 404) {
        print('ℹ️ SymfonyService: No badges found for category $categoryId');
        return null;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ SymfonyService: Error getting category badges: $e');
      return null;
    }
  }

  /// Get badge statistics for a user
  static Future<Map<String, dynamic>?> getBadgeStatistics(String userId) async {
    try {
      print('🌐 SymfonyService: Getting badge statistics for user $userId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/badges/user/$userId/stats'),
        headers: defaultHeaders,
      ).timeout(const Duration(seconds: 30));

      print('📡 SymfonyService: Get badge stats response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ SymfonyService: Loaded badge statistics');
          return data['stats'];
        } else {
          throw Exception(data['error'] ?? 'Failed to get badge statistics');
        }
      } else if (response.statusCode == 404) {
        print('ℹ️ SymfonyService: No badge statistics found for user $userId');
        return null;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ SymfonyService: Error getting badge statistics: $e');
      return null;
    }
  }

  /// Update badges for a category (admin function)
  static Future<bool> updateCategoryBadges({
    required String userId,
    required String categoryId,
    required List<Map<String, dynamic>> badges,
  }) async {
    try {
      print('🌐 SymfonyService: Updating badges for user $userId, category $categoryId');
      
      final response = await http.put(
        Uri.parse('$baseUrl/badges/update'),
        headers: defaultHeaders,
        body: json.encode({
          'userId': userId,
          'categoryId': categoryId,
          'badges': badges,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📡 SymfonyService: Update badges response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        bool success = data['success'] == true;
        print('✅ SymfonyService: Badge update result: $success');
        return success;
      } else {
        print('❌ SymfonyService: Update badges failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ SymfonyService: Error updating badges: $e');
      return false;
    }
  }

  /// Delete badges for a category (admin function)
  static Future<bool> deleteCategoryBadges(String userId, String categoryId) async {
    try {
      print('🌐 SymfonyService: Deleting badges for user $userId, category $categoryId');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/badges/user/$userId/category/$categoryId'),
        headers: defaultHeaders,
      ).timeout(const Duration(seconds: 30));

      print('📡 SymfonyService: Delete badges response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        bool success = data['success'] == true;
        print('✅ SymfonyService: Badge deletion result: $success');
        return success;
      } else {
        print('❌ SymfonyService: Delete badges failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ SymfonyService: Error deleting badges: $e');
      return false;
    }
  }

  // ========== UTILITY METHODS FOR BADGES ==========

  /// Convert Flutter badge objects to API format
  static List<Map<String, dynamic>> convertBadgesToApiFormat(List<dynamic> badges) {
    return badges.map((badge) {
      return {
        'name': badge.name,
        'icon': badge.icon,
        'description': badge.description,
        'color': getColorHex(badge.color),
      };
    }).toList();
  }

  /// Helper method to get badge color from hex string
  static String getColorHex(dynamic color) {
    if (color == null) return '#000000';
    
    // If it's already a string, return it
    if (color is String) return color;
    
    // If it's a Color object, convert to hex
    try {
      return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    } catch (e) {
      return '#000000';
    }
  }

  /// Validate badge data before sending
  static bool validateBadgeData({
    required String userId,
    required List<Map<String, dynamic>> badges,
    required String categoryId,
    required double score,
  }) {
    if (userId.isEmpty) {
      print('❌ SymfonyService: Invalid userId for badge validation');
      return false;
    }
    
    if (categoryId.isEmpty) {
      print('❌ SymfonyService: Invalid categoryId for badge validation');
      return false;
    }
    
    if (score < 0.0 || score > 5.0) {
      print('❌ SymfonyService: Invalid score for badge validation: $score');
      return false;
    }
    
    for (var badge in badges) {
      if (!badge.containsKey('name') || 
          !badge.containsKey('icon') || 
          !badge.containsKey('description')) {
        print('❌ SymfonyService: Invalid badge structure: $badge');
        return false;
      }
    }
    
    print('✅ SymfonyService: Badge data validation passed');
    return true;
  }

  /// Batch save badges for multiple categories (utility method)
  static Future<Map<String, bool>> saveBadgesForMultipleCategories({
    required String userId,
    required Map<String, List<Map<String, dynamic>>> categoriesWithBadges,
    required Map<String, double> categoryScores,
    String? quizId,
  }) async {
    Map<String, bool> results = {};
    
    for (String categoryId in categoriesWithBadges.keys) {
      final badges = categoriesWithBadges[categoryId] ?? [];
      final score = categoryScores[categoryId] ?? 0.0;
      
      try {
        final success = await saveBadges(
          userId: userId,
          badges: badges,
          categoryId: categoryId,
          score: score,
          quizId: quizId,
        );
        results[categoryId] = success;
        
        if (success) {
          print('✅ SymfonyService: Successfully saved badges for category $categoryId');
        } else {
          print('❌ SymfonyService: Failed to save badges for category $categoryId');
        }
        
        // Add small delay between requests to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 200));
        
      } catch (e) {
        print('❌ SymfonyService: Error saving badges for category $categoryId: $e');
        results[categoryId] = false;
      }
    }
    
    return results;
  }

  /// Get badges summary for dashboard/profile views
  static Future<Map<String, dynamic>?> getBadgesSummary(String userId) async {
    try {
      final badges = await getUserBadges(userId);
      final stats = await getBadgeStatistics(userId);
      
      if (badges == null || stats == null) {
        return null;
      }
      
      return {
        'badges': badges,
        'statistics': stats,
        'summary': {
          'totalBadges': stats['totalBadges'] ?? 0,
          'totalCategories': stats['totalCategories'] ?? 0,
          'averageScore': stats['averageScore'] ?? 0.0,
          'highestScore': stats['highestScore'] ?? 0.0,
        }
      };
    } catch (e) {
      print('❌ SymfonyService: Error getting badges summary: $e');
      return null;
    }
  }

  /// Check Symfony server connection
  static Future<bool> checkConnection() async {
    try {
      print('🌐 SymfonyService: Checking Symfony server connection...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/badges/health'),
        headers: defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      bool isConnected = response.statusCode == 200;
      print('📡 SymfonyService: Symfony server connection: ${isConnected ? "✅ Connected" : "❌ Failed"}');
      
      return isConnected;
    } catch (e) {
      print('❌ SymfonyService: Symfony connection error: $e');
      return false;
    }
  }

  /// Retry mechanism for failed badge requests
  static Future<T?> retryRequest<T>(
    Future<T> Function() request, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await request();
      } catch (e) {
        print('❌ SymfonyService: Badge request attempt $attempt failed: $e');
        
        if (attempt == maxRetries) {
          print('❌ SymfonyService: All badge retry attempts failed');
          rethrow;
        }
        
        await Future.delayed(delay * attempt);
      }
    }
    return null;
  }

  /// Sync local badges with Symfony server (for offline support)
  static Future<bool> syncLocalBadges(List<Map<String, dynamic>> localBadges) async {
    try {
      print('🔄 SymfonyService: Syncing ${localBadges.length} local badges with Symfony server');
      
      int successCount = 0;
      int failureCount = 0;
      
      for (var badgeRecord in localBadges) {
        try {
          final success = await saveBadges(
            userId: badgeRecord['userId'],
            badges: List<Map<String, dynamic>>.from(badgeRecord['badges']),
            categoryId: badgeRecord['categoryId'],
            score: badgeRecord['score'].toDouble(),
            quizId: badgeRecord['quizId'],
          );
          
          if (success) {
            successCount++;
          } else {
            failureCount++;
          }
          
          // Small delay between syncs
          await Future.delayed(const Duration(milliseconds: 300));
          
        } catch (e) {
          print('❌ SymfonyService: Failed to sync badge record: $e');
          failureCount++;
        }
      }
      
      print('✅ SymfonyService: Badge sync complete - Success: $successCount, Failed: $failureCount');
      return failureCount == 0;
      
    } catch (e) {
      print('❌ SymfonyService: Error syncing local badges: $e');
      return false;
    }
  }
}