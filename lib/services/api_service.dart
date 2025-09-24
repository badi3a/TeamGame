import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class ApiService {
  // FastAPI backend for quiz data (port 8001)
  static const String baseUrl = 'http://127.0.0.1:8000'; 
  
  // For Android emulator, use: 'http://10.0.2.2:8001'
  // For iOS simulator, use: 'http://127.0.0.1:8001'  
  // For real device, use your computer's IP: 'http://192.168.1.XXX:8001'
  
  // Note: Symfony backend for user management runs on port 8000

  // Headers for requests
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Verify quiz access code
  static Future<Map<String, dynamic>?> verifyQuizCode(String accessCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/quizzes/access_code/$accessCode'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> quizData = json.decode(response.body);
        print('Quiz found: ${quizData['nameQuiz']}');
        return quizData;
      } else if (response.statusCode == 404) {
        print('Quiz not found for code: $accessCode');
        return null;
      } else {
        throw Exception('Failed to verify code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error verifying quiz code: $e');
      throw Exception('Failed to connect to backend: $e');
    }
  }

  // Get category by ID
  static Future<Map<String, dynamic>?> getCategoryById(String categoryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories/$categoryId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> categoryData = json.decode(response.body);
        print('Category loaded: ${categoryData['island']}');
        return categoryData;
      } else if (response.statusCode == 404) {
        print('Category not found: $categoryId');
        return null;
      } else {
        throw Exception('Failed to load category: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading category $categoryId: $e');
      throw Exception('Failed to connect to backend: $e');
    }
  }

  // Get all questions from FastAPI backend
  static Future<List<Map<String, dynamic>>> getQuestions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/questions/'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        
        // Convert the API response to match your current question format
        List<Map<String, dynamic>> questions = jsonData.map((item) => {
          'question': item['content'] ?? '',
          'idQuestion': item['idQuestion'] ?? '',
          'idQuiz': item['idQuiz'] ?? '',
          'idCategory': item['idCategory'] ?? '',
          'options': [], // No longer needed for personality test
          'correct': 0, // No longer needed for personality test
          'explanation': 'This is a sample question from your database.',
        }).toList();
        
        return questions;
      } else {
        throw Exception('Failed to load questions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to backend: $e');
    }
  }

  // Get questions by quiz ID
  static Future<List<Map<String, dynamic>>> getQuizQuestions(String quizId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/questions/by_quiz/$quizId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        
        List<Map<String, dynamic>> questions = jsonData.map((item) => {
          'question': item['content'] ?? '',
          'idQuestion': item['idQuestion'] ?? '',
          'idQuiz': item['idQuiz'] ?? '',
          'idCategory': item['idCategory'] ?? '',
          'options': [],
          'correct': 0,
          'explanation': 'This question was loaded from your FastAPI backend.',
        }).toList();
        
        return questions;
      } else {
        throw Exception('Failed to load quiz questions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load quiz questions: $e');
    }
  }

  // Get questions by island ID
  static Future<List<Map<String, dynamic>>> getQuestionsByIsland(String islandId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/quizzes/by_island/$islandId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        
        List<Map<String, dynamic>> allQuestions = [];
        for (var quiz in jsonData) {
          if (quiz['questions'] != null) {
            final List<dynamic> questions = quiz['questions'];
            allQuestions.addAll(_convertQuestionsFormat(questions));
          }
        }
        
        return allQuestions;
      } else {
        throw Exception('Failed to load island questions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load island questions: $e');
    }
  }

  // Helper method to convert questions to the expected format
  static List<Map<String, dynamic>> _convertQuestionsFormat(List<dynamic> questions) {
    return questions.map((item) => {
      'question': item['content'] ?? '',
      'idQuestion': item['idQuestion'] ?? '',
      'idQuiz': item['idQuiz'] ?? '',
      'idCategory': item['idCategory'] ?? '',
      'options': [], // No longer needed for personality test
      'correct': 0, // No longer needed for personality test
      'explanation': 'This question was loaded from your FastAPI backend.',
    }).toList();
  }

  // Submit an answer to the backend
  // NOTE: userId should now be the Firebase document ID, not email
  static Future<bool> submitAnswer({
    required String userId, // This should be the Firebase document ID
    required String quizId,
    required String questionId,
    required int value, // 1-5 scale value
  }) async {
    try {
      final requestBody = {
        'idUser': userId, // Now expects Firebase document ID
        'idQuiz': quizId,  
        'idQuestion': questionId,
        'value': value,
      };

      print('Submitting answer with body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/answers/'),
        headers: _headers,
        body: json.encode(requestBody),
      );

      print('Answer submission response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Answer submitted successfully: Question $questionId, Value: $value');
        return true;
      } else {
        print('Failed to submit answer: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error submitting answer: $e');
      return false;
    }
  }

  // NEW: Update island position after submitting answers
  static Future<Map<String, dynamic>?> updateIslandPosition({
    required String userId,
    required String quizId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/scores/update_island_position/$quizId/user/$userId'),
        headers: _headers,
      );

      print('Update island position response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Island position updated: ${data['island_position']}');
        return data;
      } else {
        print('Failed to update island position: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error updating island position: $e');
      return null;
    }
  }

  // Calculate final score for a quiz
  static Future<Map<String, dynamic>?> calculateScore({
    required String userId, // This should be the Firebase document ID
    required String quizId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/scores/calculate_score/$quizId/user/$userId'),
        headers: _headers,
      );

      print('Calculate score response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final scoreData = json.decode(response.body);
        print('Score calculated successfully: $scoreData');
        print('Island position: ${scoreData['island_position']}');
        return scoreData;
      } else {
        print('Failed to calculate score: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error calculating score: $e');
      return null;
    }
  }

  // Get user's score for a specific quiz (original method)
  static Future<Map<String, dynamic>?> getUserScore({
    required String userId, // This should be the Firebase document ID
    required String quizId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/scores/get_score/$quizId/user/$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Retrieved user score with island position: ${data['island_position']}');
        return data;
      } else {
        return null; // No score found
      }
    } catch (e) {
      print('Error getting user score: $e');
      return null;
    }
  }

  // Get score for a quiz and user (for progression system)
  static Future<Map<String, dynamic>?> getScore({
    required String quizId,
    required String userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/scores/get_score/$quizId/user/$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Retrieved score with island position: ${data['island_position']}');
        return data;
      } else if (response.statusCode == 404) {
        // Score not found, which is expected if not calculated yet
        return null;
      } else {
        print('Failed to get score: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting score: $e');
      return null;
    }
  }

  // Get all scores for a user
  static Future<List<Map<String, dynamic>>> getUserScores(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/scores/scores/user/$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final scores = List<Map<String, dynamic>>.from(data);
        for (var score in scores) {
          print('Score island position: ${score['island_position']}');
        }
        return scores;
      } else {
        print('Failed to get user scores: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting user scores: $e');
      return [];
    }
  }

  // Check if user has answered all questions for a category
  static Future<bool> isCategoryCompleted({
    required String quizId,
    required String userId,
    required String categoryId,
  }) async {
    try {
      // Get all questions for this category
      final allQuestions = await getQuizQuestions(quizId);
      final categoryQuestions = allQuestions.where((q) => q['idCategory'] == categoryId).toList();
      
      if (categoryQuestions.isEmpty) {
        return false;
      }

      // Check if user has answers for all questions in this category
      final response = await http.get(
        Uri.parse('$baseUrl/answers/by_quiz/$quizId/user/$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final answers = json.decode(response.body);
        final categoryAnswers = (answers as List).where((answer) => 
          categoryQuestions.any((q) => q['idQuestion'] == answer['idQuestion'])
        ).toList();

        final isCompleted = categoryAnswers.length == categoryQuestions.length;
        
        // If category is completed, update island position
        if (isCompleted) {
          await updateIslandPosition(userId: userId, quizId: quizId);
        }
        
        return isCompleted;
      } else if (response.statusCode == 404) {
        // No answers found
        return false;
      } else {
        print('Failed to check completion: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error checking category completion: $e');
      return false;
    }
  }
}