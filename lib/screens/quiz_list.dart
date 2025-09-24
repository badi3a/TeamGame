import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttermoji/fluttermoji.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/quiz.dart';
import '../services/api_service.dart';
import 'profile_screen.dart';
import 'quiz_code_entry_screen.dart';
import 'islands_map_screen.dart';

class QuizListScreen extends StatefulWidget {
  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  List<Quiz> quizList = []; // Start with empty list
  String _userName = '';
  String _userEmail = '';
  String? _userDocumentId;
  bool _isLoading = false;
  bool _isLoadingQuizzes = true;

  // Replace with your actual Symfony server URL
  static const String _baseUrl = 'http://127.0.0.1:8001'; // Change this to your server URL

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('profile_name') ?? 'User';
      _userEmail = prefs.getString('profile_email') ?? '';
      _userDocumentId = prefs.getString('user_document_id');
    });
    
    // Load quizzes after we have user info
    await _loadQuizzes();
    
    // Check quiz accessibility status after loading
    await _updateQuizStatusBasedOnAccessibility();
  }

  // UPDATED: Enhanced getUserSpecificKey to support quiz-specific keys when needed
  String _getUserSpecificKey(String baseKey, {String? quizId}) {
    if (_userDocumentId != null) {
      if (quizId != null) {
        return '${baseKey}_${_userDocumentId}_${quizId}';
      }
      return '${baseKey}_${_userDocumentId}';
    }
    return '${baseKey}_guest';
  }

  Future<void> _loadQuizzes() async {
    setState(() {
      _isLoadingQuizzes = true;
    });

    try {
      if (_userDocumentId != null) {
        // Try to load from backend first
        await _loadQuizzesFromBackend();
      } else {
        // If no user ID, show empty state
        setState(() {
          quizList = [];
        });
      }
    } catch (e) {
      print('Error loading quizzes: $e');
      // Fallback to local storage
      await _loadQuizzesFromLocal();
    } finally {
      setState(() {
        _isLoadingQuizzes = false;
      });
    }
  }

  Future<void> _loadQuizzesFromBackend() async {
    try {
      print('🔄 Loading quizzes from backend for user: $_userDocumentId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/load-quiz-list/$_userDocumentId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<String> backendQuizzes = List<String>.from(responseData['quizList'] ?? []);
        
        print('✅ Loaded ${backendQuizzes.length} quizzes from backend for user $_userDocumentId');
        
        setState(() {
          quizList = backendQuizzes.map((quizJson) {
            final parts = quizJson.split('|');
            if (parts.length >= 4) {
              // Parse status if available, otherwise default to pending
              QuizStatus status = QuizStatus.pending;
              if (parts.length >= 5) {
                try {
                  // Parse the status from string
                  final statusString = parts[4];
                  status = QuizStatus.values.firstWhere(
                    (e) => e.toString() == statusString,
                    orElse: () => QuizStatus.pending,
                  );
                } catch (e) {
                  print('⚠️ Error parsing status for quiz ${parts[0]}: $e');
                  status = QuizStatus.pending;
                }
              }
              
              return Quiz(
                id: parts[0],
                title: parts[1],
                expiryDate: DateTime.parse(parts[2]),
                duration: int.parse(parts[3]),
                status: status, // Use the restored status (will be updated by accessibility check)
              );
            }
            return null;
          }).where((quiz) => quiz != null).cast<Quiz>().toList();
        });

        // Also sync to user-specific local storage for offline access
        await _saveQuizzesToLocal();
      } else {
        print('⚠️ Failed to load quizzes from backend: ${response.statusCode}');
        await _loadQuizzesFromLocal();
      }
    } catch (e) {
      print('❌ Error loading quizzes from backend: $e');
      await _loadQuizzesFromLocal();
    }
  }

  Future<void> _loadQuizzesFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final userSpecificKey = _getUserSpecificKey('user_quizzes');
    final storedQuizzes = prefs.getStringList(userSpecificKey) ?? [];
    
    print('📱 Loading ${storedQuizzes.length} quizzes from local storage for user $_userDocumentId');
    
    setState(() {
      quizList = storedQuizzes.map((quizJson) {
        final parts = quizJson.split('|');
        if (parts.length >= 4) {
          // Parse status if available, otherwise default to pending
          QuizStatus status = QuizStatus.pending;
          if (parts.length >= 5) {
            try {
              // Parse the status from string
              final statusString = parts[4];
              status = QuizStatus.values.firstWhere(
                (e) => e.toString() == statusString,
                orElse: () => QuizStatus.pending,
              );
            } catch (e) {
              print('⚠️ Error parsing status for quiz ${parts[0]}: $e');
              status = QuizStatus.pending;
            }
          }
          
          return Quiz(
            id: parts[0],
            title: parts[1],
            expiryDate: DateTime.parse(parts[2]),
            duration: int.parse(parts[3]),
            status: status, // Use the restored status (will be updated by accessibility check)
          );
        }
        return null;
      }).where((quiz) => quiz != null).cast<Quiz>().toList();
    });
  }

  // Update quiz status based on isAccessible from complete quiz data
  Future<void> _updateQuizStatusBasedOnAccessibility() async {
    bool hasChanges = false;
    
    for (int i = 0; i < quizList.length; i++) {
      final quiz = quizList[i];
      
      // Skip if already completed
      if (quiz.status == QuizStatus.done) {
        continue;
      }
      
      // Get complete quiz data to check isAccessible
      final completeQuizData = await _getCompleteQuizData(quiz.id);
      
      if (completeQuizData != null) {
        final isAccessible = completeQuizData['isAccessible'] ?? true;
        final newStatus = isAccessible ? QuizStatus.pending : QuizStatus.expired;
        
        if (quiz.status != newStatus) {
          print('🔄 Updating quiz "${quiz.title}" status from ${quiz.status} to $newStatus based on isAccessible: $isAccessible');
          
          setState(() {
            quizList[i] = Quiz(
              id: quiz.id,
              title: quiz.title,
              expiryDate: quiz.expiryDate,
              duration: quiz.duration,
              status: newStatus,
            );
          });
          hasChanges = true;
        }
      }
    }
    
    if (hasChanges) {
      await _saveQuizzes();
      print('✅ Quiz statuses updated based on isAccessible values');
    }
  }

  Future<void> _saveQuizzes() async {
    // Save to both local and backend
    await _saveQuizzesToLocal();
    if (_userDocumentId != null) {
      await _saveQuizzesToBackend();
    }
  }

  Future<void> _saveQuizzesToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final userSpecificKey = _getUserSpecificKey('user_quizzes');
    final quizStrings = quizList.map((quiz) {
      // Include status in the saved string
      return '${quiz.id}|${quiz.title}|${quiz.expiryDate.toIso8601String()}|${quiz.duration}|${quiz.status.toString()}';
    }).toList();
    await prefs.setStringList(userSpecificKey, quizStrings);
    print('💾 Saved ${quizStrings.length} quizzes to local storage for user $_userDocumentId');
  }

  Future<void> _saveQuizzesToBackend() async {
    try {
      print('💾 Saving quizzes to backend for user: $_userDocumentId');
      
      final quizStrings = quizList.map((quiz) {
        // Include status in the saved string
        return '${quiz.id}|${quiz.title}|${quiz.expiryDate.toIso8601String()}|${quiz.duration}|${quiz.status.toString()}';
      }).toList();

      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/save-quiz-list/$_userDocumentId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'quizList': quizStrings,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Quizzes saved to backend successfully for user $_userDocumentId');
      } else {
        print('⚠️ Failed to save quizzes to backend: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error saving quizzes to backend: $e');
    }
  }

  // Method to update quiz status
  void _updateQuizStatus(String quizId, QuizStatus newStatus) {
    setState(() {
      final quizIndex = quizList.indexWhere((quiz) => quiz.id == quizId);
      if (quizIndex != -1) {
        // Create a new Quiz object with updated status
        final oldQuiz = quizList[quizIndex];
        quizList[quizIndex] = Quiz(
          id: oldQuiz.id,
          title: oldQuiz.title,
          expiryDate: oldQuiz.expiryDate,
          duration: oldQuiz.duration,
          status: newStatus,
        );
      }
    });
    
    // Save the updated list
    _saveQuizzes();
  }

  // Mark quiz as completed
  void _markQuizAsCompleted(String quizId) {
    _updateQuizStatus(quizId, QuizStatus.done);
  }

  // UPDATED: Save complete quiz data with better organization
  Future<void> _saveCompleteQuizData(Map<String, dynamic> quizData) async {
    final prefs = await SharedPreferences.getInstance();
    final userSpecificKey = _getUserSpecificKey('complete_quiz_data');
    final existingData = prefs.getStringList(userSpecificKey) ?? [];
    
    // Store as JSON string
    final quizJson = json.encode(quizData);
    
    // Check if already exists for this user - use the actual quiz ID for comparison
    final quizId = quizData['idQuiz']?.toString();
    bool exists = false;
    int existingIndex = -1;
    
    if (quizId != null) {
      for (int i = 0; i < existingData.length; i++) {
        try {
          final stored = json.decode(existingData[i]);
          if (stored['idQuiz']?.toString() == quizId) {
            exists = true;
            existingIndex = i;
            break;
          }
        } catch (e) {
          continue;
        }
      }
    }
    
    if (exists && existingIndex >= 0) {
      // Update existing quiz data
      existingData[existingIndex] = quizJson;
      print('🔄 Updated complete quiz data for quiz ID: $quizId, user: $_userDocumentId');
    } else if (!exists) {
      // Add new quiz data
      existingData.add(quizJson);
      print('💾 Saved complete quiz data for quiz ID: $quizId, user: $_userDocumentId');
    }
    
    await prefs.setStringList(userSpecificKey, existingData);
    
    // Also save to backend if user is logged in
    if (_userDocumentId != null) {
      await _saveCompleteQuizDataToBackend(existingData);
    }
  }

  Future<void> _saveCompleteQuizDataToBackend(List<String> completeQuizData) async {
    try {
      print('💾 Saving complete quiz data to backend for user $_userDocumentId');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/save-quiz-progress/$_userDocumentId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'completedCategories': [], // Will be handled separately
          'completeQuizData': completeQuizData,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Complete quiz data saved to backend successfully for user $_userDocumentId');
      } else {
        print('⚠️ Failed to save complete quiz data to backend: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error saving complete quiz data to backend: $e');
    }
  }

  // UPDATED: Enhanced quiz data retrieval with better debugging
  Future<Map<String, dynamic>?> _getCompleteQuizData(String quizId) async {
    final prefs = await SharedPreferences.getInstance();
    final userSpecificKey = _getUserSpecificKey('complete_quiz_data');
    final existingData = prefs.getStringList(userSpecificKey) ?? [];
    
    print('🔍 Looking for quiz data with ID: $quizId');
    print('📊 Total quiz data entries for user: ${existingData.length}');
    
    for (int i = 0; i < existingData.length; i++) {
      try {
        final quizData = json.decode(existingData[i]);
        final storedQuizId = quizData['idQuiz']?.toString();
        
        print('   - Entry $i: Quiz ID = $storedQuizId');
        
        if (storedQuizId != null && storedQuizId == quizId) {
          print('✅ Found matching quiz data for ID: $quizId');
          return Map<String, dynamic>.from(quizData);
        }
      } catch (e) {
        print('❌ Error parsing quiz data entry $i: $e');
        continue;
      }
    }
    
    print('❌ No quiz data found for ID: $quizId');
    return null;
  }

  Future<void> _addQuizFromCode() async {
    // Navigate to code entry screen and wait for result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QuizCodeEntryScreen(),
      ),
    );
    
    if (result != null && result is Map<String, dynamic>) {
      // Code was verified successfully, add the quiz
      await _addVerifiedQuiz(result);
    }
  }

  Future<void> _addVerifiedQuiz(Map<String, dynamic> quizData) async {
    try {
      print('📝 Adding verified quiz with data: ${quizData.keys.toList()}');
      
      // Ensure we have a valid quiz ID
      final quizId = quizData['idQuiz'];
      if (quizId == null) {
        throw Exception('Quiz data is missing idQuiz field');
      }
      
      print('📝 Quiz ID from API: $quizId');
      print('📝 isAccessible: ${quizData['isAccessible']}');
      
      // Check if quiz already exists for this user
      bool alreadyExists = quizList.any(
        (quiz) => quiz.id == quizId.toString(),
      );

      if (!alreadyExists) {
        // Determine status based on isAccessible
        final isAccessible = quizData['isAccessible'] ?? true;
        final quizStatus = isAccessible ? QuizStatus.pending : QuizStatus.expired;
        
        // Create new Quiz object from API data - use the actual quiz ID
        final newQuiz = Quiz(
          id: quizId.toString(), // Always use the actual quiz ID from API
          title: quizData['nameQuiz'] ?? 'Unknown Quiz',
          expiryDate: _parseDate(quizData['dateCreation']) ?? DateTime.now().add(const Duration(days: 30)),
          duration: 15, // Default duration, you can get this from API if available
          status: quizStatus, // Status based on isAccessible
        );

        print('📝 Created new Quiz object with ID: ${newQuiz.id}, Status: ${newQuiz.status} (isAccessible: $isAccessible)');

        setState(() {
          quizList.add(newQuiz);
        });

        // Save both quiz list and complete quiz data for this user
        await _saveQuizzes();
        await _saveCompleteQuizData(quizData);

        // Show success message
        final statusMessage = isAccessible ? "Ready to start!" : "Currently not accessible";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isAccessible ? Icons.check_circle : Icons.info,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🎉 Quiz added: ${newQuiz.title}'),
                      Text(
                        statusMessage,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: isAccessible ? const Color(0xFF4CAF50) : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // Quiz already exists for this user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Quiz "${quizData['nameQuiz']}" is already in your list.')),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error adding quiz: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding quiz: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  DateTime? _parseDate(dynamic dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr.toString());
    } catch (e) {
      return null;
    }
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    bool confirmed = await _showLogoutConfirmDialog();
    if (!confirmed) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // First, sync all data to backend before logout
      if (_userDocumentId != null) {
        print('🔄 Syncing data to backend before logout...');
        
        // Save quiz list to backend
        await _saveQuizzesToBackend();
        
        // Save quiz progress to backend
        await _syncProgressToBackend();
        
        // Call backend logout endpoint
        // NOTE: This will NOT change isloggedin to false, it only tracks logout time
        final response = await http.post(
          Uri.parse('$_baseUrl/api/auth/logout/$_userDocumentId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        );
        
        if (response.statusCode == 200) {
          print('✅ User logged out on backend successfully (isloggedin remains true)');
        } else {
          print('⚠️ Failed to logout on backend: ${response.statusCode}');
        }
      }
      
      // Clear local user session data but keep user-specific quiz data
      final prefs = await SharedPreferences.getInstance();
      
      // Remove only user session data
      await prefs.remove('user_document_id');
      await prefs.remove('profile_email');
      await prefs.remove('profile_firstname');
      await prefs.remove('profile_lastname');
      await prefs.remove('profile_name');
      await prefs.remove('profile_gender');
      await prefs.remove('profile_role');
      await prefs.remove('profile_classe');
      await prefs.remove('profile_age');
      await prefs.remove('profile_date_of_birth');
      await prefs.remove('profile_nationality');
      await prefs.remove('profile_photo');
      
      // Keep user-specific quiz data - it will be accessible when they log back in
      // The isloggedin status in Firebase remains TRUE so they'll go directly to quiz list
      // await prefs.remove(_getUserSpecificKey('user_quizzes')); // Don't remove this
      // await prefs.remove(_getUserSpecificKey('complete_quiz_data')); // Don't remove this  
      // await prefs.remove(_getUserSpecificKey('completed_categories')); // Don't remove this
      
      print('✅ Local session data cleared, user-specific quiz data preserved');
      print('🔔 isloggedin status remains TRUE in Firebase for returning user detection');
      
      // Show logout success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.logout, color: Colors.white),
                SizedBox(width: 10),
                Text('Logged out successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Navigate to login screen and clear navigation stack
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      print('❌ Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error logging out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // UPDATED: Enhanced sync progress method with quiz-specific handling
  Future<void> _syncProgressToBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedCategoriesKey = _getUserSpecificKey('completed_categories');
      final completeQuizDataKey = _getUserSpecificKey('complete_quiz_data');
      
      final completedCategories = prefs.getStringList(completedCategoriesKey) ?? [];
      final completeQuizData = prefs.getStringList(completeQuizDataKey) ?? [];
      
      print('🔄 Syncing progress to backend for user $_userDocumentId:');
      print('   - Completed categories: ${completedCategories.length}');
      print('   - Complete quiz data entries: ${completeQuizData.length}');
      
      // Debug: Show categories by quiz
      final categoriesByQuiz = <String, List<String>>{};
      for (final category in completedCategories) {
        if (category.contains('_')) {
          final quizId = category.split('_')[0];
          categoriesByQuiz[quizId] = categoriesByQuiz[quizId] ?? [];
          categoriesByQuiz[quizId]!.add(category);
        }
      }
      
      print('📊 Categories by quiz:');
      categoriesByQuiz.forEach((quizId, categories) {
        print('   - Quiz $quizId: ${categories.length} completed categories');
      });
      
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
        print('✅ Progress synced to backend successfully for user $_userDocumentId');
      } else {
        print('⚠️ Failed to sync progress to backend: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error syncing progress to backend: $e');
    }
  }

  Future<bool> _showLogoutConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Color(0xFFD32F2F)),
              SizedBox(width: 10),
              Text('Logout'),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout? Your quiz data will be saved and you\'ll go directly to the quiz list when you log back in.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Add the drawer property
      drawer: _buildDrawer(context),
      // Add floating action button
      floatingActionButton: FloatingActionButton(
        onPressed: _addQuizFromCode,
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
        tooltip: 'Add Quiz with Code',
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xFFFFE5E5),
              Color.fromARGB(255, 134, 24, 24),
              Color(0xFF1A1A1A),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              _buildAnimatedBackground(context),
              Column(
                children: [
                  AppBar(
                    title: const Text("📚 My Quizzes",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    centerTitle: true,
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),
                  Expanded(
                    child: _isLoadingQuizzes
                        ? _buildLoadingState()
                        : quizList.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: quizList.length,
                                itemBuilder: (context, index) {
                                  final quiz = quizList[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: _buildQuizCard(context, quiz, index),
                                  );
                                },
                              ),
                  ),
                ],
              ),
              
              // Loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "Loading Your Quizzes...",
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "Syncing with your account",
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.quiz_outlined,
              size: 80,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "No Quizzes Yet",
            style: TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Get started by adding your first quiz with an access code from your instructor.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _addQuizFromCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFD32F2F),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 8,
            ),
            icon: const Icon(Icons.add, size: 24),
            label: const Text(
              "Add Quiz with Code",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Updated method to build the drawer with logout
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD32F2F),
              Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: Column(
          children: [
            // Drawer Header with user info
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userName.isNotEmpty ? _userName : 'Quiz App',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_userEmail.isNotEmpty)
                    Text(
                      _userEmail,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    const Text(
                      'Student Portal',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
            ),
            
            // Expanded area for menu items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Profile Option
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      title: const Text(
                        'Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 16,
                      ),
                      onTap: () async {
                        Navigator.pop(context); // Close the drawer
                        await _navigateToProfile(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Add Quiz Option
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white70,
                        size: 28,
                      ),
                      title: const Text(
                        'Add Quiz',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white54,
                        size: 16,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _addQuizFromCode();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Sync Data Option
  
                  // Settings Option
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white70,
                        size: 28,
                      ),
                      title: const Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white54,
                        size: 16,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Settings coming soon!'),
                            backgroundColor: Color(0xFFD32F2F),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // About Option
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: Colors.white70,
                        size: 28,
                      ),
                      title: const Text(
                        'About',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white54,
                        size: 16,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showAboutDialog(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Logout button at the bottom
            Container(
              margin: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.red.withOpacity(0.2),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: 28,
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white70,
                    size: 16,
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close drawer first
                    _logout();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add sync all data method
  Future<void> _syncAllData() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 10),
              Text('Syncing data...'),
            ],
          ),
          backgroundColor: Color(0xFFD32F2F),
          duration: Duration(seconds: 2),
        ),
      );

      if (_userDocumentId != null) {
        // Sync quiz list
        await _saveQuizzesToBackend();
        
        // Sync progress
        await _syncProgressToBackend();

        // Update quiz status based on accessibility after sync
        await _updateQuizStatusBasedOnAccessibility();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Data synced successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to sync data'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error syncing data. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to navigate to profile screen
  Future<void> _navigateToProfile(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
    // Reload user info when returning from profile
    _loadUserInfo();
  }

  // Optional: Show about dialog
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About Quiz App'),
          content: const Text(
            'This is a quiz application where you can take various assessments and track your progress. Your data is automatically synced to the cloud.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedBackground(BuildContext context) {
    return Stack(
      children: [
        ...List.generate(8, (index) {
          final colors = [
            const Color(0xFFD32F2F).withOpacity(0.15),
            Colors.black.withOpacity(0.05),
            const Color(0xFFC62828).withOpacity(0.12),
            const Color(0xFFB71C1C).withOpacity(0.1),
          ];
          
          return Positioned(
            top: (index * 130.0) % MediaQuery.of(context).size.height,
            left: (index * 180.0) % MediaQuery.of(context).size.width,
            child: Container(
              width: 60 + (index * 15.0),
              height: 60 + (index * 15.0),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    colors[index % colors.length],
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildQuizCard(BuildContext context, Quiz quiz, int index) {
    final statusColor = {
      QuizStatus.pending: const Color(0xFFFFA000), // Amber
      QuizStatus.done: const Color(0xFF4CAF50),   // Green
      QuizStatus.expired: const Color(0xFFD32F2F), // Red
    };

    final statusText = {
      QuizStatus.pending: "🕒 Ready to Start",
      QuizStatus.done: "✅ Completed",
      QuizStatus.expired: "⏰ Not Accessible",
    };

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white.withOpacity(0.9),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (quiz.status == QuizStatus.pending) {
            _startQuiz(context, quiz);
          } else if (quiz.status == QuizStatus.expired) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This quiz is currently not accessible'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      quiz.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Color(0xFF1A1A1A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor[quiz.status]!.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor[quiz.status]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          statusText[quiz.status]!,
                          style: TextStyle(
                            color: statusColor[quiz.status],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteQuiz(index, quiz);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Remove Quiz'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.timer, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 4),
                  Text(
                    "${quiz.duration} min",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(quiz.expiryDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (quiz.status == QuizStatus.pending)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _startQuiz(context, quiz),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.explore, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          "Start Adventure",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (quiz.status == QuizStatus.expired)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null, // Disabled button
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.block, color: Colors.white70),
                        SizedBox(width: 8),
                        Text(
                          "Not Accessible",
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  void _deleteQuiz(int index, Quiz quiz) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Remove Quiz'),
          ],
        ),
        content: Text('Are you sure you want to remove "${quiz.title}" from your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                quizList.removeAt(index);
              });
              await _saveQuizzes();
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${quiz.title} removed from your list'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: Enhanced start quiz method with better debugging
  void _startQuiz(BuildContext context, Quiz quiz) async {
    print('🚀 Starting quiz with ID: ${quiz.id}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sailing, color: Colors.white),
            const SizedBox(width: 10),
            Text("🚀 Launching ${quiz.title}..."),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    // Get complete quiz data for this user
    final completeQuizData = await _getCompleteQuizData(quiz.id);
    
    if (completeQuizData == null) {
      print('❌ No complete quiz data found for quiz ID: ${quiz.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Quiz data not found. Please try adding the quiz again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('✅ Found complete quiz data for quiz ID: ${quiz.id}');
    print('📊 Quiz data keys: ${completeQuizData.keys.toList()}');

    Future.delayed(const Duration(milliseconds: 1500), () {
      // Navigate to islands map with complete quiz data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IslandsMapScreen(quizData: completeQuizData),
        ),
      ).then((_) {
        // Refresh progress when returning from islands
        _syncProgressFromIslands();
      });
    });
  }

  // UPDATED: Method to sync progress when returning from islands with debugging
  Future<void> _syncProgressFromIslands() async {
    print('🔄 Syncing progress after returning from islands...');
    
    // The islands screen should handle saving progress locally with user-specific keys
    // We just need to sync it to backend if user is logged in
    if (_userDocumentId != null) {
      await _syncProgressToBackend();
      
      // Also refresh quiz list to show any status changes
      await _loadQuizzes();
      print('✅ Quiz list refreshed after islands return');
    }
  }
}