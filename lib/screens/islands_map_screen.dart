import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:csv/csv.dart'; // Added for CSV operations
import 'package:flutter/foundation.dart'; // Added to detect web platform
import 'package:intl/intl.dart'; // Add this for date formatting
// Web-specific import (only used when kIsWeb is true)
import 'dart:html' as html;

// UPDATED: Import Python Group Service instead of Symfony service
import '../services/python_group_service.dart';

// Import the shared model
import 'quiz_island.dart';
import '../services/api_service.dart';

import 'badge_system.dart'; // If badge_system.dart is in the same folder as islands_map_screen.dart

// Import the quiz screens
import 'category1_quiz_screen.dart';
import 'category2_quiz_screen.dart';
import 'category3_quiz_screen.dart';
import 'category4_quiz_screen.dart';

// Import avatar service
import '../services/firebase_avatar_service.dart';

// UPDATED: CollectiveCSVManager with user_id support
class CollectiveCSVManager {
  static const String _completedUsersKey = 'completed_users_data';
  static const String _completionCounterKey = 'completion_counter';
  static const int _batchSize = 12; // Trigger download after 12 users

  // Add a completed user to the collective data
  static Future<void> addCompletedUser(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      print('📊 ===============================');
      print('📊 ADDING USER TO COLLECTIVE CSV DATA');
      print('📊 ===============================');
      print('📊 User ID: ${userData['user_id']}');
      print('📊 User: ${userData['first_name']} ${userData['last_name']}');
      print('📊 Class: ${userData['class']}');
      print('📊 Scores: Hard=${userData['hard_skills']}, Soft=${userData['soft_skills']}, Team=${userData['teamwork']}, Creative=${userData['creativity']}');
      
      // Get existing completed users data
      final existingDataJson = prefs.getStringList(_completedUsersKey) ?? [];
      final List<Map<String, dynamic>> existingData = existingDataJson
          .map((jsonStr) => Map<String, dynamic>.from(json.decode(jsonStr)))
          .toList();
      
      // Add new user data
      existingData.add(userData);
      
      // Save updated data
      final updatedDataJson = existingData
          .map((data) => json.encode(data))
          .toList();
      await prefs.setStringList(_completedUsersKey, updatedDataJson);
      
      // Update counter
      final currentCount = prefs.getInt(_completionCounterKey) ?? 0;
      final newCount = currentCount + 1;
      await prefs.setInt(_completionCounterKey, newCount);
      
      print('📊 User added to collective data');
      print('📊 Total users in batch: $newCount/$_batchSize');
      print('📊 ===============================');
      
    } catch (e) {
      print('❌ Error adding user to collective data: $e');
    }
  }

  // Check if we should trigger batch download
  static Future<bool> shouldTriggerBatchDownload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_completionCounterKey) ?? 0;
      
      print('🎯 Checking batch download trigger: $currentCount/$_batchSize');
      return currentCount >= _batchSize;
    } catch (e) {
      print('❌ Error checking batch trigger: $e');
      return false;
    }
  }

  // Get current completion count
  static Future<int> getCurrentCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_completionCounterKey) ?? 0;
    } catch (e) {
      print('❌ Error getting current count: $e');
      return 0;
    }
  }

  // UPDATED: Generate and download collective CSV with user_id as first column
  static Future<void> generateCollectiveCSV() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      print('📊 ===============================');
      print('📊 GENERATING COLLECTIVE CSV WITH USER IDS');
      print('📊 ===============================');
      
      // Get all completed users data
      final completedDataJson = prefs.getStringList(_completedUsersKey) ?? [];
      final List<Map<String, dynamic>> completedUsers = completedDataJson
          .map((jsonStr) => Map<String, dynamic>.from(json.decode(jsonStr)))
          .toList();
      
      print('📊 Total users to include in CSV: ${completedUsers.length}');
      
      if (completedUsers.isEmpty) {
        print('⚠️ No completed users found for CSV generation');
        return;
      }
      
      // UPDATED: Prepare CSV data with user_id as first column
      List<List<dynamic>> csvData = [
        // Header row with user_id as first column (matching backend expectation)
        ['user_id', 'first_name', 'last_name', 'gender', 'age', 'nationality', 'hard_skills', 'soft_skills', 'teamwork', 'creativity', 'class'],
      ];
      
      // Add each user's data as a row
      for (int i = 0; i < completedUsers.length; i++) {
        final user = completedUsers[i];
        final row = [
          user['user_id']?.toString().trim() ?? 'unknown_user_${i+1}', // USER_ID FIRST
          user['first_name']?.toString().trim() ?? 'Unknown',
          user['last_name']?.toString().trim() ?? 'User',
          user['gender']?.toString().trim() ?? 'Not specified',
          user['age']?.toString().trim() ?? '0',
          user['nationality']?.toString().trim() ?? 'Not specified',
          user['hard_skills']?.toString() ?? '0.00',
          user['soft_skills']?.toString() ?? '0.00',
          user['teamwork']?.toString() ?? '0.00',
          user['creativity']?.toString() ?? '0.00',
          user['class']?.toString().trim() ?? 'Not specified',
        ];
        csvData.add(row);
        
        print('📊 Added user ${i + 1}: [${row[0]}] ${row[1]} ${row[2]} - Class: ${row[10]}');
      }
      
      print('📊 CSV structure prepared with ${csvData.length} rows (including header)');
      print('📊 CSV Header: ${csvData[0]}');
      
      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvData);
      
      print('📊 CSV string generated, length: ${csvString.length} characters');
      
      // Generate filename with timestamp and batch info
      final timestamp = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(timestamp);
      final filename = 'students_data_with_ids_batch_${completedUsers.length}_users_$formattedDate.csv';
      
      print('📊 Filename: $filename');
      
      if (kIsWeb) {
        await _downloadCSVForWeb(csvString, filename, completedUsers.length);
      } else {
        await _downloadCSVForNative(csvString, filename, completedUsers.length);
      }
      
      print('✅ ===============================');
      print('✅ COLLECTIVE CSV WITH USER IDS GENERATED');
      print('✅ ===============================');
      print('✅ Filename: $filename');
      print('✅ Total users: ${completedUsers.length}');
      print('✅ Format: user_id as first column for clustering');
      print('✅ ===============================');
      
    } catch (e) {
      print('❌ Error generating collective CSV: $e');
      throw e;
    }
  }

  // Reset the collective data after successful download
  static Future<void> resetCollectiveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      print('🔄 ===============================');
      print('🔄 RESETTING COLLECTIVE DATA');
      print('🔄 ===============================');
      
      // Clear completed users data
      await prefs.remove(_completedUsersKey);
      
      // Reset counter
      await prefs.remove(_completionCounterKey);
      
      print('✅ Collective data reset successfully');
      print('✅ Ready for next batch collection');
      print('🔄 ===============================');
      
    } catch (e) {
      print('❌ Error resetting collective data: $e');
    }
  }

  // Get preview of current batch data
  static Future<List<Map<String, dynamic>>> getCurrentBatchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedDataJson = prefs.getStringList(_completedUsersKey) ?? [];
      return completedDataJson
          .map((jsonStr) => Map<String, dynamic>.from(json.decode(jsonStr)))
          .toList();
    } catch (e) {
      print('❌ Error getting current batch data: $e');
      return [];
    }
  }

  // Download CSV for web platform
  static Future<void> _downloadCSVForWeb(String csvString, String filename, int userCount) async {
    try {
      print('🌐 ===============================');
      print('🌐 WEB COLLECTIVE CSV DOWNLOAD WITH USER IDS');
      print('🌐 ===============================');
      print('🌐 Filename: $filename');
      print('🌐 User count: $userCount');
      print('🌐 CSV length: ${csvString.length} characters');
      
      // Convert string to bytes
      final bytes = utf8.encode(csvString);
      
      // Create blob and download
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final anchor = html.AnchorElement(href: url)
        ..style.display = 'none'
        ..download = filename
        ..setAttribute('target', '_blank');
      
      html.document.body!.children.add(anchor);
      anchor.click();
      
      await Future.delayed(Duration(milliseconds: 100));
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
      
      print('✅ Web download completed successfully');
      
    } catch (e) {
      print('❌ Error in web CSV download: $e');
      throw e;
    }
  }

  // Download CSV for native platform
  static Future<void> _downloadCSVForNative(String csvString, String filename, int userCount) async {
    try {
      print('📱 Native platform collective CSV download');
      print('📱 This feature will be implemented for desktop/mobile in future updates');
      
      // Future implementation for native platforms
      throw Exception('Native platform download not yet implemented');
      
    } catch (e) {
      print('❌ Error in native CSV download: $e');
      throw e;
    }
  }

  // Clear old data (utility method for maintenance)
  static Future<void> clearOldData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_completedUsersKey);
      await prefs.remove(_completionCounterKey);
      print('✅ Old collective data cleared');
    } catch (e) {
      print('❌ Error clearing old data: $e');
    }
  }
}

// UPDATED: Enhanced data class for quiz completion results with quiz ID
class QuizCompletionResult {
  final String quizId;        // Add quiz ID to ensure proper isolation
  final String categoryId;
  final double categoryScore;
  final double totalScore;
  final int islandId;

  QuizCompletionResult({
    required this.quizId,      // Make quiz ID required
    required this.categoryId,
    required this.categoryScore,
    required this.totalScore,
    required this.islandId,
  });

  // Helper method to get the full category key for storage
  String get fullCategoryKey => '${quizId}_$categoryId';
  
  @override
  String toString() {
    return 'QuizCompletionResult(quizId: $quizId, categoryId: $categoryId, categoryScore: $categoryScore, totalScore: $totalScore, islandId: $islandId)';
  }
}

class IslandsMapScreen extends StatefulWidget {
  final Map<String, dynamic>? quizData;
  
  const IslandsMapScreen({Key? key, this.quizData}) : super(key: key);

  @override
  State<IslandsMapScreen> createState() => _IslandsMapScreenState();
}

