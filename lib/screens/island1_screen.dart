import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'quiz_island.dart';
import '../services/api_service.dart';

class Island1Screen extends StatefulWidget {
  final QuizIsland island;

  const Island1Screen({
    Key? key,
    required this.island,
  }) : super(key: key);

  @override
  State<Island1Screen> createState() => _Island1ScreenState();
}

class _Island1ScreenState extends State<Island1Screen> {
  // Core state
  int currentQuestionIndex = 0;
  int? selectedAnswer;
  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;
  
  // Data
  List<Map<String, dynamic>> questions = [];
  String? userId;
  String? quizId;

  @override
  void initState() {
    super.initState();
    print('🚀 Island1Screen initialized');
    _loadData();
  }

  Future<void> _loadData() async {
    print('📱 Loading data for Island 1');
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('profile_email') ?? 'anonymous_user';
      
      // Find quiz ID
      final completeQuizData = prefs.getStringList('complete_quiz_data') ?? [];
      for (String dataString in completeQuizData) {
        final quizData = Map<String, dynamic>.from(json.decode(dataString));
        final categoryIds = List<String>.from(quizData['idCategory'] ?? []);
        if (categoryIds.contains(widget.island.categoryId)) {
          quizId = quizData['idQuiz'];
          break;
        }
      }

      if (quizId == null) {
        throw Exception('Quiz not found');
      }

      // Load questions
      final allQuestions = await ApiService.getQuizQuestions(quizId!);
      questions = allQuestions.where((q) {
        return q['idCategory'] == widget.island.categoryId;
      }).toList();

      if (questions.isEmpty) {
        throw Exception('No questions found');
      }

      print('✅ Loaded ${questions.length} questions');
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  void _selectAnswer(int index) {
    print('👆 Answer selected: ${index + 1}');
    if (!isSubmitting) {
      HapticFeedback.lightImpact();
      setState(() {
        selectedAnswer = index;
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (selectedAnswer == null || isSubmitting) return;
    
    print('📤 Submitting answer: ${selectedAnswer! + 1}');
    setState(() {
      isSubmitting = true;
    });

    try {
      final success = await ApiService.submitAnswer(
        userId: userId!,
        quizId: quizId!,
        questionId: questions[currentQuestionIndex]['idQuestion'],
        value: selectedAnswer! + 1,
      );

      if (success) {
        print('✅ Answer submitted successfully');
        HapticFeedback.mediumImpact();
        
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (currentQuestionIndex < questions.length - 1) {
          setState(() {
            currentQuestionIndex++;
            selectedAnswer = null;
            isSubmitting = false;
          });
        } else {
          _showCompletionDialog();
        }
      }
    } catch (e) {
      print('❌ Submit error: $e');
      setState(() {
        isSubmitting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCompletionDialog() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Category Complete!'),
        content: Text('You completed ${widget.island.name} with ${questions.length} questions!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to islands
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🔄 Building Island1Screen - Loading: $isLoading, Error: $errorMessage');
    
    return WillPopScope(
      onWillPop: () async {
        return !isSubmitting; // Prevent back during submission
      },
      child: Scaffold(
        backgroundColor: widget.island.color.withOpacity(0.1),
        appBar: AppBar(
          backgroundColor: widget.island.color,
          title: Text(widget.island.name),
          centerTitle: true,
          elevation: 0,
        ),
        body: isLoading 
            ? _buildLoading()
            : errorMessage != null 
                ? _buildError()
                : _buildQuiz(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: widget.island.color,
          ),
          const SizedBox(height: 20),
          const Text('Loading questions...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              'Error: $errorMessage',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                _loadData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    final question = questions[currentQuestionIndex];
    final progress = (currentQuestionIndex + 1) / questions.length;
    
    return Column(
      children: [
        // Progress bar
        Container(
          height: 8,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(widget.island.color),
          ),
        ),
        
        // Progress text
        Container(
          padding: const EdgeInsets.all(16),
          color: widget.island.color.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${currentQuestionIndex + 1} of ${questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.island.color,
                ),
              ),
            ],
          ),
        ),
        
        // Question
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Question card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 40,
                          color: widget.island.color,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          question['question'] ?? 'No question text',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Answer options title
                Text(
                  'Select your answer:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.island.color,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Answer buttons - SIMPLE AND GUARANTEED TO WORK
                ...List.generate(5, (index) {
                  final labels = [
                    '1 - Strongly Disagree',
                    '2 - Disagree',
                    '3 - Neutral',
                    '4 - Agree',
                    '5 - Strongly Agree',
                  ];
                  
                  final isSelected = selectedAnswer == index;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting 
                            ? null 
                            : () {
                                print('🔘 Button ${index + 1} pressed');
                                _selectAnswer(index);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected 
                              ? widget.island.color 
                              : Colors.white,
                          foregroundColor: isSelected 
                              ? Colors.white 
                              : Colors.black87,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected 
                                  ? widget.island.color 
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          elevation: isSelected ? 4 : 1,
                        ),
                        child: Row(
                          children: [
                            // Number circle
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Colors.white 
                                    : widget.island.color.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected 
                                      ? Colors.white 
                                      : widget.island.color,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isSelected 
                                        ? widget.island.color 
                                        : widget.island.color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Label
                            Expanded(
                              child: Text(
                                labels[index],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            // Check icon if selected
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                
                const SizedBox(height: 30),
                
                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (selectedAnswer != null && !isSubmitting)
                        ? () {
                            print('🚀 Submit button pressed');
                            _submitAnswer();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.island.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: isSubmitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Submitting...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            currentQuestionIndex < questions.length - 1
                                ? 'Next Question →'
                                : 'Complete Quiz ✓',
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