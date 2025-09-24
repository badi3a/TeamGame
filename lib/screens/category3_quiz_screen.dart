import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'quiz_island.dart';
import '../services/api_service.dart';
import '../services/symfony_service.dart';
import 'badge_system.dart'; // Import the badge system

// Add the completion result class
class QuizCompletionResult {
  final String categoryId;
  final double categoryScore;
  final double totalScore;
  final int islandId;

  QuizCompletionResult({
    required this.categoryId,
    required this.categoryScore,
    required this.totalScore,
    required this.islandId,
  });
}

class Category3QuizScreen extends StatefulWidget {
  final QuizIsland island;

  const Category3QuizScreen({
    Key? key, 
    required this.island,
  }) : super(key: key);

  @override
  State<Category3QuizScreen> createState() => _Category3QuizScreenState();
}

class _Category3QuizScreenState extends State<Category3QuizScreen>
    with TickerProviderStateMixin {
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late AnimationController _rotationController;
  late AnimationController _badgeController; // Badge animation controller
  late Animation<double> _fadeAnimation;
  late Animation<double> _bounceAnimation;

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

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

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

    _bounceAnimation = Tween<double>(
      begin: -5,
      end: 5,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
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
      
      print('🏝️ Category3: Loading questions for user document ID: $userDocumentId');
      print('🏝️ Category3: User email: $userEmail');
      print('🏝️ Category3: Island category ID: ${widget.island.categoryId}');
      
      if (userDocumentId == null || userDocumentId!.isEmpty) {
        throw Exception('User document ID not found. Please login again.');
      }
      
      // Use user-specific key for complete quiz data
      final userSpecificKey = _getUserSpecificKey('complete_quiz_data');
      final completeQuizData = prefs.getStringList(userSpecificKey) ?? [];
      
      print('🔍 Category3: Looking for quiz data with key: $userSpecificKey');
      print('🔍 Category3: Found ${completeQuizData.length} stored quizzes');
      
      Map<String, dynamic>? currentQuizData;
      
      for (String dataString in completeQuizData) {
        try {
          final quizData = Map<String, dynamic>.from(json.decode(dataString));
          print('🔍 Category3: Checking quiz ${quizData['idQuiz']} with categories: ${quizData['idCategory']}');
          
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
          
          print('🔍 Category3: Parsed category IDs: $categoryIds');
          print('🔍 Category3: Looking for category ID: ${widget.island.categoryId}');
          
          if (categoryIds.contains(widget.island.categoryId)) {
            currentQuizData = quizData;
            quizId = quizData['idQuiz']?.toString();
            print('✅ Category3: Found matching quiz with ID: $quizId');
            break;
          }
        } catch (e) {
          print('❌ Category3: Error parsing quiz data: $e');
          continue;
        }
      }

      if (quizId == null) {
        print('❌ Category3: No quiz found containing category ${widget.island.categoryId}');
        throw Exception('Quiz ID not found for category ${widget.island.categoryId}. Please try restarting the quiz from the quiz list.');
      }

      print('🔄 Category3: Loading questions for quiz: $quizId');

      final allQuestions = await ApiService.getQuizQuestions(quizId!);
      
      categoryQuestions = allQuestions.where((question) {
        return question['idCategory'] == widget.island.categoryId;
      }).toList();

      print('✅ Category3: Found ${categoryQuestions.length} questions for this category');

      if (categoryQuestions.isEmpty) {
        throw Exception('No questions found for this category');
      }

      setState(() {
        isLoading = false;
      });

      _fadeController.forward();

    } catch (e) {
      print('❌ Category3: Error loading questions: $e');
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bounceController.dispose();
    _rotationController.dispose();
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
      final answerValue = selectedAnswer! + 1;
      final questionId = categoryQuestions[currentQuestionIndex]['idQuestion'];
      
      print('📤 Category3: Submitting answer:');
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
        print('✅ Category3: Answer submitted successfully');
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
        throw Exception('Failed to submit answer');
      }
    } catch (e) {
      print('❌ Category3: Error submitting answer: $e');
      setState(() {
        isSubmitting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit answer: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeCategory() async {
    setState(() {
      isCalculatingScore = true;
    });

    try {
      print('🧮 Category3: Calculating score for quiz $quizId, user $userDocumentId');
      
      // Calculate the score for this quiz
      final scoreData = await ApiService.calculateScore(
        quizId: quizId!,
        userId: userDocumentId!,
      );

      if (scoreData != null) {
        print('✅ Category3: Score calculation successful');
        
        // Save completion status with user-specific key
        final prefs = await SharedPreferences.getInstance();
        final completedCategoriesKey = _getUserSpecificKey('completed_categories');
        final completedCategories = prefs.getStringList(completedCategoriesKey) ?? [];
        final categoryKey = '${quizId}_${widget.island.categoryId}';
        
        print('💾 Category3: Saving completion with key: $categoryKey');
        
        if (!completedCategories.contains(categoryKey)) {
          completedCategories.add(categoryKey);
          await prefs.setStringList(completedCategoriesKey, completedCategories);
          print('✅ Category3: Completion status saved');
        }

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

        print('📊 Category3: Category score: $categoryScore');

        setState(() {
          isCalculatingScore = false;
        });

        // NEW: Save badges after score calculation
        await _saveBadges(categoryScore, scoreData['totalScore'] ?? 0.0);

        // Create completion result for instant UI update
        final completionResult = QuizCompletionResult(
          categoryId: widget.island.categoryId!,
          categoryScore: categoryScore,
          totalScore: (scoreData['totalScore'] ?? 0.0).toDouble(),
          islandId: widget.island.id,
        );

        _showCompletionDialog(categoryScore, scoreData['totalScore'] ?? 0.0, completionResult);
      } else {
        throw Exception('Failed to calculate score');
      }
    } catch (e) {
      print('❌ Category3: Error calculating score: $e');
      setState(() {
        isCalculatingScore = false;
      });
      
      // Still show completion but without score
      _showCompletionDialog(0.0, 0.0, null);
    }
  }

  // NEW: Method to save badges
  Future<void> _saveBadges(double categoryScore, double totalScore) async {
    setState(() {
      isSavingBadges = true;
    });

    try {
      print('🏆 Category3: Saving badges for score: $categoryScore');
      
      // Get badges for the achieved score
      final earnedBadges = BadgeSystem.getBadgesForScore(categoryScore);
      
      if (earnedBadges.isNotEmpty) {
        print('🎯 Category3: Earned ${earnedBadges.length} badges');
        
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
            print('✅ Category3: Badges saved successfully to backend');
            
            // Also save locally for offline access
            await _saveBadgesLocally(earnedBadges, categoryScore);
            
          } else {
            print('❌ Category3: Failed to save badges to backend');
            // Still save locally as fallback
            await _saveBadgesLocally(earnedBadges, categoryScore);
          }
        } else {
          print('❌ Category3: Badge data validation failed');
        }
      } else {
        print('ℹ️ Category3: No badges earned for score: $categoryScore');
      }
      
    } catch (e) {
      print('❌ Category3: Error saving badges: $e');
      // Try to save locally as fallback
      try {
        final earnedBadges = BadgeSystem.getBadgesForScore(categoryScore);
        await _saveBadgesLocally(earnedBadges, categoryScore);
      } catch (localError) {
        print('❌ Category3: Failed to save badges locally: $localError');
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
      
      print('✅ Category3: Badges saved locally');
      
    } catch (e) {
      print('❌ Category3: Error saving badges locally: $e');
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
          borderRadius: BorderRadius.circular(25),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    widget.island.color,
                    widget.island.color.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.island.color.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Quest Complete!',
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
                'You conquered ${widget.island.name}!',
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
                        Icon(Icons.emoji_events, color: widget.island.color, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Adventure Score',
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
                      'Challenges completed: ${categoryQuestions.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
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
                        'Saving adventure achievements...',
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
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore, color: Colors.orange.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        earnedBadges.isNotEmpty 
                            ? 'Incredible achievements! Your adventure continues with the next island!'
                            : 'Amazing! Your adventure continues with the next island!',
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
          Container(
            width: double.infinity,
            child: TextButton(
              onPressed: isSavingBadges ? null : () {
                Navigator.pop(context); // Close dialog
                // Return immediately with completion result - triggers loading screen in islands map
                Navigator.pop(context, completionResult);
              },
              style: TextButton.styleFrom(
                backgroundColor: widget.island.color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: widget.island.color.withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                          'Securing Progress...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    )
                  : const Text(
                      'Back to Adventure Map',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.island.color.withOpacity(0.03),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.island.color,
                widget.island.color.withOpacity(0.8),
                widget.island.color.withOpacity(0.6),
              ],
            ),
          ),
        ),
        title: AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _bounceAnimation.value),
              child: Text(
                widget.island.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            );
          },
        ),
        centerTitle: true,
      ),
      body: isLoading 
          ? _buildLoadingScreen()
          : errorMessage != null 
              ? _buildErrorScreen()
              : (isCalculatingScore || isSavingBadges)
                  ? _buildCalculatingScoreScreen()
                  : _buildQuizContent(),
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
                  ? 'Calculating Adventure Score...'
                  : 'Saving Quest Achievements...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.island.color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isCalculatingScore
                  ? 'Evaluating your quest performance'
                  : 'Securing your adventure rewards',
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
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: widget.island.color.withOpacity(0.3),
                  blurRadius: 25,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * pi,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.island.color,
                              widget.island.color.withOpacity(0.6),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.explore,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Preparing adventure...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.island.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Adventure Error!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '$errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isLoading = true;
                        errorMessage = null;
                      });
                      _loadUserAndQuestions();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.island.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Rest of the quiz content build method with enhanced adventure styling...
  Widget _buildQuizContent() {
    return Column(
      children: [
        // Adventure progress section
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.island.color.withOpacity(0.1),
                widget.island.color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.island.color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.map, color: widget.island.color, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Challenge ${currentQuestionIndex + 1} of ${categoryQuestions.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.island.color, widget.island.color.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: widget.island.color.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${((currentQuestionIndex + 1) / categoryQuestions.length * 100).round()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade200,
                      Colors.grey.shade100,
                    ],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (currentQuestionIndex + 1) / categoryQuestions.length,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.island.color),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Question content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: widget.island.color.withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: 3,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                widget.island.color.withOpacity(0.2),
                                widget.island.color.withOpacity(0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.psychology_alt,
                            size: 45,
                            color: widget.island.color,
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(
                          categoryQuestions[currentQuestionIndex]['question'] ?? '',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Adventure answer selection
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.island.color.withOpacity(0.1),
                        widget.island.color.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: widget.island.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.explore, color: widget.island.color, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Choose your path:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.island.color,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 25),
                
                // Adventure circle options
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 3,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Adventure-themed scale labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.sentiment_very_dissatisfied, color: Colors.red.shade400, size: 24),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Strongly\nDisagree',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.sentiment_very_satisfied, color: Colors.green.shade400, size: 24),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Strongly\nAgree',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Adventure circle options
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (index) {
                          final isSelected = selectedAnswer == index;
                          
                          return GestureDetector(
                            onTap: isSubmitting ? null : () => _selectAnswer(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isSelected 
                                    ? RadialGradient(
                                        colors: [
                                          widget.island.color,
                                          widget.island.color.withOpacity(0.7),
                                        ],
                                      )
                                    : null,
                                color: isSelected ? null : Colors.white,
                                border: Border.all(
                                  color: isSelected 
                                      ? widget.island.color 
                                      : Colors.grey.shade300,
                                  width: isSelected ? 4 : 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: widget.island.color.withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 4,
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 22,
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
                      
                      const SizedBox(height: 20),
                      
                      // Enhanced number labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (index) {
                          return Container(
                            width: 60,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: selectedAnswer == index 
                                  ? widget.island.color.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
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
                
                const SizedBox(height: 30),
                
                // Adventure submit button
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: selectedAnswer != null 
                        ? [
                            BoxShadow(
                              color: widget.island.color.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton(
                    onPressed: selectedAnswer != null && !isSubmitting 
                        ? _submitAnswerAndProceed 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ).copyWith(
                      backgroundColor: MaterialStateProperty.all(Colors.transparent),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: selectedAnswer != null 
                              ? [
                                  widget.island.color,
                                  widget.island.color.withOpacity(0.8),
                                  widget.island.color.withOpacity(0.6),
                                ]
                              : [Colors.grey.shade400, Colors.grey.shade500, Colors.grey.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: isSubmitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Advancing...',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    currentQuestionIndex < categoryQuestions.length - 1
                                        ? Icons.explore
                                        : Icons.flag_outlined,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    selectedAnswer != null
                                        ? (currentQuestionIndex < categoryQuestions.length - 1
                                            ? 'Continue Adventure'
                                            : 'Complete Quest')
                                        : 'Choose your path',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ],
    );
  }
}