class _IslandsMapScreenState extends State<IslandsMapScreen>
    with TickerProviderStateMixin {
  
  // Replace with your actual Symfony server URL
  static const String _baseUrl = 'http://127.0.0.1:8001'; // Change this to your server URL
  
  // UPDATED: Group members state to handle user IDs and detailed data from Python backend
  bool _isLoadingGroupMembers = false;
  bool _showGroupMembersPopup = false;
  List<Map<String, dynamic>> _groupMemberDetails = []; // Now contains full details including avatars from Python
  late PythonGroupService _pythonGroupService; // UPDATED: Python group service

  // Animation Controllers
  late AnimationController _waveController;
  late AnimationController _cloudController;
  late AnimationController _particleController;
  late AnimationController _islandController;
  late AnimationController _lightController;
  late AnimationController _rotationController;
  late AnimationController _scoreController;
  late AnimationController _transitionController; 
  late AnimationController _postQuizLoadingController;
  late AnimationController _avatarPulseController;
  late AnimationController _badgeCollectionController; // NEW: For badge collection animation
  
  // Animations
  late Animation<double> _waveAnimation;
  late Animation<double> _cloudAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _islandAnimation;
  late Animation<double> _lightAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scoreAnimation;
  late Animation<double> _transitionAnimation;
  late Animation<double> _postQuizLoadingAnimation;
  late Animation<double> _avatarPulseAnimation;
  late Animation<double> _badgeCollectionAnimation; // NEW: For badge collection animation
  
  // State
  int? _selectedIsland;
  bool _isLoadingData = true;
  bool _isRefreshing = false;
  bool _isPostQuizLoading = false;
  bool _showPostQuizLoadingImmediately = false;
  String _loadingMessage = 'Loading Islands...';
  String _postQuizLoadingMessage = 'Updating your progress...';
  String? _errorMessage;
  
  // Avatar-related state
  bool _isLoadingAvatar = true;
  AvatarData? _userAvatar;
  late FirebaseAvatarService _avatarService;
  
  // Avatar cache variables
  Uint8List? _cachedAvatarBytes;
  String? _lastProcessedAvatarData;
  
  // NEW: Badge collection state
  List<AchievementBadge> _allEarnedBadges = [];
  bool _isLoadingBadges = true;
  bool _showBadgeCollection = false;
  bool _showBadgePopup = false; // NEW: For badge popup visibility
  
  // NEW: Island position tracking
  String _currentIslandPosition = "island 1"; // Default to island 1
  
  // ADDED: Local score cache for immediate UI updates
  Map<String, double> _localScoreCache = {};
  
  // ADDED: Flag to track if CSV has been saved for this session
  bool _csvSavedThisSession = false;
  // Add this with your other state variables
  bool _isGroupAccessible = false;
  
  // GlobalKeys for precise positioning
  final Map<int, GlobalKey> _islandKeys = {};
  
  // Manual zoom centers for each island
  final Map<int, Offset?> _manualZoomCenters = {
    1: Offset(150, 250),
    2: Offset(280, 200),
    3: Offset(120, 450),
    4: Offset(300, 480),
  };

  final bool _useManualZoomCenters = true;

  // Island Data with progression
  List<QuizIsland> _islands = [];
  double _totalScore = 0.0;
  String? _userDocumentId;
  String? _quizId;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeIslandKeys();
    _initializeAvatarService();
    _initializePythonGroupService(); // UPDATED: Initialize Python group service
    _loadCompleteIslandData();
  }

  void _initializeAnimations() {
    // Wave animation for water effects
    _waveController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    
    _waveAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.linear,
    ));

    // Cloud animation
    _cloudController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
    
    _cloudAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _cloudController,
      curve: Curves.linear,
    ));

    // Particle animation for atmospheric effects
    _particleController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _particleAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.linear,
    ));

    // Island floating animation
    _islandController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    
    _islandAnimation = Tween<double>(
      begin: -1,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _islandController,
      curve: Curves.easeInOut,
    ));

    // Island rotation animation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    // Light animation for day/night cycle
    _lightController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat(reverse: true);
    
    _lightAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _lightController,
      curve: Curves.easeInOut,
    ));

    // Score floating animation
    _scoreController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _scoreAnimation = Tween<double>(
      begin: -3,
      end: 3,
    ).animate(CurvedAnimation(
      parent: _scoreController,
      curve: Curves.easeInOut,
    ));

    // Transition animation for smooth updates
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _transitionAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutBack,
    ));

    // Post-quiz loading animation
    _postQuizLoadingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _postQuizLoadingAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _postQuizLoadingController,
      curve: Curves.easeInOut,
    ));

    // Avatar pulse animation
    _avatarPulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _avatarPulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _avatarPulseController,
      curve: Curves.easeInOut,
    ));

    // NEW: Badge collection animation
    _badgeCollectionController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _badgeCollectionAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _badgeCollectionController,
      curve: Curves.easeOutBack,
    ));
  }

  // UPDATED: Initialize Python group service
  void _initializePythonGroupService() {
    try {
      // Try to find existing service first
      _pythonGroupService = Get.find<PythonGroupService>();
      print('✅ Found existing PythonGroupService');
    } catch (e) {
      // If not found, register it
      print('⚠️ PythonGroupService not found, registering new instance');
      _pythonGroupService = Get.put(PythonGroupService(), permanent: true);
      print('✅ PythonGroupService registered successfully');
    }
  }

  // UPDATED: Check if all islands are completed for group members feature
  bool _areAllIslandsCompletedForGroups() {
    print('🔍 Checking completion for group members feature...');
    
    bool atFinalIsland = _currentIslandPosition.contains('island 4');
    bool hasAllScores = _localScoreCache.length >= 4;
    int completedCount = _islands.where((island) => island.status == IslandStatus.completed).length;
    bool allIslandsCompleted = completedCount >= 4;
    
    print('🎯 Island position check: $atFinalIsland ($_currentIslandPosition)');
    print('🎯 Local scores check: $hasAllScores (${_localScoreCache.length}/4)');
    print('🎯 Islands status check: $allIslandsCompleted ($completedCount/4 completed)');
    
    bool isCompleted = atFinalIsland && hasAllScores && allIslandsCompleted;
    print('✅ All islands completed for groups: $isCompleted');
    
    return isCompleted;
  }

  // UPDATED: Load group members using the Python backend service
