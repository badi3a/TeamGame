import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'quiz_island.dart';
import '../services/api_service.dart';
import '../services/symfony_service.dart';
import 'badge_system.dart'; // Import the badge system

// UPDATED: Add the completion result class with quizId for proper isolation
class QuizCompletionResult {
  final String quizId;        // ADD: Quiz ID for proper isolation
  final String categoryId;
  final double categoryScore;
  final double totalScore;
  final int islandId;

  QuizCompletionResult({
    required this.quizId,      // REQUIRED: Quiz ID for isolation
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

class Category1QuizScreen extends StatefulWidget {
  final QuizIsland island;

  const Category1QuizScreen({
    Key? key, 
    required this.island,
  }) : super(key: key);

  @override
  State<Category1QuizScreen> createState() => _Category1QuizScreenState();
}

class _Category1QuizScreenState extends State<Category1QuizScreen>
    with TickerProviderStateMixin {
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _badgeController; // Badge animation controller
  late Animation<double> _fadeAnimation;

  // Quiz State
  int currentQuestionIndex = 0;
  int? selectedAnswer; // 0-4 for scale 1-5
  bool isLoading = true;
  bool isSubmitting = false;
  bool isCalculatingScore = false;
  bool isSavingBadges = false; // NEW: Track badge saving state
  String? errorMessage;
  
  // Data
  List<Map<String, dynamic>> categoryQuestions = [];
  String? userDocumentId;
  String? userEmail;
  String? quizId;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserAndQuestions();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Badge animation controller
    _badgeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
  }

  // Helper method to get user-specific keys for SharedPreferences
  String _getUserSpecificKey(String baseKey) {
    if (userDocumentId != null) {
      return '${baseKey}_${userDocumentId}';
    }
    return '${baseKey}_guest';
  }

  Future<void> _loadUserAndQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      userDocumentId = prefs.getString('user_document_id');
      userEmail = prefs.getString('profile_email') ?? 'anonymous_user';
      
      print('🏝️ Category1: Loading questions for user document ID: $userDocumentId');
      print('🏝️ Category1: User email: $userEmail');
      print('🏝️ Category1: Island category ID: ${widget.island.categoryId}');
      
      if (userDocumentId == null || userDocumentId!.isEmpty) {
        throw Exception('User document ID not found. Please login again.');
      }
      
      // Use user-specific key for complete quiz data
      final userSpecificKey = _getUserSpecificKey('complete_quiz_data');
      final completeQuizData = prefs.getStringList(userSpecificKey) ?? [];
      
      print('🔍 Category1: Looking for quiz data with key: $userSpecificKey');
      print('🔍 Category1: Found ${completeQuizData.length} stored quizzes');
      
      Map<String, dynamic>? currentQuizData;
      
      for (String dataString in completeQuizData) {
        try {
          final quizData = Map<String, dynamic>.from(json.decode(dataString));
          print('🔍 Category1: Checking quiz ${quizData['idQuiz']} with categories: ${quizData['idCategory']}');
          
          // Handle different formats of idCategory
          List<String> categoryIds = [];
          final categoryData = quizData['idCategory'];
          
          if (categoryData is List) {
            categoryIds = List<String>.from(categoryData);
          } else if (categoryData is String) {
            try {
              final decoded = json.decode(categoryData);
              if (decoded is List) {
                categoryIds = List<String>.from(decoded);
              } else {
                categoryIds = [categoryData];
              }
            } catch (e) {
              categoryIds = [categoryData];
            }
          } else if (categoryData != null) {
            categoryIds = [categoryData.toString()];
          }
          
          print('🔍 Category1: Parsed category IDs: $categoryIds');
          print('🔍 Category1: Looking for category ID: ${widget.island.categoryId}');
          
          if (categoryIds.contains(widget.island.categoryId)) {
            currentQuizData = quizData;
            quizId = quizData['idQuiz']?.toString();
            print('✅ Category1: Found matching quiz with ID: $quizId');
            break;
          }
        } catch (e) {
          print('❌ Category1: Error parsing quiz data: $e');
          continue;
        }
      }

      if (quizId == null) {
        print('❌ Category1: No quiz found containing category ${widget.island.categoryId}');
        print('🔍 Category1: Available quiz data:');
        for (String dataString in completeQuizData) {
          try {
            final quizData = json.decode(dataString);
            print('   - Quiz ${quizData['idQuiz']}: categories ${quizData['idCategory']}');
          } catch (e) {
            print('   - Invalid quiz data: $dataString');
          }
        }
        throw Exception('Quiz ID not found for category ${widget.island.categoryId}. Please try restarting the quiz from the quiz list.');
      }

      print('🔄 Category1: Loading questions for quiz: $quizId');

      final allQuestions = await ApiService.getQuizQuestions(quizId!);
      
      categoryQuestions = allQuestions.where((question) {
        final questionCategoryId = question['idCategory'];
        print('📝 Category1: Question ${question['idQuestion']} has category: $questionCategoryId');
        return questionCategoryId == widget.island.categoryId;
      }).toList();

      print('✅ Category1: Found ${categoryQuestions.length} questions for this category');

      if (categoryQuestions.isEmpty) {
        throw Exception('No questions found for this category');
      }

      setState(() {
        isLoading = false;
      });

      _fadeController.forward();

    } catch (e) {
      print('❌ Category1: Error loading questions: $e');
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _badgeController.dispose(); // Dispose badge controller
    super.dispose();
  }

  void _selectAnswer(int answerIndex) {
    if (isSubmitting) return;
    
    HapticFeedback.lightImpact();
    setState(() {
      selectedAnswer = answerIndex;
    });
  }

  Future<void> _submitAnswerAndProceed() async {
    if (selectedAnswer == null || isSubmitting || userDocumentId == null) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final answerValue = selectedAnswer! + 1; // Convert 0-4 to 1-5
      final questionId = categoryQuestions[currentQuestionIndex]['idQuestion'];
      
      print('📤 Category1: Submitting answer:');
      print('   - User Document ID: $userDocumentId');
      print('   - Quiz ID: $quizId');
      print('   - Question ID: $questionId');
      print('   - Answer Value: $answerValue');
      
      final success = await ApiService.submitAnswer(
        userId: userDocumentId!,
        quizId: quizId!,
        questionId: questionId,
        value: answerValue,
      );

      if (success) {
        print('✅ Category1: Answer submitted successfully');
        HapticFeedback.lightImpact();
        
        if (currentQuestionIndex < categoryQuestions.length - 1) {
          setState(() {
            currentQuestionIndex++;
            selectedAnswer = null;
            isSubmitting = false;
          });
          
          _fadeController.reset();
          _fadeController.forward();
        } else {
          setState(() {
            isSubmitting = false;
          });
          await _completeCategory();
        }
      } else {
        throw Exception('Failed to submit answer to server');
      }
    } catch (e) {
      print('❌ Category1: Error submitting answer: $e');
      setState(() {
        isSubmitting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit answer: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // UPDATED: Complete category with enhanced score verification and retry logic
  Future<void> _completeCategory() async {
    setState(() {
      isCalculatingScore = true;
    });

    try {
      print('🧮 Category1: Calculating score for quiz $quizId, user $userDocumentId');
      
      // ENHANCED: Calculate score with retry logic
      Map<String, dynamic>? scoreData;
      
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          print('🔄 Category1: Score calculation attempt $attempt/3');
          scoreData = await ApiService.calculateScore(
            quizId: quizId!,
            userId: userDocumentId!,
          );
          
          if (scoreData != null) {
            print('✅ Category1: Score calculation successful on attempt $attempt');
            break;
          } else {
            print('⚠️ Category1: No score data returned on attempt $attempt');
            if (attempt < 3) {
              await Future.delayed(Duration(milliseconds: 500 * attempt));
            }
          }
        } catch (e) {
          print('❌ Category1: Score calculation failed on attempt $attempt: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }

      if (scoreData != null) {
        print('✅ Category1: Score calculation successful');
        print('📊 Category1: Full score data: $scoreData');
        
        // ENHANCED: Immediate local storage saving with score caching
        await _saveCompletionStatusWithScore(scoreData);

        // Get the category score from the scoreData
        double categoryScore = 0.0;
        switch (widget.island.id) {
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

        print('📊 Category1: Category score: $categoryScore');
        print('📊 Category1: Total score: ${scoreData['totalScore']}');

        setState(() {
          isCalculatingScore = false;
        });

        // NEW: Save badges after score calculation
        await _saveBadges(categoryScore, scoreData['totalScore'] ?? 0.0);

        // UPDATED: Create completion result with quiz ID for proper isolation
        final completionResult = QuizCompletionResult(
          quizId: quizId!,                           // CRITICAL: Include quiz ID
          categoryId: widget.island.categoryId!,
          categoryScore: categoryScore,
          totalScore: (scoreData['totalScore'] ?? 0.0).toDouble(),
          islandId: widget.island.id,
        );

        print('🎉 Category1: Created completion result: ${completionResult.toString()}');
        print('🔑 Category1: Full category key: ${completionResult.fullCategoryKey}');

        _showCompletionDialog(categoryScore, scoreData['totalScore'] ?? 0.0, completionResult);
      } else {
        throw Exception('Failed to calculate score after 3 attempts');
      }
    } catch (e) {
      print('❌ Category1: Error calculating score: $e');
      setState(() {
        isCalculatingScore = false;
      });
      
      // UPDATED: Still provide completion result even without score for UI update
      final fallbackResult = QuizCompletionResult(
        quizId: quizId!,
        categoryId: widget.island.categoryId!,
        categoryScore: 0.0,
        totalScore: 0.0,
        islandId: widget.island.id,
      );
      
      _showCompletionDialog(0.0, 0.0, fallbackResult);
    }
  }

  // NEW: Enhanced completion status saving with score caching
  Future<void> _saveCompletionStatusWithScore(Map<String, dynamic> scoreData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedCategoriesKey = _getUserSpecificKey('completed_categories');
      final completedCategories = prefs.getStringList(completedCategoriesKey) ?? [];
      
      // CRITICAL: Use quiz-specific category key format
      final categoryKey = '${quizId}_${widget.island.categoryId}';
      
      print('💾 Category1: Saving completion with key: $categoryKey');
      print('💾 Category1: Existing completed categories: $completedCategories');
      
      if (!completedCategories.contains(categoryKey)) {
        completedCategories.add(categoryKey);
        await prefs.setStringList(completedCategoriesKey, completedCategories);
        print('✅ Category1: Completion status saved successfully');
        print('✅ Category1: Updated completed categories: $completedCategories');
      } else {
        print('ℹ️ Category1: Category already marked as completed');
      }

      // ENHANCED: Cache scores for immediate UI updates
      final scoresKey = _getUserSpecificKey('cached_scores');
      Map<String, double> cachedScores = {};
      
      // Load existing cached scores
      final existingScoresJson = prefs.getString(scoresKey);
      if (existingScoresJson != null) {
        try {
          final decoded = json.decode(existingScoresJson);
          cachedScores = Map<String, double>.from(decoded);
        } catch (e) {
          print('⚠️ Category1: Error loading existing cached scores: $e');
        }
      }
      
      // Add current category score
      final categoryScore = _getCurrentCategoryScore(scoreData);
      if (categoryScore > 0) {
        cachedScores[categoryKey] = categoryScore;
        
        // Save back to preferences
        await prefs.setString(scoresKey, json.encode(cachedScores));
        print('✅ Category1: Cached score saved: $categoryKey = $categoryScore');
      }
      
    } catch (e) {
      print('❌ Category1: Error saving completion status and score: $e');
    }
  }

  // Helper method to get current category score from score data
  double _getCurrentCategoryScore(Map<String, dynamic> scoreData) {
    switch (widget.island.id) {
      case 1:
        return (scoreData['scoreCategory1'] ?? 0.0).toDouble();
      case 2:
        return (scoreData['scoreCategory2'] ?? 0.0).toDouble();
      case 3:
        return (scoreData['scoreCategory3'] ?? 0.0).toDouble();
      case 4:
        return (scoreData['scoreCategory4'] ?? 0.0).toDouble();
      default:
        return 0.0;
    }
  }

  // NEW: Method to save badges
  Future<void> _saveBadges(double categoryScore, double totalScore) async {
    setState(() {
      isSavingBadges = true;
    });

    try {
      print('🏆 Category1: Saving badges for score: $categoryScore');
      
      // Get badges for the achieved score
      final earnedBadges = BadgeSystem.getBadgesForScore(categoryScore);
      
      if (earnedBadges.isNotEmpty) {
        print('🎯 Category1: Earned ${earnedBadges.length} badges');
        
        // Convert badges to API format
        final badgesForApi = earnedBadges.map((badge) {
          return {
            'name': badge.name,
            'icon': badge.icon,
            'description': badge.description,
            'color': SymfonyService.getColorHex(badge.color),
          };
        }).toList();
        
        // Validate badge data
        final isValid = SymfonyService.validateBadgeData(
          userId: userDocumentId!,
          badges: badgesForApi,
          categoryId: widget.island.categoryId!,
          score: categoryScore,
        );
        
        if (isValid) {
          // Save badges to backend
          final success = await SymfonyService.saveBadges(
            userId: userDocumentId!,
            badges: badgesForApi,
            categoryId: widget.island.categoryId!,
            score: categoryScore,
            quizId: quizId,
          );
          
          if (success) {
            print('✅ Category1: Badges saved successfully to backend');
            
            // Also save locally for offline access
            await _saveBadgesLocally(earnedBadges, categoryScore);
            
          } else {
            print('❌ Category1: Failed to save badges to backend');
            // Still save locally as fallback
            await _saveBadgesLocally(earnedBadges, categoryScore);
          }
        } else {
          print('❌ Category1: Badge data validation failed');
        }
      } else {
        print('ℹ️ Category1: No badges earned for score: $categoryScore');
      }
      
    } catch (e) {
      print('❌ Category1: Error saving badges: $e');
      // Try to save locally as fallback
      try {
        final earnedBadges = BadgeSystem.getBadgesForScore(categoryScore);
        await _saveBadgesLocally(earnedBadges, categoryScore);
      } catch (localError) {
        print('❌ Category1: Failed to save badges locally: $localError');
      }
    } finally {
      setState(() {
        isSavingBadges = false;
      });
    }
  }

  // NEW: Save badges locally as backup
  Future<void> _saveBadgesLocally(List<AchievementBadge> badges, double score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final badgesKey = _getUserSpecificKey('earned_badges');
      
      // Get existing badges
      final existingBadgesJson = prefs.getStringList(badgesKey) ?? [];
      final existingBadges = existingBadgesJson.map((json) => jsonDecode(json)).toList();
      
      // Create new badge record
      final badgeRecord = {
        'categoryId': widget.island.categoryId,
        'quizId': quizId,
        'score': score,
        'earnedAt': DateTime.now().toIso8601String(),
        'badges': badges.map((badge) => {
          'name': badge.name,
          'icon': badge.icon,
          'description': badge.description,
          'color': badge.color.toString(),
        }).toList(),
      };
      
      // Remove existing record for this category (if any)
      existingBadges.removeWhere((record) => 
        record['categoryId'] == widget.island.categoryId && 
        record['quizId'] == quizId
      );
      
      // Add new record
      existingBadges.add(badgeRecord);
      
      // Save back to preferences
      final badgesJsonList = existingBadges.map((badge) => jsonEncode(badge)).toList();
      await prefs.setStringList(badgesKey, badgesJsonList);
      
      print('✅ Category1: Badges saved locally');
      
    } catch (e) {
      print('❌ Category1: Error saving badges locally: $e');
    }
  }

  void _showCompletionDialog(double categoryScore, double totalScore, QuizCompletionResult? completionResult) {
    HapticFeedback.heavyImpact();
    
    // Get badges for the achieved score
    final earnedBadges = BadgeSystem.getBadgesForScore(categoryScore);
    
    // Start badge animation
    _badgeController.forward();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.island.color, widget.island.color.withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Category Complete!',
              style: TextStyle(
                color: widget.island.color,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Congratulations! You completed ${widget.island.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              
              // Category Score Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.island.color.withOpacity(0.1),
                      widget.island.color.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: widget.island.color.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, color: widget.island.color, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Your Score',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.island.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${categoryScore.toStringAsFixed(1)}/5.0',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: widget.island.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Questions answered: ${categoryQuestions.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Debug info (you can remove this in production)
              if (completionResult != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Debug: ${completionResult.fullCategoryKey}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade600,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Score cached for immediate UI update',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.green.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              
              // Badge Display with save status
              if (isSavingBadges) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Saving your achievements...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Badge Display - Shows earned badges
                BadgeSystem.buildAnimatedBadgeReveal(earnedBadges, _badgeController),
              ],
              
              const SizedBox(height: 15),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        earnedBadges.isNotEmpty 
                            ? 'Fantastic work! Your achievements have been saved and the next island is now unlocked!'
                            : 'Your answers have been saved and the next island is now unlocked!',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSavingBadges ? null : () {
                Navigator.pop(context); // Close dialog
                
                // CRITICAL: Return with completion result to trigger proper UI update
                print('🚀 Category1: Returning with completion result: ${completionResult?.toString()}');
                Navigator.pop(context, completionResult);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.island.color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: widget.island.color.withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSavingBadges
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Finalizing...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Continue to Next Island',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: widget.island.color,
      body: SafeArea(
        child: isLoading 
            ? _buildLoadingScreen()
            : errorMessage != null 
                ? _buildErrorScreen()
                : (isCalculatingScore || isSavingBadges)
                    ? _buildCalculatingScoreScreen()
                    : _buildQuizContent(screenHeight, screenWidth),
      ),
    );
  }

  Widget _buildCalculatingScoreScreen() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.island.color.withOpacity(0.3),
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
                gradient: LinearGradient(
                  colors: [widget.island.color, widget.island.color.withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCalculatingScore ? Icons.calculate : Icons.save,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isCalculatingScore 
                  ? 'Calculating Your Score...'
                  : 'Saving Your Achievements...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.island.color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isCalculatingScore
                  ? 'Please wait while we analyze your answers with retry protection'
                  : 'Securing your badges and progress locally & remotely',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(widget.island.color),
            ),
            const SizedBox(height: 15),
            // Show additional status info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.island.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: widget.island.color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.security, color: widget.island.color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    isCalculatingScore 
                        ? 'Enhanced score calculation in progress'
                        : 'Caching scores for instant UI updates',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.island.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading questions...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            'Quiz: $quizId',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            'Category: ${widget.island.categoryId}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            'User: $userEmail',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              errorMessage ?? 'Error loading questions',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: widget.island.color,
              ),
              child: const Text('Back'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                _loadUserAndQuestions();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: widget.island.color,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizContent(double screenHeight, double screenWidth) {
    return Column(
      children: [
        // Compact Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.island.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Question ${currentQuestionIndex + 1} of ${categoryQuestions.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        
        // Progress Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 4,
          child: LinearProgressIndicator(
            value: (currentQuestionIndex + 1) / categoryQuestions.length,
            backgroundColor: Colors.white30,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Question Card
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.psychology,
                          size: 40,
                          color: widget.island.color,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          categoryQuestions[currentQuestionIndex]['question'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Circle Answer Options
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Rate your response:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Scale labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Strongly\nDisagree',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Strongly\nAgree',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Circle options
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (index) {
                          final isSelected = selectedAnswer == index;
                          
                          return GestureDetector(
                            onTap: isSubmitting ? null : () => _selectAnswer(index),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected 
                                    ? widget.island.color 
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected 
                                      ? widget.island.color 
                                      : Colors.grey.shade300,
                                  width: isSelected ? 3 : 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: widget.island.color.withOpacity(0.4),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.2),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected 
                                        ? Colors.white 
                                        : widget.island.color,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      
                      const SizedBox(height: 15),
                      
                      // Number labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (index) {
                          return SizedBox(
                            width: 50,
                            child: Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: selectedAnswer == index 
                                    ? widget.island.color 
                                    : Colors.grey.shade500,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: selectedAnswer != null && !isSubmitting 
                        ? _submitAnswerAndProceed 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: widget.island.color,
                      disabledBackgroundColor: Colors.white54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: selectedAnswer != null ? 4 : 0,
                    ),
                    child: isSubmitting
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.island.color
                              ),
                            ),
                          )
                        : Text(
                            selectedAnswer != null
                                ? (currentQuestionIndex < categoryQuestions.length - 1 
                                    ? 'Next Question' 
                                    : 'Complete')
                                : 'Select an answer',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}