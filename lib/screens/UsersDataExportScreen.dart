import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html; // For web downloads
import '../services/api_service.dart';

class UsersDataExportScreen extends StatefulWidget {
  const UsersDataExportScreen({Key? key}) : super(key: key);

  @override
  State<UsersDataExportScreen> createState() => _UsersDataExportScreenState();
}

class _UsersDataExportScreenState extends State<UsersDataExportScreen>
    with TickerProviderStateMixin {
  
  static const String _symfonyUrl = 'http://127.0.0.1:8001'; // Symfony backend for users
  static const String _pythonUrl = 'http://127.0.0.1:8000'; // Python backend for scores
  
  // Animation Controllers
  late AnimationController _loadingController;
  late AnimationController _exportController;
  late Animation<double> _loadingAnimation;
  late Animation<double> _exportAnimation;
  
  // State variables
  bool _isLoadingUsers = false;
  bool _isExporting = false;
  String _loadingMessage = '';
  String _exportMessage = '';
  
  List<Map<String, dynamic>> _allUsersData = [];
  List<String> _availableQuizIds = [];
  String? _selectedQuizId;
  int _totalUsersFound = 0;
  int _processedUsers = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAvailableQuizzes();
  }

  void _initializeAnimations() {
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _loadingAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));

    _exportController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _exportAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _exportController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _exportController.dispose();
    super.dispose();
  }

  // Load available quiz IDs from Python backend
  Future<void> _loadAvailableQuizzes() async {
    try {
      // Get available quizzes from Python backend
      final response = await http.get(
        Uri.parse('$_pythonUrl/api/quizzes/available'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final quizzes = List<Map<String, dynamic>>.from(responseData['quizzes'] ?? []);
        
        setState(() {
          _availableQuizIds = quizzes.map((quiz) => quiz['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
        });
        
        print('✅ Loaded ${_availableQuizIds.length} available quizzes: $_availableQuizIds');
      } else {
        print('⚠️ Failed to load quizzes from Python backend, using fallback');
        // Fallback to some default quiz IDs
        setState(() {
          _availableQuizIds = ['Quiz1', 'Quiz2', 'Quiz3', 'Quiz4', 'Quiz5'];
        });
      }
    } catch (e) {
      print('❌ Error loading quiz IDs: $e');
      // Fallback to some default quiz IDs  
      setState(() {
        _availableQuizIds = ['Quiz1', 'Quiz2', 'Quiz3', 'Quiz4', 'Quiz5'];
      });
      _showErrorSnackBar('Failed to load available quizzes, using defaults');
    }
  }

  // Fetch user profile data from Symfony backend
  Future<Map<String, dynamic>?> _fetchUserProfileData(String userId) async {
    try {
      print('🔄 Fetching user profile data from Symfony for: $userId');
      
      final response = await http.get(
        Uri.parse('$_symfonyUrl/api/auth/user-profile/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        
        // Create normalized data with user_id included
        final normalizedData = {
          'user_id': userId,
          'first_name': userData['firstname'] ?? 'Unknown',
          'last_name': userData['lastname'] ?? 'User',
          'gender': userData['sexe'] ?? 'Not specified',
          'age': userData['age']?.toString() ?? 
                 _calculateAgeFromDOB(userData['dateOfBirth']) ?? 
                 '0',
          'nationality': userData['nationality'] ?? 'Not specified',
          'class': userData['classe'] ?? 'Not specified',
        };
        
        return normalizedData;
      } else {
        print('❌ Failed to fetch user profile for $userId: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching user profile for $userId: $e');
      return null;
    }
  }

  // Calculate age from date of birth (reusing logic from islands map screen)
  String? _calculateAgeFromDOB(String? dobString) {
    if (dobString == null || dobString.isEmpty) {
      return null;
    }
    
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int age = now.year - dob.year;
      
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age = age - 1;
      }
      
      return age.toString();
    } catch (e) {
      print('⚠️ Error calculating age from DOB "$dobString": $e');
      return null;
    }
  }

  // Fetch user scores from Python backend
  Future<Map<String, double>?> _fetchUserScores(String userId, String quizId) async {
    try {
      print('🎯 Fetching scores from Python backend for user: $userId, quiz: $quizId');
      
      // Call Python backend to get scores
      final response = await http.get(
        Uri.parse('$_pythonUrl/api/scores/user/$userId/quiz/$quizId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final scoreData = json.decode(response.body);
        
        return {
          'creativity': (scoreData['scoreCategory1'] ?? 0.0).toDouble(),    // Island 1
          'teamwork': (scoreData['scoreCategory2'] ?? 0.0).toDouble(),      // Island 2
          'hard_skills': (scoreData['scoreCategory3'] ?? 0.0).toDouble(),   // Island 3
          'soft_skills': (scoreData['scoreCategory4'] ?? 0.0).toDouble(),   // Island 4
          'total_score': (scoreData['totalScore'] ?? 0.0).toDouble(),
        };
      } else if (response.statusCode == 404) {
        print('⚠️ No scores found for user $userId, quiz $quizId');
        return null;
      } else {
        print('❌ Failed to fetch scores: ${response.statusCode}');
        return null;
      }
      
    } catch (e) {
      print('❌ Error fetching scores for user $userId, quiz $quizId: $e');
      return null;
    }
  }

  // Get users who have completed a specific quiz from Symfony backend
  Future<List<Map<String, dynamic>>> _getUsersByQuiz(String quizId) async {
    try {
      print('🔍 Searching for users with quiz from Symfony: $quizId');
      
      // Call Symfony backend to get users filtered by quiz in userQuizzes field
      final response = await http.get(
        Uri.parse('$_symfonyUrl/api/auth/users-by-quiz/$quizId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return List<Map<String, dynamic>>.from(responseData['users'] ?? []);
      } else if (response.statusCode == 404) {
        print('⚠️ No users found for quiz $quizId');
        return [];
      } else {
        print('❌ Error response: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching users by quiz from Symfony: $e');
      return [];
    }
  }

  // Alternative method: Get all users from Symfony and filter client-side (fallback)
  Future<List<Map<String, dynamic>>> _getAllUsersAndFilter(String quizId) async {
    try {
      print('🔄 Fallback: Getting all users from Symfony and filtering for quiz $quizId');
      
      final response = await http.get(
        Uri.parse('$_symfonyUrl/api/auth/all-users-with-quizzes'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 20));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final allUsers = List<Map<String, dynamic>>.from(responseData['users'] ?? []);
        
        // Filter users who have the target quiz in their userQuizzes field
        final filteredUsers = <Map<String, dynamic>>[];
        
        for (final user in allUsers) {
          final userQuizzesString = user['userQuizzes']?.toString() ?? '';
          if (userQuizzesString.isNotEmpty) {
            // Check if the quiz ID appears in the userQuizzes string
            if (userQuizzesString.contains('|$quizId|') || 
                userQuizzesString.contains('$quizId|')) {
              
              // Parse the quiz info
              final quizInfo = _parseUserQuizzes(userQuizzesString, quizId);
              if (quizInfo != null) {
                // Add quiz info to user data
                user['parsed_quiz_info'] = quizInfo;
                filteredUsers.add(user);
                print('✅ Found user ${user['id'] ?? user['user_id']} with quiz $quizId');
              }
            }
          }
        }
        
        print('🎯 Filtered ${filteredUsers.length} users with quiz $quizId');
        return filteredUsers;
      } else {
        print('❌ Failed to get all users from Symfony: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error in fallback method: $e');
      return [];
    }
  }

  // Parse userQuizzes string to extract quiz information
  Map<String, dynamic>? _parseUserQuizzes(String userQuizzesString, String targetQuizId) {
    try {
      // userQuizzes format: "RQIALTIccH9o7XZThPi2|Quiz1|2025-07-28T13:05:33.038Z|15|QuizStatus.pending"
      final parts = userQuizzesString.split('|');
      
      if (parts.length >= 5) {
        final quizId = parts[1]; // Quiz1
        final timestamp = parts[2]; // 2025-07-28T13:05:33.038Z
        final someNumber = parts[3]; // 15
        final status = parts[4]; // QuizStatus.pending
        
        // Check if this matches our target quiz
        if (quizId == targetQuizId) {
          return {
            'quiz_id': quizId,
            'timestamp': timestamp,
            'number': someNumber,
            'status': status,
            'raw_string': userQuizzesString,
          };
        }
      }
      return null;
    } catch (e) {
      print('❌ Error parsing userQuizzes string: $e');
      return null;
    }
  }

  // Load all users data for the selected quiz (updated for userQuizzes field)
  Future<void> _loadAllUsersData() async {
    if (_selectedQuizId == null) {
      _showErrorSnackBar('Please select a quiz first');
      return;
    }

    setState(() {
      _isLoadingUsers = true;
      _loadingMessage = 'Searching for users with quiz ${_selectedQuizId}...';
      _allUsersData.clear();
      _totalUsersFound = 0;
      _processedUsers = 0;
    });

    try {
      // Try to get users by quiz first
      List<Map<String, dynamic>> usersWithQuiz = await _getUsersByQuiz(_selectedQuizId!);
      
      // If no users found or endpoint doesn't exist, try fallback method
      if (usersWithQuiz.isEmpty) {
        print('⚠️ No users found via quiz endpoint, trying fallback method...');
        setState(() {
          _loadingMessage = 'Searching all users for quiz ${_selectedQuizId}...';
        });
        usersWithQuiz = await _getAllUsersAndFilter(_selectedQuizId!);
      }

      if (usersWithQuiz.isEmpty) {
        setState(() {
          _isLoadingUsers = false;
          _loadingMessage = '';
        });
        _showErrorSnackBar('No users found with quiz ${_selectedQuizId}');
        return;
      }

      setState(() {
        _totalUsersFound = usersWithQuiz.length;
        _loadingMessage = 'Processing user data (0/${_totalUsersFound})...';
      });

      print('📊 Found ${usersWithQuiz.length} users with quiz ${_selectedQuizId}');

      // Process each user
      for (int i = 0; i < usersWithQuiz.length; i++) {
        final userWithQuiz = usersWithQuiz[i];
        
        setState(() {
          _processedUsers = i + 1;
          _loadingMessage = 'Processing user data (${_processedUsers}/${_totalUsersFound})...';
        });

        try {
          // Extract user ID (could be 'id' or 'user_id' depending on your backend)
          final userId = userWithQuiz['id']?.toString() ?? 
                        userWithQuiz['user_id']?.toString() ?? 
                        'unknown_${i+1}';
          
          print('🔄 Processing user: $userId');

          // Get user profile data (either from the response or fetch separately)
          Map<String, dynamic>? userProfile;
          
          if (userWithQuiz.containsKey('firstname') && userWithQuiz.containsKey('lastname')) {
            // User profile data is already included in the response
            userProfile = {
              'user_id': userId,
              'first_name': userWithQuiz['firstname'] ?? 'Unknown',
              'last_name': userWithQuiz['lastname'] ?? 'User',
              'gender': userWithQuiz['sexe'] ?? 'Not specified',
              'age': userWithQuiz['age']?.toString() ?? 
                     _calculateAgeFromDOB(userWithQuiz['dateOfBirth']) ?? 
                     '0',
              'nationality': userWithQuiz['nationality'] ?? 'Not specified',
              'class': userWithQuiz['classe'] ?? 'Not specified',
            };
          } else {
            // Need to fetch user profile separately
            userProfile = await _fetchUserProfileData(userId);
          }

          if (userProfile == null) {
            print('⚠️ Skipping user $userId - no profile data');
            continue;
          }

          // Fetch user scores for the selected quiz
          final scores = await _fetchUserScores(userId, _selectedQuizId!);
          
          // Get quiz status from parsed userQuizzes if available
          String quizStatus = 'unknown';
          String quizTimestamp = '';
          
          if (userWithQuiz.containsKey('parsed_quiz_info')) {
            final quizInfo = userWithQuiz['parsed_quiz_info'] as Map<String, dynamic>;
            quizStatus = quizInfo['status']?.toString() ?? 'unknown';
            quizTimestamp = quizInfo['timestamp']?.toString() ?? '';
          }
          
          // Combine user data with scores and quiz info
          final userData = {
            ...userProfile,
            'hard_skills': scores?['hard_skills']?.toStringAsFixed(2) ?? '0.00',
            'soft_skills': scores?['soft_skills']?.toStringAsFixed(2) ?? '0.00',
            'teamwork': scores?['teamwork']?.toStringAsFixed(2) ?? '0.00',
            'creativity': scores?['creativity']?.toStringAsFixed(2) ?? '0.00',
            'total_score': scores?['total_score']?.toStringAsFixed(2) ?? '0.00',
            'quiz_id': _selectedQuizId!,
            'quiz_status': quizStatus,
            'quiz_timestamp': quizTimestamp,
            'export_timestamp': DateTime.now().toIso8601String(),
          };

          _allUsersData.add(userData);
          print('✅ Added user data for: ${userProfile['first_name']} ${userProfile['last_name']} (Status: $quizStatus)');

        } catch (e) {
          print('❌ Error processing user at index $i: $e');
          continue;
        }

        // Small delay to prevent overwhelming the server
        await Future.delayed(Duration(milliseconds: 50));
      }

      setState(() {
        _isLoadingUsers = false;
        _loadingMessage = '';
      });

      print('✅ Successfully loaded data for ${_allUsersData.length} users with quiz ${_selectedQuizId}');
      
      if (_allUsersData.isNotEmpty) {
        _showSuccessSnackBar('Loaded data for ${_allUsersData.length} users with quiz ${_selectedQuizId}');
      } else {
        _showErrorSnackBar('No complete user data found for quiz ${_selectedQuizId}');
      }

    } catch (e) {
      setState(() {
        _isLoadingUsers = false;
        _loadingMessage = '';
      });
      
      print('❌ Error loading users data for quiz ${_selectedQuizId}: $e');
      _showErrorSnackBar('Failed to load users data: ${e.toString()}');
    }
  }

  // Generate and download CSV (reusing logic from CollectiveCSVManager)
  Future<void> _exportToCSV() async {
    if (_allUsersData.isEmpty) {
      _showErrorSnackBar('No user data to export. Please load data first.');
      return;
    }

    setState(() {
      _isExporting = true;
      _exportMessage = 'Preparing CSV data...';
    });

    _exportController.forward();

    try {
      print('📊 Starting CSV export for ${_allUsersData.length} users');

      setState(() {
        _exportMessage = 'Generating CSV structure...';
      });

      // Prepare CSV data with user_id as first column (same structure as CollectiveCSVManager)
      List<List<dynamic>> csvData = [
        // Header row with user_id as first column
        [
          'user_id',
          'first_name', 
          'last_name', 
          'gender', 
          'age', 
          'nationality', 
          'hard_skills', 
          'soft_skills', 
          'teamwork', 
          'creativity', 
          'class',
          'total_score',
          'quiz_id',
          'quiz_status',
          'quiz_timestamp',
          'export_timestamp'
        ],
      ];

      setState(() {
        _exportMessage = 'Processing user data...';
      });

      // Add each user's data as a row
      for (int i = 0; i < _allUsersData.length; i++) {
        final user = _allUsersData[i];
        final row = [
          user['user_id']?.toString().trim() ?? 'unknown_user_${i+1}',
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
          user['total_score']?.toString() ?? '0.00',
          user['quiz_id']?.toString() ?? _selectedQuizId ?? 'unknown',
          user['quiz_status']?.toString() ?? 'unknown',
          user['quiz_timestamp']?.toString() ?? '',
          user['export_timestamp']?.toString() ?? DateTime.now().toIso8601String(),
        ];
        csvData.add(row);
      }

      setState(() {
        _exportMessage = 'Converting to CSV format...';
      });

      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvData);

      setState(() {
        _exportMessage = 'Downloading CSV file...';
      });

      // Generate filename
      final timestamp = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd_HH-mm-ss').format(timestamp);
      final filename = 'all_users_data_quiz_${_selectedQuizId}_${_allUsersData.length}_users_$formattedDate.csv';

      // Download CSV (web only for now)
      if (kIsWeb) {
        await _downloadCSVForWeb(csvString, filename);
      } else {
        throw Exception('CSV export currently only supported on web platform');
      }

      setState(() {
        _isExporting = false;
        _exportMessage = '';
      });

      _showSuccessSnackBar('✅ CSV exported successfully: $filename');
      
      print('✅ CSV export completed successfully');
      print('📊 Exported ${_allUsersData.length} users to $filename');

    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportMessage = '';
      });
      
      print('❌ Error exporting CSV: $e');
      _showErrorSnackBar('Failed to export CSV: ${e.toString()}');
    }
  }

  // Download CSV for web platform (same logic as CollectiveCSVManager)
  Future<void> _downloadCSVForWeb(String csvString, String filename) async {
    try {
      print('🌐 Starting web CSV download');
      print('🌐 Filename: $filename');
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
      
      print('✅ Web CSV download completed successfully');
      
    } catch (e) {
      print('❌ Error in web CSV download: $e');
      throw e;
    }
  }

  // Helper methods for showing messages
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.white,
              Colors.green.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.download, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Users Data Export',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Quiz Selection Card
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.quiz, color: Colors.blue.shade600),
                                  SizedBox(width: 12),
                                  Text(
                                    'Select Quiz',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _selectedQuizId,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  prefixIcon: Icon(Icons.quiz_outlined),
                                ),
                                hint: Text('Choose a quiz to export data for'),
                                items: _availableQuizIds.map((quizId) {
                                  return DropdownMenuItem(
                                    value: quizId,
                                    child: Text('Quiz $quizId'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedQuizId = value;
                                    _allUsersData.clear(); // Clear previous data
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Data Status Card
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.people, color: Colors.green.shade600),
                                  SizedBox(width: 12),
                                  Text(
                                    'Data Status',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              
                              if (_isLoadingUsers) ...[
                                AnimatedBuilder(
                                  animation: _loadingAnimation,
                                  builder: (context, child) {
                                    return Column(
                                      children: [
                                        LinearProgressIndicator(
                                          value: _totalUsersFound > 0 
                                              ? _processedUsers / _totalUsersFound 
                                              : null,
                                          backgroundColor: Colors.grey.shade300,
                                          color: Colors.blue.shade600,
                                        ),
                                        SizedBox(height: 12),
                                        Transform.scale(
                                          scale: _loadingAnimation.value,
                                          child: Text(
                                            _loadingMessage,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ] else ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Users Loaded:',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _allUsersData.isEmpty 
                                            ? Colors.grey.shade100 
                                            : Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${_allUsersData.length}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _allUsersData.isEmpty 
                                              ? Colors.grey.shade600 
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingUsers || _isExporting || _selectedQuizId == null
                                  ? null
                                  : _loadAllUsersData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 8,
                              ),
                              icon: _isLoadingUsers
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(Icons.refresh),
                              label: Text(
                                _isLoadingUsers ? 'Loading...' : 'Load All Users',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingUsers || _isExporting || _allUsersData.isEmpty
                                  ? null
                                  : _exportToCSV,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 8,
                              ),
                              icon: _isExporting
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(Icons.download),
                              label: Text(
                                _isExporting ? 'Exporting...' : 'Export CSV',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_isExporting) ...[
                        SizedBox(height: 20),
                        AnimatedBuilder(
                          animation: _exportAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _exportAnimation.value,
                              child: Card(
                                color: Colors.green.shade50,
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      CircularProgressIndicator(
                                        color: Colors.green.shade600,
                                        strokeWidth: 3,
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Exporting Data',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              _exportMessage,
                                              style: TextStyle(
                                                color: Colors.green.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      // Users Preview (if data loaded)
                      if (_allUsersData.isNotEmpty && !_isLoadingUsers && !_isExporting) ...[
                        SizedBox(height: 20),
                        Expanded(
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(15),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.preview, color: Colors.grey.shade600),
                                      SizedBox(width: 8),
                                      Text(
                                        'Data Preview (${_allUsersData.length} users)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: EdgeInsets.all(8),
                                    itemCount: _allUsersData.length,
                                    itemBuilder: (context, index) {
                                      final user = _allUsersData[index];
                                      return Card(
                                        margin: EdgeInsets.symmetric(vertical: 2),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.blue.shade100,
                                            child: Text(
                                              '${user['first_name']?[0] ?? '?'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            '${user['first_name']} ${user['last_name']}',
                                            style: TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          subtitle: Text(
                                            'Total Score: ${user['total_score']} | Class: ${user['class']}',
                                          ),
                                          trailing: Text(
                                            'ID: ${user['user_id']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}