// UPDATED: Load group members using the Python backend service with enhanced user details
// Add this new method
Future<void> _checkGroupAccessibility() async {
  if (_userDocumentId == null) return;
  
  try {
    final isAccessible = await _pythonGroupService.isGroupAccessible(_userDocumentId!);
    setState(() {
      _isGroupAccessible = isAccessible;
    });
    print('🔓 Group accessibility updated: $_isGroupAccessible');
  } catch (e) {
    print('❌ Error checking group accessibility: $e');
    setState(() {
      _isGroupAccessible = false;
    });
  }
}
Future<void> _loadEnhancedGroupMembers() async {
  if (_userDocumentId == null) {
    print('⚠️ Cannot load group members: User ID not available');
    return;
  }

  try {
    setState(() {
      _isLoadingGroupMembers = true;
    });

    print('🔍 ===============================');
    print('🔍 LOADING GROUP MEMBERS WITH REAL USER DETAILS');
    print('🔍 ===============================');
    print('🔍 Current user ID: $_userDocumentId');

    // Test connection first (optional)
    final connectionOk = await _pythonGroupService.testConnection();
    if (!connectionOk) {
      throw Exception('Cannot connect to Python backend on port 8000');
    }
    print('✅ Connection to Python backend successful');

    // UPDATED: Get group members with avatars and REAL user details from Python backend
    final membersWithDetails = await _pythonGroupService.getGroupMembersWithAvatars(_userDocumentId!);
    
    print('📊 ===============================');
    print('📊 RECEIVED GROUP MEMBERS DATA');
    print('📊 ===============================');
    print('📊 Total members received: ${membersWithDetails.length}');
    
    // Debug each member's details
    for (int i = 0; i < membersWithDetails.length; i++) {
      final member = membersWithDetails[i];
      print('👤 Member ${i + 1}:');
      print('   - User ID: ${member['user_id']}');
      print('   - Firstname: "${member['firstname']}"');
      print('   - Lastname: "${member['lastname']}"');
      print('   - Full Name: "${member['full_name']}"');
      print('   - Has Avatar: ${member['has_avatar']}');
      print('   - Class: ${member['classe']}');
    }
    
    setState(() {
      _groupMemberDetails = membersWithDetails;
      _isLoadingGroupMembers = false;
      _showGroupMembersPopup = true;
    });

    if (membersWithDetails.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are not assigned to any group yet.'),
            backgroundColor: Colors.orange.shade600,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    print('✅ ===============================');
    print('✅ GROUP MEMBERS WITH REAL DETAILS LOADED SUCCESSFULLY');
    print('✅ All members now have real firstname and lastname from Firebase');
    print('✅ ===============================');

  } catch (e, stackTrace) {
    print('❌ Error loading enhanced group members: $e');
    print('❌ Stack trace: $stackTrace');
    
    setState(() {
      _isLoadingGroupMembers = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load group members with details. Please check your connection.'),
          backgroundColor: Colors.red.shade600,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

  // UPDATED: Build "Show My Group Members" button - positioned above View Badges
// UPDATED: Build button only if group is accessible (controlled by Angular frontend)
Widget _buildGroupMembersButton() {
  if (!_areAllIslandsCompletedForGroups() || 
      _isPostQuizLoading || 
      _showPostQuizLoadingImmediately ||
      !_isGroupAccessible) {  // Hide button if group is not accessible
    return Container();
  }

  return Positioned(
    bottom: MediaQuery.of(context).padding.bottom + 70,
    left: 20,
    child: AnimatedContainer(
      duration: Duration(milliseconds: 500),
      child: ElevatedButton.icon(
        onPressed: _isLoadingGroupMembers ? null : _loadEnhancedGroupMembers,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 8,
          shadowColor: Colors.deepPurple.withOpacity(0.4),
        ),
        icon: _isLoadingGroupMembers
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(Icons.group, size: 24),
        label: Text(
          _isLoadingGroupMembers ? 'Loading...' : 'Group Members',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}
  // UPDATED: Build enhanced group members popup with cleaner title
  Widget _buildEnhancedGroupMembersPopup() {
    if (!_showGroupMembersPopup) return Container();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.deepPurple.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.deepPurple.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade600,
                      Colors.deepPurple.shade400,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.group,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'My Group Members',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_groupMemberDetails.length}',
                        style: TextStyle(
                          color: Colors.deepPurple.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showGroupMembersPopup = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Members list with avatars
              Flexible(
                child: _groupMemberDetails.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No group members found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You might not be assigned to a group yet.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Group Members:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Grid view for members with avatars
                            Flexible(
                              child: GridView.builder(
                                shrinkWrap: true,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.0,
                                ),
                                itemCount: _groupMemberDetails.length,
                                itemBuilder: (context, index) {
                                  final memberDetail = _groupMemberDetails[index];
                                  return _buildEnhancedMemberCardWithRealNames(memberDetail);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              
              // Bottom padding
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED: Build enhanced member card with bigger avatars and cleaner display

Widget _buildEnhancedMemberCardWithRealNames(Map<String, dynamic> memberDetail) {
  final userId = memberDetail['user_id'] as String;
  final firstname = memberDetail['firstname'] as String? ?? 'Unknown';
  final lastname = memberDetail['lastname'] as String? ?? 'User';
  final hasAvatar = memberDetail['has_avatar'] == true;
  final avatarData = memberDetail['avatar_data'];
  
  print('🎨 Building card for: $firstname $lastname (ID: $userId) - Avatar: $hasAvatar');
  
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.deepPurple.shade50,
          Colors.white,
        ],
      ),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: Colors.deepPurple.shade200,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.deepPurple.withOpacity(0.1),
          blurRadius: 8,
          spreadRadius: 1,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Avatar
        _buildMemberAvatar(avatarData, hasAvatar, 80),
        const SizedBox(height: 12),
        // Display REAL firstname and lastname from Firebase
        Text(
          '$firstname $lastname',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple.shade800,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}
  // NEW: Build member avatar with improved handling
  Widget _buildMemberAvatar(dynamic avatarData, bool hasAvatar, double size) {
    try {
      if (!hasAvatar || avatarData == null || avatarData['image_avatar'] == null) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.deepPurple.shade100,
            border: Border.all(color: Colors.deepPurple.shade300, width: 2),
          ),
          child: Icon(
            Icons.person,
            size: size * 0.5,
            color: Colors.deepPurple.shade600,
          ),
        );
      }

      String imageData = avatarData['image_avatar'] as String;
      
      // Remove data URL prefix if present
      if (imageData.contains(',')) {
        imageData = imageData.split(',').last;
      }
      
      final avatarBytes = base64Decode(imageData);
      
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.2),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.memory(
            avatarBytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.red.shade100,
                child: Icon(
                  Icons.error,
                  size: size * 0.5,
                  color: Colors.red,
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      print('❌ Error building member avatar: $e');
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.shade100,
        ),
        child: Icon(
          Icons.error,
          size: size * 0.5,
          color: Colors.red,
        ),
      );
    }
  }

  // UPDATED: Debug method for testing Python group functionality
// UPDATED: Enhanced debug method for testing Python group functionality with user details
Future<void> _debugPythonGroupMembers() async {
  try {
    if (_userDocumentId == null) {
      print('⚠️ DEBUG: No user document ID available');
      return;
    }
    
    print('🔍 ===============================');
    print('🔍 DEBUG: PYTHON GROUP MEMBERS WITH REAL USER DETAILS TEST');
    print('🔍 ===============================');
    print('🔍 User Document ID: $_userDocumentId');
    
    // Test connection
    final connectionOk = await _pythonGroupService.testConnection();
    print('🔗 Connection test: ${connectionOk ? "SUCCESS" : "FAILED"}');
    
    if (!connectionOk) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Cannot connect to Python backend on port 8000'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Run complete debug flow
    await _pythonGroupService.debugCompleteGroupUserFlow(_userDocumentId!);
    
    // Test the full loading flow
    await _loadEnhancedGroupMembers();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ DEBUG: Complete Python backend test completed - check console for details'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
    
  } catch (e) {
    print('❌ DEBUG Error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ DEBUG Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  // NEW: Debug button for Python group functionality
  Widget _buildEnhancedDebugButton() {
    // Only show in development mode
    if (kReleaseMode) return Container();
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 100,
      right: 20,
      child: FloatingActionButton(
        onPressed: _debugPythonGroupMembers, // UPDATED: Use Python debug method
        backgroundColor: Colors.orange,
        child: Icon(Icons.group_work, color: Colors.white),
        mini: true,
      ),
    );
  }

  // Initialize avatar service
  void _initializeAvatarService() {
    try {
      // Try to find existing service first
      _avatarService = Get.find<FirebaseAvatarService>();
      print('✅ Found existing FirebaseAvatarService');
    } catch (e) {
      // If not found, register it
      print('⚠️ FirebaseAvatarService not found, registering new instance');
      _avatarService = Get.put(FirebaseAvatarService(), permanent: true);
      print('✅ FirebaseAvatarService registered successfully');
    }
  }

  // UPDATED: Save completed category to local storage and score cache
  Future<void> _saveCompletedCategoryToLocal(String categoryId, {double? categoryScore}) async {
    if (_quizId == null || _userDocumentId == null) {
      print('⚠️ Cannot save completion: Quiz ID or User ID not available');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userSpecificKey = _getUserSpecificKey('completed_categories');
      List<String> completedCategories = prefs.getStringList(userSpecificKey) ?? [];
      
      // Create the quiz-specific category key
      final categoryKey = '${_quizId}_$categoryId';
      
      // Add if not already present
      if (!completedCategories.contains(categoryKey)) {
        completedCategories.add(categoryKey);
        await prefs.setStringList(userSpecificKey, completedCategories);
        print('✅ Saved completed category to local: $categoryKey');
      } else {
        print('ℹ️ Category already marked as completed: $categoryKey');
      }
      
      // ADDED: Cache the score locally for immediate UI updates
      if (categoryScore != null) {
        _localScoreCache[categoryKey] = categoryScore;
        print('✅ Cached score locally: $categoryKey = $categoryScore');
      }
      
      // Debug the isolation
      await _debugAfterOperation('category completion save');
    } catch (e) {
      print('❌ Error saving completed category to local: $e');
    }
  }

  // ADDED: Get cached score for a category
  double? _getCachedScore(String categoryId) {
    final categoryKey = '${_quizId}_$categoryId';
    return _localScoreCache[categoryKey];
  }

  // UPDATED: Check if all islands are completed with better logging
  bool _areAllIslandsCompleted() {
    print('🔍 Checking if all islands are completed...');
    print('📊 Total islands: ${_islands.length}');
    
    if (_islands.length != 4) {
      print('❌ Not all 4 islands are loaded');
      return false;
    }
    
    int completedCount = 0;
    for (final island in _islands) {
      print('🏝️ Island ${island.id}: Status = ${island.status}, Score = ${island.categoryScore}');
      if (island.status == IslandStatus.completed) {
        completedCount++;
      }
    }
    
    print('📈 Completed islands: $completedCount/4');
    final allCompleted = completedCount == 4;
    print('✅ All islands completed: $allCompleted');
    
    return allCompleted;
  }

  // UPDATED: Alternative check using island position and scores
  bool _areAllIslandsCompletedAlternative() {
    print('🔍 Alternative check - Current island position: $_currentIslandPosition');
    print('💾 Local score cache size: ${_localScoreCache.length}');
    
    // Check if we're at island 4 and have all 4 scores
    bool atIsland4 = _currentIslandPosition.contains('island 4');
    bool hasAllScores = _localScoreCache.length >= 4;
    
    print('🎯 At island 4: $atIsland4');
    print('📊 Has all scores: $hasAllScores');
    
    return atIsland4 && hasAllScores;
  }

  // NEW: Fetch user profile data from API with better error handling
String? _calculateAgeFromDOB(String? dobString) {
  print('🎂 Calculating age from DOB: "$dobString"');
  
  if (dobString == null || dobString.isEmpty) {
    print('🎂 DOB is null or empty, returning null');
    return null;
  }
  
  try {
    final dob = DateTime.parse(dobString);
    final now = DateTime.now();
    print('🎂 Parsed DOB: $dob');
    print('🎂 Current date: $now');
    
    int age = now.year - dob.year;
    print('🎂 Initial age calculation: $age');
    
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age = age - 1;
      print('🎂 Adjusted age (birthday not yet this year): $age');
    }
    
    print('🎂 Final calculated age: $age');
    return age.toString();
  } catch (e) {
    print('⚠️ Error calculating age from DOB "$dobString": $e');
    return null;
  }
}

// UPDATED: Fetch user profile data with proper user_id inclusion
Future<Map<String, dynamic>?> _fetchUserProfileData() async {
  if (_userDocumentId == null) {
    print('⚠️ Cannot fetch user profile: User ID not available');
    return null;
  }

  try {
    print('🔄 ===============================');
    print('🔄 FETCHING USER PROFILE DATA WITH USER ID');
    print('🔄 ===============================');
    print('🔄 User Document ID: $_userDocumentId');
    print('🔄 API URL: $_baseUrl/api/auth/user-profile/$_userDocumentId');
    
    final response = await http.get(
      Uri.parse('$_baseUrl/api/auth/user-profile/$_userDocumentId'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(Duration(seconds: 10)); // Add timeout

    print('📡 API Response Status: ${response.statusCode}');
    print('📡 API Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      final userData = json.decode(response.body);
      print('✅ User profile data fetched successfully');
      print('📊 ===============================');
      print('📊 RAW USER DATA FROM API');
      print('📊 ===============================');
      
      // Print all raw data fields with their values
      userData.forEach((key, value) {
        print('📊 Raw field: "$key" = "${value.toString()}"');
        print('   - Type: ${value.runtimeType}');
        print('   - Is null: ${value == null}');
        print('   - Is empty: ${value is String ? value.isEmpty : false}');
      });
      
      print('📊 ===============================');
      print('📊 PROCESSING AND NORMALIZING DATA');
      print('📊 ===============================');
      
      // UPDATED: Create a normalized map with user_id included
      final normalizedData = {
        'user_id': _userDocumentId, // IMPORTANT: Include user_id for CSV
        'first_name': userData['firstname'] ?? 'Unknown',
        'last_name': userData['lastname'] ?? 'User', 
        'gender': userData['sexe'] ?? 'Not specified',
        'age': userData['age']?.toString() ?? 
               _calculateAgeFromDOB(userData['dateOfBirth']) ?? 
               '0',
        'nationality': userData['nationality'] ?? 'Not specified',
        'class': userData['classe'] ?? 'Not specified',
      };
      
      print('📊 ===============================');
      print('📊 NORMALIZED USER DATA FOR CSV WITH USER ID');
      print('📊 ===============================');
      normalizedData.forEach((key, value) {
        print('✅ Normalized "$key": "${value.toString()}"');
        print('   - Length: ${value.toString().length}');
        print('   - Trimmed: "${value.toString().trim()}"');
        print('   - After trim length: ${value.toString().trim().length}');
      });
      
      // Additional validation checks
      print('📊 ===============================');
      print('📊 DATA VALIDATION CHECKS');
      print('📊 ===============================');
      normalizedData.forEach((key, value) {
        final stringValue = value.toString().trim();
        if (stringValue.isEmpty || stringValue == 'null') {
          print('⚠️ WARNING: Field "$key" is empty or null!');
        } else {
          print('✅ Field "$key" validation passed');
        }
      });
      
      print('📊 ===============================');
      print('📊 USER PROFILE DATA WITH USER ID READY');
      print('📊 ===============================');
      
      return normalizedData;
    } else {
      print('❌ Failed to fetch user profile: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      return null;
    }
  } catch (e) {
    print('❌ Error fetching user profile: $e');
    return null;
  }
}

  // UPDATED: Save user data to collective CSV with proper user_id handling
Future<void> _saveUserDataToCollectiveCSV() async {
  try {
    // Fetch user profile data
    final userProfile = await _fetchUserProfileData();
    if (userProfile == null) {
      print('❌ Cannot save to collective CSV: User profile data not available');
      return;
    }

    // Map island scores to categories
    Map<String, double> scores = {
      'creativity': 0.0,    // Island 1
      'teamwork': 0.0,      // Island 2
      'hard_skills': 0.0,   // Island 3
      'soft_skills': 0.0,   // Island 4
    };

    // Process islands to get scores
    for (final island in _islands) {
      if (island.categoryScore != null) {
        switch (island.id) {
          case 1:
            scores['creativity'] = island.categoryScore!;
            break;
          case 2:
            scores['teamwork'] = island.categoryScore!;
            break;
          case 3:
            scores['hard_skills'] = island.categoryScore!;
            break;
          case 4:
            scores['soft_skills'] = island.categoryScore!;
            break;
        }
      } else {
        // Check cached scores
        final cachedScore = _getCachedScore(island.categoryId ?? '');
        if (cachedScore != null) {
          switch (island.id) {
            case 1:
              scores['creativity'] = cachedScore;
              break;
            case 2:
              scores['teamwork'] = cachedScore;
              break;
            case 3:
              scores['hard_skills'] = cachedScore;
              break;
            case 4:
              scores['soft_skills'] = cachedScore;
              break;
          }
        }
      }
    }

    // Validate all scores are available
    bool hasAllScores = scores.values.every((score) => score > 0);
    if (!hasAllScores) {
      print('❌ Not all scores available for collective CSV');
      return;
    }

    // UPDATED: Prepare user data for collective CSV with user_id
    final userData = {
      'user_id': _userDocumentId!, // CRITICAL: Include user_id
      'first_name': userProfile['first_name']?.toString().trim() ?? 'Unknown',
      'last_name': userProfile['last_name']?.toString().trim() ?? 'User',
      'gender': userProfile['gender']?.toString().trim() ?? 'Not specified',
      'age': userProfile['age']?.toString().trim() ?? '0',
      'nationality': userProfile['nationality']?.toString().trim() ?? 'Not specified',
      'hard_skills': scores['hard_skills']?.toStringAsFixed(2) ?? '0.00',
      'soft_skills': scores['soft_skills']?.toStringAsFixed(2) ?? '0.00',
      'teamwork': scores['teamwork']?.toStringAsFixed(2) ?? '0.00',
      'creativity': scores['creativity']?.toStringAsFixed(2) ?? '0.00',
      'class': userProfile['class']?.toString().trim() ?? 'Not specified',
      'completion_timestamp': DateTime.now().toIso8601String(),
    };

    // Add to collective data
    await CollectiveCSVManager.addCompletedUser(userData);

    // Check if we should trigger batch download
    final shouldTrigger = await CollectiveCSVManager.shouldTriggerBatchDownload();
    final currentCount = await CollectiveCSVManager.getCurrentCount();

    if (shouldTrigger) {
      // Generate and download collective CSV
      await CollectiveCSVManager.generateCollectiveCSV();
      
      // Reset for next batch
      await CollectiveCSVManager.resetCollectiveData();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch Complete! Downloaded CSV with user IDs for clustering.'),
            backgroundColor: Colors.green.shade600,
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      // Show progress message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User added to batch! Progress: $currentCount/12 users'),
            backgroundColor: Colors.blue.shade600,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

  } catch (e, stackTrace) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving user data to batch. Please try again.'),
          backgroundColor: Colors.red.shade600,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

  // UPDATED: Enhanced score loading with retry logic and fallback
  Future<Map<String, dynamic>?> _loadScoreWithRetry({int maxRetries = 3}) async {
    if (_userDocumentId == null || _quizId == null) {
      print('⚠️ Cannot load scores: User ID or Quiz ID not available');
      return null;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🔄 Score loading attempt $attempt/$maxRetries for quiz: $_quizId, user: $_userDocumentId');
        
        final scoreData = await ApiService.getScore(
          quizId: _quizId!,
          userId: _userDocumentId!,
        );

        if (scoreData != null) {
          print('✅ Score data loaded successfully on attempt $attempt: $scoreData');
          return scoreData;
        } else {
          print('⚠️ No score data returned on attempt $attempt');
          if (attempt < maxRetries) {
            // Wait before retry with exponential backoff
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      } catch (e) {
        print('❌ Score loading failed on attempt $attempt: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }

    print('⚠️ All score loading attempts failed, using cached scores');
    return _buildFallbackScoreData();
  }

  // UPDATED: Build fallback score data from local cache - capped at island 4
  Map<String, dynamic>? _buildFallbackScoreData() {
    if (_localScoreCache.isEmpty) {
      print('⚠️ No cached scores available');
      return null;
    }

    print('🔄 Building fallback score data from cache: $_localScoreCache');
    
    double totalScore = 0.0;
    Map<String, dynamic> scoreData = {
      'scoreCategory1': 0.0,
      'scoreCategory2': 0.0,
      'scoreCategory3': 0.0,
      'scoreCategory4': 0.0,
      'totalScore': 0.0,
      'island_position': _currentIslandPosition,
    };

    // Map cached scores to categories
    for (int i = 0; i < _islands.length; i++) {
      final island = _islands[i];
      final cachedScore = _getCachedScore(island.categoryId ?? '');
      if (cachedScore != null) {
        final categoryKey = 'scoreCategory${island.id}';
        scoreData[categoryKey] = cachedScore;
        totalScore += cachedScore;
        print('📊 Fallback score for category ${island.id}: $cachedScore');
      }
    }

    scoreData['totalScore'] = totalScore;
    
    // Update island position based on completed categories (capped at 4)
    final completedCount = _localScoreCache.length;
    if (completedCount > 0) {
      final clampedPosition = (completedCount + 1).clamp(1, 4);
      scoreData['island_position'] = 'island $clampedPosition';
    }

    print('📊 Fallback score data: $scoreData');
    return scoreData;
  }

  // UPDATED: Update island position after any progress change - capped at island 4
  Future<void> _updateIslandPosition() async {
    if (_userDocumentId == null || _quizId == null) {
      print('⚠️ Cannot update island position: User ID or Quiz ID not available');
      return;
    }

    try {
      print('🏝️ Updating island position for user: $_userDocumentId, quiz: $_quizId');
      
      final result = await ApiService.updateIslandPosition(
        userId: _userDocumentId!,
        quizId: _quizId!,
      );

      if (result != null && result['island_position'] != null) {
        String newPosition = result['island_position'] as String;
        
        // Cap the island position at 4
        if (newPosition.contains('island')) {
          final parts = newPosition.split(' ');
          if (parts.length >= 2) {
            try {
              final islandNumber = int.parse(parts[1]);
              final clampedNumber = islandNumber.clamp(1, 4); // Maximum of 4
              newPosition = 'island $clampedNumber';
            } catch (e) {
              // If parsing fails, keep original
            }
          }
        }
        
        if (newPosition != _currentIslandPosition) {
          setState(() {
            _currentIslandPosition = newPosition;
          });
          print('🎯 Island position updated to: $_currentIslandPosition');
        }
      } else {
        // Fallback: calculate position based on completed categories (capped at 4)
        final completedCount = _localScoreCache.length;
        final clampedPosition = (completedCount + 1).clamp(1, 4);
        final fallbackPosition = 'island $clampedPosition';
        if (fallbackPosition != _currentIslandPosition) {
          setState(() {
            _currentIslandPosition = fallbackPosition;
          });
          print('🎯 Island position updated (fallback) to: $_currentIslandPosition');
        }
      }
    } catch (e) {
      print('❌ Error updating island position: $e');
      // Fallback: calculate position based on completed categories (capped at 4)
      final completedCount = _localScoreCache.length;
      final clampedPosition = (completedCount + 1).clamp(1, 4);
      final fallbackPosition = 'island $clampedPosition';
      if (fallbackPosition != _currentIslandPosition) {
        setState(() {
          _currentIslandPosition = fallbackPosition;
        });
        print('🎯 Island position updated (fallback) to: $_currentIslandPosition');
      }
    }
  }

  // UPDATED: Load all earned badges with CSV saving logic
  Future<void> _loadAllEarnedBadges() async {
    if (_userDocumentId == null || _quizId == null) {
      print('⚠️ Cannot load badges: User ID or Quiz ID not available');
      setState(() {
        _isLoadingBadges = false;
      });
      return;
    }

    try {
      print('🏆 Loading all earned badges for user: $_userDocumentId');
      setState(() {
        _isLoadingBadges = true;
      });

      // UPDATED: Use enhanced score loading with retry
      final scoreData = await _loadScoreWithRetry();

      Set<AchievementBadge> allBadges = {};

      if (scoreData != null) {
        // Update island position from score data
        if (scoreData['island_position'] != null) {
          setState(() {
            _currentIslandPosition = scoreData['island_position'];
          });
          print('🎯 Current island position from score: $_currentIslandPosition');
        }

        // Get badges for each category score
        final scores = [
          (scoreData['scoreCategory1'] ?? 0.0).toDouble(),
          (scoreData['scoreCategory2'] ?? 0.0).toDouble(),
          (scoreData['scoreCategory3'] ?? 0.0).toDouble(),
          (scoreData['scoreCategory4'] ?? 0.0).toDouble(),
        ];

        print('🎯 Category scores: $scores');

        // Collect badges from all categories
        for (int i = 0; i < scores.length; i++) {
          final categoryBadges = BadgeSystem.getBadgesForScore(scores[i]);
          allBadges.addAll(categoryBadges);
          print('🏆 Category ${i + 1} earned ${categoryBadges.length} badges with score ${scores[i]}');
        }

        // Remove duplicates (since badges have same name across categories)
        final uniqueBadges = <String, AchievementBadge>{};
        for (final badge in allBadges) {
          uniqueBadges[badge.name] = badge;
        }

        setState(() {
          _allEarnedBadges = uniqueBadges.values.toList();
          _isLoadingBadges = false;
          _showBadgeCollection = _allEarnedBadges.isNotEmpty;
        });

        print('✅ Total unique badges earned: ${_allEarnedBadges.length}');

        // Start badge collection animation if we have badges
        if (_allEarnedBadges.isNotEmpty) {
          _badgeCollectionController.forward();
        }

        // UPDATED: Check if all islands completed and trigger CSV save with user ID
        print('🎯 Checking completion status after loading badges...');
        print('🎯 Current island position: $_currentIslandPosition');
        print('🎯 Score data available: ${scoreData != null}');
        print('🎯 All scores present: ${scores.every((score) => score > 0)}');
        
        // Check if user completed all islands (is at island 4 with all scores)
        if (_currentIslandPosition.contains('island 4') && scores.every((score) => score > 0)) {
          print('🎉 ===============================');
          print('🎉 ALL ISLANDS COMPLETED!');
          print('🎉 ===============================');
          print('🎉 User has finished all 4 islands');
          print('🎉 Island position: $_currentIslandPosition');
          print('🎉 All scores available: $scores');
          print('🎉 User ID: $_userDocumentId');
          print('🎉 Triggering CSV save with user ID...');
          
          // Trigger CSV save with user ID
          await _saveUserDataToCollectiveCSV();

          print('🎉 CSV save process with user ID completed!');
        } else {
          print('ℹ️ Not all islands completed yet');
          print('ℹ️ Current position: $_currentIslandPosition');
          print('ℹ️ Scores: $scores');
          print('ℹ️ CSV save skipped');
        }

      } else {
        setState(() {
          _allEarnedBadges = [];
          _isLoadingBadges = false;
          _showBadgeCollection = false;
        });
        print('⚠️ No score data available for badge calculation');
      }
    } catch (e) {
      print('❌ Error loading badges: $e');
      setState(() {
        _allEarnedBadges = [];
        _isLoadingBadges = false;
        _showBadgeCollection = false;
      });
    }
  }

  // Load user avatar with detailed debugging
  Future<void> _loadUserAvatar() async {
    if (_userDocumentId == null) {
      print('⚠️ Cannot load avatar: User ID not available');
      setState(() {
        _isLoadingAvatar = false;
      });
      return;
    }

    try {
      print('🎭 Loading avatar for user: $_userDocumentId');
      setState(() {
        _isLoadingAvatar = true;
      });

      // Ensure avatar service is available
      try {
        _avatarService = Get.find<FirebaseAvatarService>();
      } catch (e) {
        print('🔧 Avatar service not found, creating new instance');
        _avatarService = Get.put(FirebaseAvatarService(), permanent: true);
      }

      // Debug: First check all avatars to see what's in the database
      print('🔍 DEBUG: Checking all avatars in database...');
      List<AvatarData> allAvatars = await _avatarService.getAllAvatars();
      print('📊 DEBUG: Total avatars in database: ${allAvatars.length}');
      
      for (int i = 0; i < allAvatars.length; i++) {
        final avatar = allAvatars[i];
        print('🎭 DEBUG Avatar $i: user_id="${avatar.userId}", created_at=${avatar.createdAt}');
        print('   - Has image: ${avatar.imageAvatar != null}');
        print('   - User ID matches: ${avatar.userId == _userDocumentId}');
      }

      // Try to get user's specific avatars
      print('🔍 DEBUG: Searching for avatars with user_id: "$_userDocumentId"');
      List<AvatarData> userAvatars = await _avatarService.getAvatarsByUserId(_userDocumentId!);
      print('📊 DEBUG: Found ${userAvatars.length} avatars for user $_userDocumentId');

      if (userAvatars.isEmpty) {
        // Try manual search in case there's a data format issue
        print('🔍 DEBUG: No avatars found with query, trying manual search...');
        AvatarData? foundAvatar;
        
        for (final avatar in allAvatars) {
          if (avatar.userId != null && avatar.userId!.trim() == _userDocumentId!.trim()) {
            foundAvatar = avatar;
            print('✅ DEBUG: Found matching avatar manually!');
            break;
          }
        }
        
        if (foundAvatar != null) {
          userAvatars = [foundAvatar];
          print('✅ DEBUG: Manual search successful, found 1 avatar');
        }
      }
      
      if (userAvatars.isNotEmpty) {
        final selectedAvatar = userAvatars.first;
        print('🎭 DEBUG: Selected avatar details:');
        print('   - ID: ${selectedAvatar.id}');
        print('   - User ID: ${selectedAvatar.userId}');
        print('   - Has image: ${selectedAvatar.imageAvatar != null}');
        print('   - Image length: ${selectedAvatar.imageAvatar?.length ?? 0}');
        
        setState(() {
          _userAvatar = selectedAvatar;
          _isLoadingAvatar = false;
        });
        print('✅ Avatar loaded successfully for user $_userDocumentId');
      } else {
        setState(() {
          _userAvatar = null;
          _isLoadingAvatar = false;
        });
        print('📭 No avatar found for user $_userDocumentId after thorough search');
      }
    } catch (e) {
      print('❌ Error loading avatar: $e');
      setState(() {
        _userAvatar = null;
        _isLoadingAvatar = false;
      });
    }
  }

  // Fast background sync without affecting UI
  Future<void> _fastBackgroundSync() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      print('🔄 Fast sync: Starting background data sync');
      
      // Save progress to backend
      await _saveProgressToBackend();
      
      // Quick refresh of critical data only
      await _refreshCriticalDataOnly();
      
      // Update island position
      await _updateIslandPosition();
      
      print('✅ Fast sync: Background sync completed');
    } catch (e) {
      print('⚠️ Fast sync: Background sync failed (non-critical): $e');
      // Don't show error to user since this is background sync
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // UPDATED: Refresh critical data with enhanced score loading
  Future<void> _refreshCriticalDataOnly() async {
    try {
      if (_userDocumentId == null || _quizId == null) return;

      // UPDATED: Use enhanced score loading with retry
      final scoreData = await _loadScoreWithRetry();
      final completedCategories = await _loadProgressFromLocal();

      if (scoreData != null) {
        setState(() {
          _totalScore = (scoreData['totalScore'] ?? 0.0).toDouble();
          
          // Update island position from score data
          if (scoreData['island_position'] != null) {
            _currentIslandPosition = scoreData['island_position'];
          }
          
          // Update island scores
          for (int i = 0; i < _islands.length; i++) {
            final island = _islands[i];
            double? categoryScore;
            
            switch (island.id) {
              case 1:
                categoryScore = (scoreData['scoreCategory1'] ?? 0.0).toDouble();
                break;
              case 2:
                categoryScore = (scoreData['scoreCategory2'] ?? 0.0).toDouble();
                break;
              case 3:
                categoryScore = (scoreData['scoreCategory3'] ?? 0.0).toDouble();
                break;
              case 4:
                categoryScore = (scoreData['scoreCategory4'] ?? 0.0).toDouble();
                break;
            }
            
            final categoryKey = '${_quizId}_${island.categoryId}';
            final isCompleted = completedCategories.contains(categoryKey);
            
            // ADDED: Cache the score for future use
            if (categoryScore != null && categoryScore > 0) {
              _localScoreCache[categoryKey] = categoryScore;
            }
            
            if (categoryScore != null || isCompleted) {
              _islands[i] = _islands[i].copyWith(
                categoryScore: categoryScore,
                status: isCompleted ? IslandStatus.completed : _islands[i].status,
              );
            }
          }
        });
      }
    } catch (e) {
      print('⚠️ Critical data refresh failed: $e');
    }
  }

  Future<void> _loadCompleteIslandData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _loadingMessage = 'Connecting to your account...';
        _errorMessage = null;
      });

      final prefs = await SharedPreferences.getInstance();
      _userDocumentId = prefs.getString('user_document_id');
      
      if (_userDocumentId == null) {
        throw Exception('User not logged in');
      }

      print('🏝️ Islands Map: User Document ID: $_userDocumentId');
      print('🏝️ Islands Map: Quiz Data Keys: ${widget.quizData?.keys.toList()}');

      // Get quiz ID from quiz data with better validation
      if (widget.quizData != null) {
        _quizId = widget.quizData!['idQuiz']?.toString();
        print('🏝️ Islands Map: Quiz ID: $_quizId');
        
        if (_quizId == null) {
          throw Exception('Quiz data is missing idQuiz field');
        }
      } else {
        throw Exception('Quiz data is null');
      }

      setState(() {
        _loadingMessage = 'Loading quiz categories...';
      });

      // Load everything in the correct order without showing partial state
      await _loadCompleteIslandConfiguration();

      // Load user avatar after user ID is available
      await _loadUserAvatar();

      // NEW: Load all earned badges
      await _loadAllEarnedBadges();

      await _checkGroupAccessibility();

      // Initial island position update
      await _updateIslandPosition();

      // Debug quiz isolation on startup
      await _debugAfterOperation('initial load');

    } catch (e) {
      print('❌ Error loading island data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Error loading island data: ${e.toString()}';
        _loadingMessage = 'Error occurred';
      });
    }
  }

  Future<void> _loadCompleteIslandConfiguration() async {
    try {
      // Step 1: Prepare base island configuration
      final baseIslands = _createBaseIslandConfiguration();

      setState(() {
        _loadingMessage = 'Loading category information...';
      });

      // Step 2: Load category names and IDs
      List<QuizIsland> islandsWithNames = await _loadCategoryNames(baseIslands);

      setState(() {
        _loadingMessage = 'Loading your progress...';
      });

      // Step 3: Load complete progress data BEFORE showing anything
      List<QuizIsland> finalIslands = await _loadCompleteProgressData(islandsWithNames);

      setState(() {
        _loadingMessage = 'Finalizing...';
      });

      // Step 4: Only now set the islands with complete data
      setState(() {
        _islands = finalIslands;
        _isLoadingData = false;
        _errorMessage = null;
      });

      print('✅ Islands loaded with complete data, count: ${_islands.length}');

    } catch (e) {
      print('❌ Error loading complete island configuration: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Failed to load island configuration: ${e.toString()}';
        _loadingMessage = 'Error loading islands';
      });
    }
  }

  // UPDATED: Handle post-quiz loading with immediate score caching and CSV save check
  Future<void> _handlePostQuizLoading(QuizCompletionResult result) async {
    print('🎯 Post-quiz loading started for island ${result.islandId}');
    print('🎯 Quiz ID: ${result.quizId}, Category: ${result.categoryId}');
    print('🎯 Category Score: ${result.categoryScore}, Total Score: ${result.totalScore}');
    
    try {
      // Step 1: IMMEDIATELY cache the scores locally for instant UI updates
      await _saveCompletedCategoryToLocal(result.categoryId, categoryScore: result.categoryScore);
      
      // Update total score in cache
      _totalScore = result.totalScore;
      
      setState(() {
        _postQuizLoadingMessage = 'Saving your achievement...';
      });
      print('💾 Step 1: Cached scores immediately');
      
      // Step 2: Wait for minimum display time
      await Future.delayed(const Duration(milliseconds: 2000));
      
      // Step 3: Save progress to backend (run in background)
      _saveProgressToBackend(); // Don't await - let it run in background
      
      setState(() {
        _postQuizLoadingMessage = 'Updating island position...';
      });
      print('🏝️ Step 3: Updating island position');
      
      // Step 4: Update island position
      await _updateIslandPosition();
      
      setState(() {
        _postQuizLoadingMessage = 'Loading updated island data...';
      });
      print('🔄 Step 4: Reloading island configuration');
      
      // Step 5: Reload island configuration with new data
      await _loadCompleteIslandConfiguration();
      print('✅ Step 5: Island configuration reloaded');
      
      setState(() {
        _postQuizLoadingMessage = 'Updating your badge collection...';
      });
      print('🏆 Step 6: Reloading badge collection');
      
      // Step 6: Reload badges with new scores (THIS WILL TRIGGER CSV SAVE WITH USER ID IF ALL COMPLETED)
      await _loadAllEarnedBadges();
      print('✅ Step 6: Badge collection updated');
      
      // Step 7: Final delay for smooth transition
      await Future.delayed(const Duration(milliseconds: 1500));
      
      setState(() {
        _postQuizLoadingMessage = 'Finalizing your progress...';
      });
      
      await Future.delayed(const Duration(milliseconds: 1000));
      
      print('✅ Post-quiz loading completed successfully');
      print('🏝️ Final island position: $_currentIslandPosition');
      print('📊 Final total score: $_totalScore');
      print('🎯 All islands completed: ${_areAllIslandsCompleted()}');
      
      // Step 8: Trigger celebration animation
      _transitionController.reset();
      _transitionController.forward();
      
      // Haptic feedback for completion
      HapticFeedback.heavyImpact();
      
    } catch (e) {
      print('❌ Error in post-quiz loading: $e');
      // Even if there's an error, the scores are already cached locally
      _updateIslandOptimistically(result);
    } finally {
      // Always ensure loading states are turned off
      print('🏁 Turning off loading states');
      setState(() {
        _isPostQuizLoading = false;
        _showPostQuizLoadingImmediately = false;
      });
      print('🏁 Loading states turned off');
    }
  }

  // UPDATED: Optimistic update method with enhanced local caching
  void _updateIslandOptimistically(QuizCompletionResult result) {
    // Cache the completion and score
    _saveCompletedCategoryToLocal(result.categoryId, categoryScore: result.categoryScore);
    
    setState(() {
      // Update the specific island
      for (int i = 0; i < _islands.length; i++) {
        if (_islands[i].id == result.islandId) {
          _islands[i] = _islands[i].copyWith(
            status: IslandStatus.completed,
            categoryScore: result.categoryScore,
            isUnlocked: true,
          );
          
          // Unlock next island if exists
          if (i + 1 < _islands.length) {
            _islands[i + 1] = _islands[i + 1].copyWith(
              status: IslandStatus.available,
              isUnlocked: true,
            );
          }
          break;
        }
      }
      
      // Update total score
      _totalScore = result.totalScore;
    });

    // Update island position optimistically
    _updateIslandPosition();

    // Trigger celebration animation
    _transitionController.reset();
    _transitionController.forward();
    
    // Haptic feedback for completion
    HapticFeedback.heavyImpact();
  }

  List<QuizIsland> _createBaseIslandConfiguration() {
    return [
      QuizIsland(
        id: 1,
        name: "Category 1",
        position: Offset(0.2, 0.3),
        size: 130,
        color: Colors.red.shade600,
        icon: Icons.quiz,
        quizTopic: "category1",
        description: "Test your knowledge with challenging questions!",
        difficulty: "Medium",
        imagePath: "assets/images/islandN1.png",
        blackWhiteImagePath: "assets/images/islandN1.png",
        rotationSpeed: 0.5,
        floatAmplitude: 8.0,
        status: IslandStatus.available,
        isUnlocked: true,
      ),
      QuizIsland(
        id: 2,
        name: "Category 2",
        position: Offset(0.7, 0.25),
        size: 135,
        color: Colors.green.shade600,
        icon: Icons.quiz,
        quizTopic: "category2",
        description: "Explore and test your understanding!",
        difficulty: "Hard",
        imagePath: "assets/images/islandN2.png",
        blackWhiteImagePath: "assets/images/islandN2_bw.png",
        rotationSpeed: 0.3,
        floatAmplitude: 10.0,
        status: IslandStatus.locked,
        isUnlocked: false,
      ),
      QuizIsland(
        id: 3,
        name: "Category 3",
        position: Offset(0.3, 0.65),
        size: 125,
        color: Colors.orange.shade600,
        icon: Icons.quiz,
        quizTopic: "category3",
        description: "Journey through knowledge and test your skills!",
        difficulty: "Easy",
        imagePath: "assets/images/islandN3.png",
        blackWhiteImagePath: "assets/images/islandN3_bw.png",
        rotationSpeed: 0.7,
        floatAmplitude: 6.0,
        status: IslandStatus.locked,
        isUnlocked: false,
      ),
      QuizIsland(
        id: 4,
        name: "Category 4",
        position: Offset(0.75, 0.7),
        size: 128,
        color: Colors.purple.shade600,
        icon: Icons.quiz,
        quizTopic: "category4",
        description: "Dive into the world of knowledge and discovery!",
        difficulty: "Medium",
        imagePath: "assets/images/islandN4.png",
        blackWhiteImagePath: "assets/images/islandN4_bw.png",
        rotationSpeed: 0.4,
        floatAmplitude: 7.0,
        status: IslandStatus.locked,
        isUnlocked: false,
      ),
    ];
  }

  Future<List<QuizIsland>> _loadCategoryNames(List<QuizIsland> baseIslands) async {
    try {
      if (widget.quizData == null) {
        print('⚠️ Widget quiz data is null, using default category names');
        return baseIslands;
      }

      print('🔍 Quiz data contents: ${widget.quizData}');
      
      // Check if idCategory exists and is not null
      final categoryData = widget.quizData!['idCategory'];
      if (categoryData == null) {
        print('⚠️ Quiz data is missing idCategory field, using default category names');
        return baseIslands;
      }

      List<String> categoryIds;
      
      // Handle different possible formats of idCategory
      if (categoryData is List) {
        categoryIds = List<String>.from(categoryData);
      } else if (categoryData is String) {
        // If it's a single string, try to parse as JSON or split
        try {
          final decoded = json.decode(categoryData);
          if (decoded is List) {
            categoryIds = List<String>.from(decoded);
          } else {
            categoryIds = [categoryData];
          }
        } catch (e) {
          // If JSON parsing fails, treat as single ID
          categoryIds = [categoryData];
        }
      } else {
        categoryIds = [categoryData.toString()];
      }
      
      print('🏷️ Category IDs to fetch: $categoryIds');
      
      if (categoryIds.isEmpty) {
        print('⚠️ No category IDs found, using default category names');
        return baseIslands;
      }

      // Fetch category details from API
      List<Map<String, dynamic>> categories = [];
      
      for (String categoryId in categoryIds) {
        try {
          print('🔄 Fetching category data for ID: $categoryId');
          final response = await ApiService.getCategoryById(categoryId);
          if (response != null) {
            print('✅ Successfully fetched category: ${response['island']}');
            categories.add(response);
          } else {
            print('⚠️ No data returned for category ID: $categoryId');
          }
        } catch (e) {
          print('❌ Error fetching category $categoryId: $e');
          // Continue with other categories even if one fails
        }
      }

      print('📋 Total categories fetched: ${categories.length}');

      // Update islands with real category names and IDs
      List<QuizIsland> updatedIslands = [...baseIslands];
      for (int i = 0; i < updatedIslands.length && i < categories.length; i++) {
        final category = categories[i];
        final currentCategoryId = categoryIds[i];
        print('🏝️ Updating island ${i + 1} with category: ${category['island']}');
        
        updatedIslands[i] = updatedIslands[i].copyWith(
          name: category['island'] ?? updatedIslands[i].name,
          quizTopic: category['island'] ?? updatedIslands[i].quizTopic,
          description: category['description'] ?? updatedIslands[i].description,
          categoryId: currentCategoryId,
          blackWhiteImagePath: updatedIslands[i].blackWhiteImagePath,
        );
      }
      
      print('✅ Successfully updated ${categories.length} islands with category data');
      return updatedIslands;
    } catch (e) {
      print('❌ Error loading category names: $e');
      // Return base islands with error information
      print('⚠️ Falling back to default category names due to error');
      return baseIslands;
    }
  }

  // UPDATED: Enhanced complete progress data loading with cached scores
  Future<List<QuizIsland>> _loadCompleteProgressData(List<QuizIsland> islandsWithNames) async {
    try {
      if (_userDocumentId == null || _quizId == null) {
        print('⚠️ Missing user document ID or quiz ID, cannot load progress');
        return islandsWithNames;
      }

      print('🔄 Loading progress for user: $_userDocumentId, quiz: $_quizId');

      // Load progress data from backend first, then fallback to local if needed
      List<String> completedCategories = [];
      
      try {
        // Try backend first
        completedCategories = await _loadProgressFromBackend();
        print('✅ Loaded progress from backend: ${completedCategories.length} completed categories');
      } catch (e) {
        print('⚠️ Backend load failed, trying local: $e');
        // Fallback to local
        completedCategories = await _loadProgressFromLocal();
        print('📱 Loaded progress from local: ${completedCategories.length} completed categories');
      }

      // UPDATED: Load scores with retry and fallback to cache
      double totalScore = 0.0;
      Map<String, dynamic>? scoreData = await _loadScoreWithRetry();
      
      if (scoreData != null) {
        totalScore = (scoreData['totalScore'] ?? 0.0).toDouble();
        
        // Update island position from score data
        if (scoreData['island_position'] != null) {
          _currentIslandPosition = scoreData['island_position'];
          print('🏝️ Loaded island position from score: $_currentIslandPosition');
        }
        
        print('✅ Loaded total score: $totalScore');
      } else {
        print('⚠️ No score data found, using cached scores');
      }

      // Process islands with complete progress data
      List<QuizIsland> finalIslands = [];
      bool foundIncomplete = false;

      for (int i = 0; i < islandsWithNames.length; i++) {
        final island = islandsWithNames[i];
        final categoryKey = '${_quizId}_${island.categoryId}';
        final isCompleted = completedCategories.contains(categoryKey);

        print('🏝️ Island ${island.id}: categoryId="${island.categoryId}", categoryKey="$categoryKey", completed=$isCompleted');

        IslandStatus status;
        double? categoryScore;
        bool isUnlocked;

        if (isCompleted) {
          // Island is completed
          status = IslandStatus.completed;
          isUnlocked = true;
          
          // UPDATED: Get score from scoreData or cache
          if (scoreData != null) {
            switch (island.id) {
              case 1:
                categoryScore = (scoreData['scoreCategory1'] ?? 0.0).toDouble();
                break;
              case 2:
                categoryScore = (scoreData['scoreCategory2'] ?? 0.0).toDouble();
                break;
              case 3:
                categoryScore = (scoreData['scoreCategory3'] ?? 0.0).toDouble();
                break;
              case 4:
                categoryScore = (scoreData['scoreCategory4'] ?? 0.0).toDouble();
                break;
            }
          } else {
            // Fallback to cached score
            categoryScore = _getCachedScore(island.categoryId ?? '');
          }
          
          // Cache the score for future use
          if (categoryScore != null && categoryScore > 0) {
            _localScoreCache[categoryKey] = categoryScore;
          }
          
          print('📊 Island ${island.id} score: $categoryScore');
        } else if (!foundIncomplete) {
          // First incomplete island - make it available
          status = IslandStatus.available;
          isUnlocked = true;
          foundIncomplete = true;
          print('🔓 Island ${island.id} is available (first incomplete)');
        } else {
          // Subsequent islands - keep them locked
          status = IslandStatus.locked;
          isUnlocked = false;
          print('🔒 Island ${island.id} is locked');
        }

        finalIslands.add(island.copyWith(
          status: status,
          categoryScore: categoryScore,
          isUnlocked: isUnlocked,
        ));
      }

      // Set total score
      _totalScore = totalScore;
      print('🎯 Final total score: $_totalScore');
      print('🏝️ Final island position: $_currentIslandPosition');
      print('💾 Cached scores: $_localScoreCache');
      print('🎯 Quiz $_quizId progress summary: ${finalIslands.where((i) => i.status == IslandStatus.completed).length}/${finalIslands.length} islands completed');

      return finalIslands;
    } catch (e) {
      print('❌ Error loading complete progress data: $e');
      return islandsWithNames;
    }
  }

  // UPDATED: Enhanced progress loading with better debugging
  Future<List<String>> _loadProgressFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final userSpecificKey = _getUserSpecificKey('completed_categories');
    final allCompletedCategories = prefs.getStringList(userSpecificKey) ?? [];
    
    // Filter to only include categories for the current quiz
    final currentQuizCategories = allCompletedCategories
        .where((categoryKey) => categoryKey.startsWith('${_quizId}_'))
        .toList();
    
    print('📊 Progress Debug for Quiz $_quizId:');
    print('   - Total completed categories for user: ${allCompletedCategories.length}');
    print('   - Completed categories for current quiz: ${currentQuizCategories.length}');
    print('   - Current quiz categories: $currentQuizCategories');
    
    return allCompletedCategories; // Return all, but we filter during processing
  }

  // UPDATED: Enhanced backend progress loading with debugging
  Future<List<String>> _loadProgressFromBackend() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/auth/load-quiz-progress/$_userDocumentId'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final List<String> backendCompletedCategories = List<String>.from(responseData['completedCategories'] ?? []);
      
      // Filter to only include categories for the current quiz for debugging
      final currentQuizCategories = backendCompletedCategories
          .where((categoryKey) => categoryKey.startsWith('${_quizId}_'))
          .toList();
      
      print('📊 Backend Progress Debug for Quiz $_quizId:');
      print('   - Total completed categories from backend: ${backendCompletedCategories.length}');
      print('   - Completed categories for current quiz: ${currentQuizCategories.length}');
      print('   - Current quiz categories: $currentQuizCategories');
      
      // Sync to local storage
      final prefs = await SharedPreferences.getInstance();
      final userSpecificKey = _getUserSpecificKey('completed_categories');
      await prefs.setStringList(userSpecificKey, backendCompletedCategories);
      
      return backendCompletedCategories;
    } else {
      throw Exception('Backend load failed: ${response.statusCode}');
    }
  }

  // Helper method to get user-specific keys for SharedPreferences
  String _getUserSpecificKey(String baseKey) {
    if (_userDocumentId != null) {
      return '${baseKey}_${_userDocumentId}';
    }
    return '${baseKey}_guest';
  }

  Future<void> _saveProgressToBackend() async {
    try {
      if (_userDocumentId == null) return;
      
      print('💾 Saving progress to backend for user: $_userDocumentId');
      
      final prefs = await SharedPreferences.getInstance();
      final completedCategoriesKey = _getUserSpecificKey('completed_categories');
      final completeQuizDataKey = _getUserSpecificKey('complete_quiz_data');
      
      final completedCategories = prefs.getStringList(completedCategoriesKey) ?? [];
      final completeQuizData = prefs.getStringList(completeQuizDataKey) ?? [];
      
      print('📊 Saving to backend:');
      print('   - Completed categories: ${completedCategories.length}');
      print('   - Complete quiz data entries: ${completeQuizData.length}');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/save-quiz-progress/$_userDocumentId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'completedCategories': completedCategories,
          'completeQuizData': completeQuizData,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Progress saved to backend successfully');
      } else {
        print('⚠️ Failed to save progress to backend: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error saving progress to backend: $e');
    }
  }

  // UPDATED: Refresh after quiz completion with local storage saving
  Future<void> _refreshAfterQuizCompletion() async {
    try {
      print('🔄 Refreshing after quiz completion (fallback method)');
      
      // Save progress to backend first
      await _saveProgressToBackend();

      // Update island position
      await _updateIslandPosition();
      
      // Then reload the complete island configuration
      await _loadCompleteIslandConfiguration();

      // Also reload badges
      await _loadAllEarnedBadges();

    } catch (e) {
      print('❌ Error refreshing after quiz completion: $e');
    }
  }

  // DEBUGGING: Method to check quiz isolation
  Future<void> _debugQuizIsolation() async {
    if (_quizId == null || _userDocumentId == null) {
      print('⚠️ Cannot debug: Missing quiz ID or user ID');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userSpecificKey = _getUserSpecificKey('completed_categories');
    final allCategories = prefs.getStringList(userSpecificKey) ?? [];
    
    print('🔍 QUIZ ISOLATION DEBUG for Quiz $_quizId:');
    print('────────────────────────────────────────');
    
    // Group categories by quiz
    final categoriesByQuiz = <String, List<String>>{};
    for (final category in allCategories) {
      if (category.contains('_')) {
        final parts = category.split('_');
        if (parts.length >= 2) {
          final quizId = parts[0];
          categoriesByQuiz[quizId] = categoriesByQuiz[quizId] ?? [];
          categoriesByQuiz[quizId]!.add(category);
        }
      } else {
        categoriesByQuiz['INVALID'] = categoriesByQuiz['INVALID'] ?? [];
        categoriesByQuiz['INVALID']!.add(category);
      }
    }
    
    categoriesByQuiz.forEach((quizId, categories) {
      print('📊 Quiz $quizId: ${categories.length} completed categories');
      for (final category in categories) {
        print('   ├─ $category');
      }
    });
    
    // Check current quiz specifically
    final currentQuizCategories = categoriesByQuiz[_quizId] ?? [];
    print('🎯 Current Quiz ($_quizId) Progress:');
    print('   ├─ Completed categories: ${currentQuizCategories.length}');
    print('   ├─ Islands status:');
    
    for (int i = 0; i < _islands.length; i++) {
      final island = _islands[i];
      final categoryKey = '${_quizId}_${island.categoryId}';
      final isCompleted = currentQuizCategories.contains(categoryKey);
      final cachedScore = _getCachedScore(island.categoryId ?? '');
      print('   ├─ Island ${island.id} (${island.categoryId}): ${isCompleted ? "COMPLETED" : "PENDING"} [${island.status}] Score: $cachedScore');
    }
    
    print('💾 Cached Scores: $_localScoreCache');
    print('────────────────────────────────────────');
  }

  // Add this method to be called after any major operation for debugging
  Future<void> _debugAfterOperation(String operation) async {
    print('🔍 DEBUG after $operation:');
    await _debugQuizIsolation();
  }

  void _initializeIslandKeys() {
    for (int i = 1; i <= 4; i++) {
      _islandKeys[i] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _cloudController.dispose();
    _particleController.dispose();
    _islandController.dispose();
    _lightController.dispose();
    _rotationController.dispose();
    _scoreController.dispose();
    _transitionController.dispose();
    _postQuizLoadingController.dispose();
    _avatarPulseController.dispose();
    _badgeCollectionController.dispose(); // NEW: Dispose badge collection controller
    super.dispose();
  }

  void _onIslandTapped(QuizIsland island) {
    if (!island.canBeTapped) {
      // Show appropriate message for locked or completed islands
      if (island.status == IslandStatus.locked) {
        _showLockedIslandDialog(island);
      } else if (island.status == IslandStatus.completed) {
        _showCompletedIslandDialog(island);
      }
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _selectedIsland = island.id;
    });
    
    // Show quiz selection dialog
    _showQuizDialog(island);
  }

  void _showLockedIslandDialog(QuizIsland island) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.grey.shade600, size: 28),
            const SizedBox(width: 12),
            const Text('Island Locked'),
          ],
        ),
        content: Text(
          'Complete the previous island to unlock ${island.name}!',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompletedIslandDialog(QuizIsland island) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
            const SizedBox(width: 12),
            const Text('Island Completed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You have already completed ${island.name}!',
              style: const TextStyle(fontSize: 16),
            ),
            if (island.categoryScore != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Your Score',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${island.categoryScore!.toStringAsFixed(1)}/5.0',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: Colors.green.shade600,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuizDialog(QuizIsland island) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              island.color.withOpacity(0.9),
              island.color.withOpacity(0.7),
              Colors.white.withOpacity(0.9),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Handle
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),
              
              // Island Info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      island.icon,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      island.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(island.difficulty),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Difficulty: ${island.difficulty}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      island.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _startQuiz(island);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: island.color,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Start Quiz',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED: Start quiz with proper loading state management
  void _startQuiz(QuizIsland island) {
    // Additional validation before starting quiz
    if (_quizId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Quiz ID not found. Please try restarting the quiz.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('🚀 Starting quiz for island: ${island.name}, Category ID: ${island.categoryId}');
    
    Offset zoomCenter;
    
    if (_useManualZoomCenters && _manualZoomCenters[island.id] != null) {
      zoomCenter = _manualZoomCenters[island.id]!;
    } else {
      final RenderBox? renderBox = _islandKeys[island.id]?.currentContext?.findRenderObject() as RenderBox?;
      
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        zoomCenter = Offset(
          position.dx + size.width / 2,
          position.dy + size.height / 2,
        );
      } else {
        zoomCenter = _getCalculatedZoomCenter(island);
      }
    }
    
    Navigator.of(context).push(
      IslandZoomPageRoute(
        builder: (context) => _getQuizScreenForIsland(island),
        zoomCenter: zoomCenter,
        island: island,
        currentFloatOffset: _islandAnimation.value * island.floatAmplitude,
      ),
    ).then((result) async {
      print('🔙 Returned from quiz screen with result type: ${result.runtimeType}');
      
      // Immediately show loading screen when ANY result is received
      if (result is QuizCompletionResult) {
        print('🎉 Quiz completed with result: ${result.toString()}');
        print('🎉 Setting loading states to true immediately');
        
        // IMMEDIATELY set loading states - this is crucial
        setState(() {
          _showPostQuizLoadingImmediately = true;
          _isPostQuizLoading = true;
          _postQuizLoadingMessage = 'Processing your achievement...';
        });
        
        print('🎉 Loading states set: _isPostQuizLoading=$_isPostQuizLoading, _showPostQuizLoadingImmediately=$_showPostQuizLoadingImmediately');
        
        // Force a rebuild to ensure loading screen appears
        WidgetsBinding.instance.addPostFrameCallback((_) {
          print('🔄 Forcing rebuild to show loading screen');
          setState(() {});
        });
        
        // Small delay to ensure setState has taken effect
        await Future.delayed(const Duration(milliseconds: 100));
        print('🎯 About to start post-quiz loading sequence');
        
        // Start the loading sequence with proper awaiting
        await _handlePostQuizLoading(result);
      } else {
        // Fallback method if no result provided
        print('🔄 No completion result, using fallback refresh');
        await _refreshAfterQuizCompletion();
      }
    });
  }

  Offset _getCalculatedZoomCenter(QuizIsland island) {
    final screenSize = MediaQuery.of(context).size;
    final mediaQuery = MediaQuery.of(context);
    final safePadding = mediaQuery.padding;
    
    final islandX = island.position.dx * screenSize.width;
    final islandY = island.position.dy * screenSize.height;
    
    final currentFloatOffset = _islandAnimation.value * island.floatAmplitude;
    
    final exactIslandCenterX = islandX;
    final exactIslandCenterY = islandY + currentFloatOffset;
    
    final adjustedCenterY = exactIslandCenterY + safePadding.top;
    
    return Offset(exactIslandCenterX, adjustedCenterY);
  }

  Widget _getQuizScreenForIsland(QuizIsland island) {
    switch (island.id) {
      case 1:
        return Category1QuizScreen(island: island);
      case 2:
        return Category2QuizScreen(island: island);
      case 3:
        return Category3QuizScreen(island: island);
      case 4:
        return Category4QuizScreen(island: island);
      default:
        return IslandsMapScreen();
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _getIslandImage(QuizIsland island) {
    // Determine which image to use based on island status
    String? imageToUse;
    
    if (island.id == 1) {
      // Island 1 always uses colored image
      imageToUse = island.imagePath;
    } else {
      // For islands 2, 3, and 4: use black and white when locked, colored otherwise
      if (island.status == IslandStatus.locked) {
        imageToUse = island.blackWhiteImagePath ?? island.imagePath;
      } else {
        imageToUse = island.imagePath;
      }
    }
    
    if (imageToUse != null) {
      return Image.asset(
        imageToUse,
        fit: BoxFit.contain,
        width: island.size.toDouble(),
        height: island.size.toDouble(),
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              island.getStatusIcon(),
              color: island.getStatusColor(),
              size: 40,
            ),
          );
        },
      );
    } else {
      return Center(
        child: Icon(
          island.getStatusIcon(),
          color: island.getStatusColor(),
          size: 40,
        ),
      );
    }
  }

  // Build user avatar display widget
  Widget _buildUserAvatarDisplay() {
    return AnimatedBuilder(
      animation: _avatarPulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _avatarPulseAnimation.value,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.blue.shade50.withOpacity(0.9),
                ],
              ),
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: _buildAvatarContent(),
            ),
          ),
        );
      },
    );
  }

  // Build avatar content based on loading/data state
  Widget _buildAvatarContent() {
    if (_isLoadingAvatar) {
      return Container(
        color: Colors.grey.shade100,
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
          ),
        ),
      );
    }

    if (_userAvatar == null || _userAvatar!.imageAvatar == null || _userAvatar!.imageAvatar!.isEmpty) {
      if (_userAvatar != null) {
        print('⚠️ DEBUG: Avatar found but no image data. Avatar ID: ${_userAvatar!.id}');
      } else {
        print('⚠️ DEBUG: No avatar data available');
      }
      return Container(
        color: Colors.blue.shade100,
        child: Icon(
          Icons.person,
          size: 40,
          color: Colors.blue.shade600,
        ),
      );
    }

    // Check if we've already processed this avatar data
    if (_userAvatar!.imageAvatar != _lastProcessedAvatarData) {
      _lastProcessedAvatarData = _userAvatar!.imageAvatar;
      _cachedAvatarBytes = null; // Reset cache
      
      try {
        String imageData = _userAvatar!.imageAvatar!;
        
        // Remove data URL prefix if present
        if (imageData.contains(',')) {
          imageData = imageData.split(',').last;
        }
        
        // Decode and cache the bytes
        _cachedAvatarBytes = base64Decode(imageData);
        print('✅ Avatar image decoded and cached successfully');
      } catch (e) {
        print('❌ Error decoding avatar image: $e');
        return Container(
          color: Colors.red.shade100,
          child: Icon(
            Icons.error,
            size: 32,
            color: Colors.red,
          ),
        );
      }
    }

    // Use cached bytes if available
    if (_cachedAvatarBytes != null) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: ClipOval(
          child: Image.memory(
            _cachedAvatarBytes!,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('❌ Error displaying cached avatar image: $error');
              return Container(
                color: Colors.red.shade100,
                child: Icon(
                  Icons.error,
                  size: 32,
                  color: Colors.red,
                ),
              );
            },
          ),
        ),
      );
    }

    // Fallback if everything fails
    return Container(
      color: Colors.blue.shade100,
      child: Icon(
        Icons.person,
        size: 40,
        color: Colors.blue.shade600,
      ),
    );
  }

  // FIXED: Build badge button display for bottom left positioning
  Widget _buildBadgeButton() {
    if (!_showBadgeCollection || _allEarnedBadges.isEmpty) {
      return Container();
    }

    return AnimatedBuilder(
      animation: _badgeCollectionAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: (_badgeCollectionAnimation.value).clamp(0.0, 1.0),
          child: Opacity(
            opacity: (_badgeCollectionAnimation.value).clamp(0.0, 1.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showBadgePopup = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.amber.shade400,
                      Colors.orange.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'View Badges',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_allEarnedBadges.length}',
                        style: TextStyle(
                          color: Colors.amber.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // NEW: Build badge popup/modal
  Widget _buildBadgePopup() {
    if (!_showBadgePopup) return Container();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.amber.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.amber.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade400,
                      Colors.orange.shade400,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Your Achievement Badges',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_allEarnedBadges.length}',
                        style: TextStyle(
                          color: Colors.amber.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showBadgePopup = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Badge grid content
              Expanded(
                child: _allEarnedBadges.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emoji_events_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No badges earned yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Complete quizzes to earn badges!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(20),
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: _allEarnedBadges.length,
                          itemBuilder: (context, index) {
                            final badge = _allEarnedBadges[index];
                            return _buildDetailedBadgeCard(badge);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Build detailed badge card for popup
  Widget _buildDetailedBadgeCard(AchievementBadge badge) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            badge.color.withOpacity(0.1),
            badge.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: badge.color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: badge.color.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            badge.icon,
            style: TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: badge.color.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            badge.description,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Build post-quiz loading screen (exactly like initial loading)
  Widget _buildPostQuizLoadingScreen() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        margin: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.blue.shade50.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.blue.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade100,
                border: Border.all(
                  color: Colors.blue.shade300,
                  width: 3,
                ),
              ),
              child: CircularProgressIndicator(
                color: Colors.blue.shade600,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 25),
            Text(
              _postQuizLoadingMessage,
              style: TextStyle(
                fontSize: 20,
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Please wait while we update your progress...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, color: Colors.blue.shade600, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Updating your achievement',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            // NEW: Display current island position during loading
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, color: Colors.blue.shade600, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Current Position: $_currentIslandPosition',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Show cached scores during loading
            if (_localScoreCache.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.score, color: Colors.green.shade600, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Total Score: ${_totalScore.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOrErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        margin: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _errorMessage != null 
                ? [
                    Colors.red.shade50.withOpacity(0.95),
                    Colors.red.shade100.withOpacity(0.95),
                  ]
                : [
                    Colors.white.withOpacity(0.95),
                    Colors.blue.shade50.withOpacity(0.95),
                  ],
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: _errorMessage != null 
                ? Colors.red.shade200
                : Colors.blue.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (_errorMessage != null ? Colors.red : Colors.blue).withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_errorMessage != null ? Colors.red : Colors.blue).shade100,
                border: Border.all(
                  color: (_errorMessage != null ? Colors.red : Colors.blue).shade300,
                  width: 3,
                ),
              ),
              child: _errorMessage != null
                  ? Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: 40,
                    )
                  : CircularProgressIndicator(
                      color: Colors.blue.shade600,
                      strokeWidth: 4,
                    ),
            ),
            const SizedBox(height: 25),
            Text(
              _errorMessage ?? _loadingMessage,
              style: TextStyle(
                fontSize: 20,
                color: (_errorMessage != null ? Colors.red : Colors.blue).shade800,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage != null
                  ? 'Please check your connection and try again.'
                  : 'Please wait while we prepare your adventure...',
              style: TextStyle(
                fontSize: 14,
                color: (_errorMessage != null ? Colors.red : Colors.blue).shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _loadCompleteIslandData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ] else ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sailing, color: Colors.blue.shade600, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Setting up your islands',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalScoreDisplay(Size screenSize) {
    return AnimatedBuilder(
      animation: _scoreAnimation,
      builder: (context, child) {
        return Positioned(
          left: screenSize.width / 2 - 80,
          top: screenSize.height / 2 - 60 + _scoreAnimation.value,
          child: Container(
            width: 160,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber.shade300,
                  Colors.amber.shade400,
                  Colors.orange.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.6),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    const Text(
                      'Total Score',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_totalScore.toStringAsFixed(1)}/5.0',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // NEW: Build island position indicator with maximum of 4
  Widget _buildIslandPositionIndicator() {
    // Parse current position and ensure it doesn't exceed 4
    String displayPosition = _currentIslandPosition;
    if (displayPosition.contains('island')) {
      final parts = displayPosition.split(' ');
      if (parts.length >= 2) {
        try {
          final islandNumber = int.parse(parts[1]);
          final clampedNumber = islandNumber.clamp(1, 4); // Maximum of 4
          displayPosition = 'island $clampedNumber';
        } catch (e) {
          // If parsing fails, keep original
          displayPosition = _currentIslandPosition;
        }
      }
    }

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.9),
              Colors.blue.shade50.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              size: 16,
              color: Colors.blue.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              displayPosition.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIsland(QuizIsland island, Size screenSize) {
    final islandX = island.position.dx * screenSize.width;
    final islandY = island.position.dy * screenSize.height;
    final isSelected = _selectedIsland == island.id;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_islandAnimation, _rotationAnimation, _scoreAnimation, _transitionAnimation]),
      builder: (context, child) {
        final floatOffset = _islandAnimation.value * island.floatAmplitude;
        final rotation = _rotationAnimation.value * island.rotationSpeed * 0.02;
        
        // Scale animation for completed islands
        final celebrationScale = island.status == IslandStatus.completed 
            ? 1.0 + ((_transitionAnimation.value).clamp(0.0, 1.0) * 0.1)
            : 1.0;
        
        return Positioned(
          left: islandX - (island.size + 20) / 2,
          top: islandY - (island.size + 20) / 2 + floatOffset,
          child: RepaintBoundary(
            key: _islandKeys[island.id],
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onIslandTapped(island),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                transform: Matrix4.identity()
                  ..scale(isSelected ? 1.02 : celebrationScale),
                child: Container(
                  width: island.size.toDouble() + 40,
                  height: island.size.toDouble() + 40,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Island Shadow
                      Positioned(
                        bottom: 12,
                        left: 24,
                        right: 16,
                        child: Container(
                          height: island.size * 0.2,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(island.size / 2),
                          ),
                        ),
                      ),
                      
                      // Island Image with status overlay
                      Positioned(
                        left: 20,
                        top: 20,
                        child: Transform.rotate(
                          angle: rotation,
                          child: Container(
                            width: island.size.toDouble(),
                            height: island.size.toDouble(),
                            child: Center(
                              child: _getIslandImage(island),
                            ),
                          ),
                        ),
                      ),
                      
                      // Status icon overlay
                      if (island.status == IslandStatus.locked)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        
                      if (island.status == IslandStatus.completed)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: AnimatedBuilder(
                            animation: _transitionAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1.0 + ((_transitionAnimation.value).clamp(0.0, 1.0) * 0.2),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.5 + (_transitionAnimation.value).clamp(0.0, 1.0) * 0.3),
                                        blurRadius: 8 + ((_transitionAnimation.value).clamp(0.0, 1.0) * 10),
                                        offset: Offset(0, 2),
                                        spreadRadius: (_transitionAnimation.value).clamp(0.0, 1.0) * 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      
                      // Selection Circle
                      if (isSelected)
                        Positioned(
                          top: 10,
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: AnimatedBuilder(
                            animation: _rotationController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotationController.value * 2 * pi,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: island.color.withOpacity(0.8),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: island.color.withOpacity(0.4),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      
                      // Score Display for completed islands
                      if (island.status == IslandStatus.completed && island.categoryScore != null)
                        Positioned(
                          top: 0 + _scoreAnimation.value,
                          left: (island.size + 40) / 2 - 25,
                          child: AnimatedBuilder(
                            animation: _transitionAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1.0 + ((_transitionAnimation.value).clamp(0.0, 1.0) * 0.15),
                                child: Container(
                                  width: 50,
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green.shade400,
                                        Colors.green.shade500,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.4 + (_transitionAnimation.value).clamp(0.0, 1.0) * 0.3),
                                        blurRadius: 8 + ((_transitionAnimation.value).clamp(0.0, 1.0) * 5),
                                        spreadRadius: 2 + ((_transitionAnimation.value).clamp(0.0, 1.0) * 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star, color: Colors.white, size: 10),
                                      const SizedBox(height: 1),
                                      Text(
                                        island.scoreDisplayText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      
                      // Category Name
                      Positioned(
                        bottom: -25,
                        left: 0,
                        right: 0,
                        child: Text(
                          island.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                offset: Offset(1, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // UPDATED: Build UI with avatar only (no badge collection)
  Widget _buildUI() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Top Bar with Avatar only (no badge collection)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  ),
                  
                  // User Avatar only (removed badge collection)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () {
                        // Optional: Show avatar details or edit avatar
                        if (_userAvatar != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Avatar created: ${_userAvatar!.createdAt.toString().substring(0, 16)}'),
                              backgroundColor: Colors.blue.shade600,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No avatar found. Create one in the profile section!'),
                              backgroundColor: Colors.orange.shade600,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: _buildUserAvatarDisplay(),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Title
                  Text(
                    widget.quizData != null 
                        ? '🏝️ ${widget.quizData!['nameQuiz'] ?? 'Quiz Islands'}'
                        : '🏝️ Quiz Islands',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 90), // Reduced space since no badge collection
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UPDATED: Build method with badge collection in bottom left and island position indicator
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    // Ensure FirebaseAvatarService is available (safety check)
    try {
      Get.find<FirebaseAvatarService>();
    } catch (e) {
      // Register if not found
      Get.put(FirebaseAvatarService(), permanent: true);
      print('🔧 FirebaseAvatarService registered in build method as fallback');
    }
    
    // Debug: Print loading states on every build
    print('🏗️ Build called - Loading states: _isPostQuizLoading=$_isPostQuizLoading, _showPostQuizLoadingImmediately=$_showPostQuizLoadingImmediately, _isLoadingData=$_isLoadingData');
    print('🏝️ Current island position: $_currentIslandPosition');
    print('💾 Local score cache: $_localScoreCache');
    
    return Scaffold(
      body: Stack(
        children: [
          
          // Animated Background
          AnimatedBuilder(
            animation: Listenable.merge([_lightAnimation, _waveAnimation]),
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(
                        const Color(0xFF87CEEB),
                        const Color(0xFFFFE082),
                        _lightAnimation.value * 0.3,
                      )!,
                      Color.lerp(
                        const Color(0xFF4FC3F7),
                        const Color(0xFFFFB74D),
                        _lightAnimation.value * 0.2,
                      )!,
                      Color.lerp(
                        const Color(0xFF29B6F6),
                        const Color(0xFFFF8A65),
                        _lightAnimation.value * 0.2,
                      )!,
                      Color.lerp(
                        const Color(0xFF0277BD),
                        const Color(0xFF1976D2),
                        _lightAnimation.value * 0.2,
                      )!,
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Ocean with Waves
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: EnhancedOceanPainter(_waveAnimation.value, _lightAnimation.value),
                size: Size.infinite,
              );
            },
          ),
          
          // Floating Particles
          AnimatedBuilder(
            animation: _particleAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlePainter(_particleAnimation.value),
                size: Size.infinite,
              );
            },
          ),
          
          // Animated Clouds
          AnimatedBuilder(
            animation: _cloudAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: CloudPainter(_cloudAnimation.value, _lightAnimation.value),
                size: Size.infinite,
              );
            },
          ),
          
          // Loading State or Error State (initial loading) - Show ONLY when not post-quiz loading
          if ((_isLoadingData || _errorMessage != null) && !_isPostQuizLoading && !_showPostQuizLoadingImmediately)
            _buildLoadingOrErrorState(),
          
          // Total Score Display - Only show when appropriate
          if (!_isLoadingData && _errorMessage == null && _islands.isNotEmpty && _totalScore > 0 && !_isPostQuizLoading && !_showPostQuizLoadingImmediately)
            _buildTotalScoreDisplay(screenSize),

          // NEW: Island Position Indicator - Only show when islands are loaded
          if (!_isLoadingData && _errorMessage == null && _islands.isNotEmpty && !_isPostQuizLoading && !_showPostQuizLoadingImmediately)
            _buildIslandPositionIndicator(),
          
          // Islands - Only show when data is loaded and not in loading state
          if (!_isLoadingData && _errorMessage == null && _islands.isNotEmpty && !_isPostQuizLoading && !_showPostQuizLoadingImmediately)
            ..._islands.map((island) => _buildIsland(island, screenSize)),
          
          // Background refresh indicator - only when not in post-quiz loading
          if (_isRefreshing && !_isPostQuizLoading && !_showPostQuizLoadingImmediately)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Syncing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // UI Controls - Only when not in post-quiz loading
          if (!_isPostQuizLoading && !_showPostQuizLoadingImmediately)
            _buildUI(),
          
          // Badge Button - Bottom Left (NEW POSITION)
          if (!_isPostQuizLoading && !_showPostQuizLoadingImmediately)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 20,
              child: _buildBadgeButton(),
            ),
          
          // Badge Popup - Full Screen Overlay
          if (_showBadgePopup)
            Positioned.fill(
              child: _buildBadgePopup(),
            ),
          
          // UPDATED: Group Members Button - Show when all islands completed
          if (!_isPostQuizLoading && !_showPostQuizLoadingImmediately)
            _buildGroupMembersButton(),
          
          // UPDATED: Enhanced Group Members Popup
          if (_showGroupMembersPopup)
            Positioned.fill(
              child: _buildEnhancedGroupMembersPopup(),
            ),
          
          // POST-QUIZ LOADING SCREEN - HIGHEST PRIORITY (moved to end for z-index)
          if (_showPostQuizLoadingImmediately || _isPostQuizLoading) ...[
            // Debug statement
            Builder(builder: (context) {
              print('🎬 POST-QUIZ LOADING SCREEN IS BEING SHOWN');
              return Container();
            }),
            Container(
              // Full screen overlay
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.3), // Semi-transparent overlay
              child: _buildPostQuizLoadingScreen(),
            ),
          ],
        ],
      ),
    );
  }
}

// Keep all the existing custom painters and page routes exactly the same...
class IslandZoomPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Offset zoomCenter;
  final QuizIsland island;
  final double currentFloatOffset;

  IslandZoomPageRoute({
    required this.builder,
    required this.zoomCenter,
    required this.island,
    this.currentFloatOffset = 0.0,
    RouteSettings? settings,
  }) : super(settings: settings);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 1500);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final screenSize = MediaQuery.of(context).size;
    
    final cameraZoomAnimation = Tween<double>(
      begin: 1.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
    ));

    final fadeToBlackAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.5, 0.8, curve: Curves.easeInOut),
    ));

    final fadeFromBlackAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
    ));

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        if (animation.value <= 0.8) {
          return Stack(
            children: [
              Transform.scale(
                scale: cameraZoomAnimation.value,
                alignment: Alignment(
                  (zoomCenter.dx / screenSize.width) * 2 - 1,
                  (zoomCenter.dy / screenSize.height) * 2 - 1,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF87CEEB),
                        const Color(0xFF4FC3F7),
                        const Color(0xFF29B6F6),
                        const Color(0xFF0277BD),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      CustomPaint(
                        painter: EnhancedOceanPainter(0, 0.8),
                        size: Size.infinite,
                      ),
                      CustomPaint(
                        painter: CloudPainter(0, 0.8),
                        size: Size.infinite,
                      ),
                      Positioned(
                        left: zoomCenter.dx - island.size / 2,
                        top: zoomCenter.dy - island.size / 2,
                        child: Container(
                          width: island.size.toDouble(),
                          height: island.size.toDouble(),
                          child: Center(
                            child: island.imagePath != null
                                ? Image.asset(
                                    island.imagePath!,
                                    fit: BoxFit.contain,
                                    width: island.size.toDouble(),
                                    height: island.size.toDouble(),
                                  )
                                : Icon(
                                    island.icon,
                                    color: island.color,
                                    size: 40,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(fadeToBlackAnimation.value),
                ),
              ),
            ],
          );
        } else {
          return Stack(
            children: [
              child,
              IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(fadeFromBlackAnimation.value),
                ),
              ),
            ],
          );
        }
      },
    );
  }
}

class EnhancedOceanPainter extends CustomPainter {
  final double animationValue;
  final double lightValue;

  EnhancedOceanPainter(this.animationValue, this.lightValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (int layer = 0; layer < 5; layer++) {
      final wavePaint = Paint()
        ..color = Colors.white.withOpacity(0.08 - layer * 0.015)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 - layer * 0.3;

      final path = Path();
      final waveOffset = animationValue + layer * 1.2;
      final frequency = 4 + layer * 1.5;
      final amplitude = 15 - layer * 2;
      
      for (double x = 0; x <= size.width + 20; x += 4) {
        final baseY = size.height * (0.15 + layer * 0.08);
        final wave1 = sin((x / size.width) * frequency * pi + waveOffset) * amplitude;
        final wave2 = sin((x / size.width) * (frequency * 1.3) * pi + waveOffset * 1.1) * (amplitude * 0.5);
        final y = baseY + wave1 + wave2;
        
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      
      canvas.drawPath(path, wavePaint);
    }

    final sparklePaint = Paint()..color = Colors.white.withOpacity(lightValue * 0.6);

    for (int i = 0; i < 30; i++) {
      final sparkleSpeed = 0.3 + (i % 3) * 0.2;
      final x = (i * 40.0 + sin(animationValue * sparkleSpeed + i) * 50) % size.width;
      final y = size.height * 0.3 + cos(animationValue * sparkleSpeed * 0.7 + i) * 120;
      final sparkleSize = 0.5 + sin(animationValue * 3 + i) * 1.5;
      
      canvas.drawCircle(Offset(x, y), sparkleSize, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant EnhancedOceanPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.lightValue != lightValue;
  }
}

class ParticlePainter extends CustomPainter {
  final double animationValue;

  ParticlePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final particlePaint = Paint()..color = Colors.white.withOpacity(0.4);

    for (int i = 0; i < 20; i++) {
      final particleSpeed = 0.1 + (i % 4) * 0.05;
      final x = (i * 60.0 + cos(animationValue * particleSpeed + i) * 30) % size.width;
      final y = (i * 50.0 + sin(animationValue * particleSpeed * 0.8 + i) * 40) % size.height;
      final particleSize = 1.0 + sin(animationValue * 2 + i) * 0.5;
      
      canvas.drawCircle(Offset(x, y), particleSize, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class CloudPainter extends CustomPainter {
  final double animationValue;
  final double lightValue;

  CloudPainter(this.animationValue, this.lightValue);

  @override
  void paint(Canvas canvas, Size size) {
    final cloudColor = Color.lerp(
      Colors.white.withOpacity(0.2),
      Colors.orange.withOpacity(0.15),
      lightValue * 0.3,
    )!;

    for (int i = 0; i < 3; i++) {
      final cloudX = (size.width * animationValue * 0.05 + i * 200.0) % (size.width + 100);
      final cloudY = 50.0 + i * 30.0 + sin(animationValue + i) * 20.0;
      final cloudSize = 60.0 + i * 20.0;
      
      _drawCloud(canvas, cloudColor, Offset(cloudX, cloudY), cloudSize);
    }
  }

  void _drawCloud(Canvas canvas, Color color, Offset center, double size) {
    final cloudPaint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final cloudParts = [
      Offset(center.dx, center.dy),
      Offset(center.dx - size * 0.3, center.dy + size * 0.1),
      Offset(center.dx + size * 0.3, center.dy + size * 0.1),
      Offset(center.dx - size * 0.15, center.dy - size * 0.2),
      Offset(center.dx + size * 0.15, center.dy - size * 0.2),
    ];

    for (final part in cloudParts) {
      canvas.drawCircle(part, size * 0.3, cloudPaint);
    }
  }

  @override 
  bool shouldRepaint(covariant CloudPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.lightValue != lightValue;
  }
}