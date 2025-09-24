import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../avatar/avatar_maker_screen.dart';
import '../screens/signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  // Replace with your actual Symfony server URL
  static const String _baseUrl = 'http://127.0.0.1:8001'; // Change this to your server URL
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _logoController;
  late AnimationController _cardFlipController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _logoController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _cardFlipController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_rotationController);
    
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_waveController);
    
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _slideController.forward();
    _fadeController.forward();
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
    _logoController.forward();
    _cardFlipController.repeat();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _logoController.dispose();
    _cardFlipController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Helper method to get user-specific keys for SharedPreferences
  String _getUserSpecificKey(String baseKey, String userId) {
    return '${baseKey}_$userId';
  }

  // Updated Flutter login method to work with the new StudentLoginController and load saved data
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare login data
      final loginData = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      };

      print('🔐 Starting login process for: ${_emailController.text.trim()}');

      // Step 1: Authenticate user credentials with new controller
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/student-login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(loginData),
      );

      print('📡 Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Success response
        final responseData = json.decode(response.body);
        final userData = responseData['user'];
        
        // Get user document ID
        final userId = userData['id'];
        if (userId == null || userId.isEmpty) {
          throw Exception('User ID not found in response');
        }
        
        print('✅ User authenticated successfully. User ID: $userId');
        
        // Step 2: Save user data locally first
        await _saveUserDataLocally(userData, userId);
        
        // Step 3: Check real-time login status from Firebase with retry logic
        print('🔍 Checking real-time login status...');
        bool isCurrentlyLoggedIn = false;
        bool statusCheckSuccessful = false;
        
        // Try to get status with retry logic
        for (int attempt = 1; attempt <= 3; attempt++) {
          print('📡 Status check attempt $attempt/3');
          
          final statusResponse = await http.get(
            Uri.parse('$_baseUrl/api/auth/check-login-status/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          );
          
          if (statusResponse.statusCode == 200) {
            final statusData = json.decode(statusResponse.body);
            isCurrentlyLoggedIn = statusData['isloggedin'] ?? false;
            statusCheckSuccessful = true;
            print('✅ Real-time login status retrieved (attempt $attempt): $isCurrentlyLoggedIn');
            break;
          } else {
            print('⚠️ Status check failed (attempt $attempt): ${statusResponse.statusCode}');
            if (attempt < 3) {
              // Wait before retry
              await Future.delayed(Duration(milliseconds: 500 * attempt));
            }
          }
        }
        
        // Fallback to response data if status check failed
        if (!statusCheckSuccessful) {
          print('⚠️ Using fallback login status from response data');
          isCurrentlyLoggedIn = userData['isloggedin'] ?? false;
        }
        
        // Determine if this is first login based on real-time status
        // isloggedin = false: User has NEVER logged in before → First time → Avatar Maker
        // isloggedin = true:  User has logged in before → Returning user → Quiz List
        bool isFirstLogin = !isCurrentlyLoggedIn;
        
        print('📊 Login status analysis:');
        print('  - Real-time isloggedin: $isCurrentlyLoggedIn');
        print('  - Is first login: $isFirstLogin');
        print('  - User will go to: ${isFirstLogin ? 'Avatar Maker' : 'Quiz List'}');
        print('  - Note: isloggedin tracks "has ever logged in" not current session');
        
        // Step 4: Handle login status update and data loading
        if (isFirstLogin) {
          print('🔄 First login detected, updating isloggedin to true (PERMANENT)...');
          bool updateSuccess = await _updateIsLoggedInStatusWithRetry(userId);
          if (updateSuccess) {
            print('✅ Login status updated successfully (will NEVER go back to false)');
          } else {
            print('⚠️ Warning: Could not update login status, but continuing...');
          }
        } else {
          // Load saved quiz data and progress (only for returning users)
          print('📥 Loading saved user data for returning user...');
          await _loadSavedUserDataWithUserSpecificKeys(userId);
        }
        
        // Step 5: Show success message and navigate
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome ${isFirstLogin ? '' : 'back'}, ${userData['firstname'] ?? 'User'}!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Small delay to let the snackbar show
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (isFirstLogin) {
            // First time login - go to Avatar Designer
            print('🎯 Navigating to Avatar Maker (First login - real-time isloggedin was false)');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AvatarMakerScreen()),
            );
          } else {
            // Subsequent logins - go directly to Quiz List
            print('🎯 Navigating to Quiz List (Returning user - real-time isloggedin was true)');
            Navigator.pushReplacementNamed(context, '/listquiz');
          }
        }
      } else {
        // Handle error responses
        await _handleLoginError(response);
      }
    } on http.ClientException catch (e) {
      print('🌐 Network error: $e');
      if (mounted) {
        _showErrorDialog('Network error. Please check your internet connection.');
      }
    } catch (e) {
      print('❌ Login error: $e');
      if (mounted) {
        _showErrorDialog('An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Method to permanently set isloggedin to true (never goes back to false)
  Future<bool> _updateIsLoggedInStatusWithRetry(String userId) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('🔄 PERMANENTLY updating isloggedin to true for user: $userId (attempt $attempt/3)');
        print('📌 Note: Once true, this will NEVER be set back to false, even on logout');
        
        final updateData = {
          'isloggedin': true,
        };

        final response = await http.patch(
          Uri.parse('$_baseUrl/api/auth/update-login-status/$userId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(updateData),
        );

        print('📡 Update response status (attempt $attempt): ${response.statusCode}');

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          print('✅ Login status PERMANENTLY updated to true on attempt $attempt');
          print('📅 Update timestamp: ${responseData['timestamp']}');
          return true;
        } else {
          print('⚠️ Failed to update login status on attempt $attempt: ${response.statusCode}');
          print('⚠️ Response: ${response.body}');
          
          if (attempt < 3) {
            // Wait before retry
            await Future.delayed(Duration(milliseconds: 1000 * attempt));
          }
        }
      } catch (e) {
        print('❌ Error updating login status (attempt $attempt): $e');
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 1000 * attempt));
        }
      }
    }
    
    return false;
  }

  // Updated method to load saved user data with user-specific keys
  Future<void> _loadSavedUserDataWithUserSpecificKeys(String userId) async {
    try {
      print('📥 Loading saved user data for returning user: $userId');
      
      // Load quiz list from backend
      await _loadQuizListFromBackendWithUserSpecificKeys(userId);
      
      // Load quiz progress from backend
      await _loadQuizProgressFromBackendWithUserSpecificKeys(userId);
      
      print('✅ All saved data loaded successfully with user-specific keys');
      
    } catch (e) {
      print('⚠️ Error loading saved data: $e');
      // Don't block login if data loading fails
    }
  }

  // Load quiz list from backend with user-specific local storage
  Future<void> _loadQuizListFromBackendWithUserSpecificKeys(String userId) async {
    try {
      print('📋 Loading quiz list from backend...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/load-quiz-list/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<String> backendQuizzes = List<String>.from(responseData['quizList'] ?? []);
        
        print('✅ Loaded ${backendQuizzes.length} quizzes from backend');
        
        // Save to user-specific local storage for immediate access
        final prefs = await SharedPreferences.getInstance();
        final userSpecificKey = _getUserSpecificKey('user_quizzes', userId);
        await prefs.setStringList(userSpecificKey, backendQuizzes);
        print('💾 Saved quiz list to user-specific local storage: $userSpecificKey');
        
      } else {
        print('⚠️ Failed to load quiz list from backend: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading quiz list from backend: $e');
    }
  }

  // Load quiz progress from backend with user-specific local storage
  Future<void> _loadQuizProgressFromBackendWithUserSpecificKeys(String userId) async {
    try {
      print('📈 Loading quiz progress from backend...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/load-quiz-progress/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<String> completedCategories = List<String>.from(responseData['completedCategories'] ?? []);
        final List<String> completeQuizData = List<String>.from(responseData['completeQuizData'] ?? []);
        
        print('✅ Loaded ${completedCategories.length} completed categories from backend');
        print('✅ Loaded ${completeQuizData.length} complete quiz data entries from backend');
        
        // Save to user-specific local storage for immediate access
        final prefs = await SharedPreferences.getInstance();
        final completedCategoriesKey = _getUserSpecificKey('completed_categories', userId);
        final completeQuizDataKey = _getUserSpecificKey('complete_quiz_data', userId);
        
        await prefs.setStringList(completedCategoriesKey, completedCategories);
        await prefs.setStringList(completeQuizDataKey, completeQuizData);
        
        print('💾 Saved progress to user-specific local storage:');
        print('  - $completedCategoriesKey');
        print('  - $completeQuizDataKey');
        
      } else {
        print('⚠️ Failed to load quiz progress from backend: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading quiz progress from backend: $e');
    }
  }

  // Helper method to save user data locally
  Future<void> _saveUserDataLocally(Map<String, dynamic> userData, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    
    print('💾 Saving user data locally for user: $userId');
    
    // Save the Firebase document ID
    await prefs.setString('user_document_id', userId);
    
    // Save user data
    await prefs.setString('profile_email', userData['email'] ?? '');
    await prefs.setString('profile_firstname', userData['firstname'] ?? '');
    await prefs.setString('profile_lastname', userData['lastname'] ?? '');
    await prefs.setString('profile_name', '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}');
    await prefs.setString('profile_gender', userData['sexe'] ?? '');
    await prefs.setString('profile_role', userData['userRole'] ?? '');
    await prefs.setString('profile_classe', userData['classe'] ?? '');
    
    // Save optional fields
    if (userData['age'] != null) {
      await prefs.setInt('profile_age', userData['age']);
    }
    if (userData['dateOfBirth'] != null && userData['dateOfBirth'].isNotEmpty) {
      await prefs.setString('profile_date_of_birth', userData['dateOfBirth']);
    }
    if (userData['nationality'] != null && userData['nationality'].isNotEmpty) {
      await prefs.setString('profile_nationality', userData['nationality']);
    }
    
    // Save photo if available
    if (userData['photoBase64'] != null && userData['photoBase64'].isNotEmpty) {
      await prefs.setString('profile_photo', userData['photoBase64']);
    }
    
    print('✅ User data saved locally');
  }

  // Helper method to handle login errors
  Future<void> _handleLoginError(http.Response response) async {
    final errorData = json.decode(response.body);
    String errorMessage = 'Login failed';
    
    switch (response.statusCode) {
      case 400:
        errorMessage = errorData['error'] ?? 'Please enter both email and password';
        break;
      case 401:
        errorMessage = 'Wrong email or password';
        break;
      case 403:
        errorMessage = 'Account access denied. Please contact your administrator.';
        break;
      case 404:
        errorMessage = 'User not found. Please check your email or sign up first.';
        break;
      case 500:
        errorMessage = 'Server error. Please try again later.';
        break;
      default:
        errorMessage = errorData['error'] ?? 'An unexpected error occurred';
    }
    
    print('❌ Login failed: $errorMessage');
    
    if (mounted) {
      _showErrorDialog(errorMessage);
    }
  }

  // Optional: Method to verify session (useful for app startup)
  Future<bool> _verifyUserSession(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/verify-session/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['valid'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error verifying session: $e');
      return false;
    }
  }

  // Optional: Method to logout user
  Future<bool> _logoutUser(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/logout/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('✅ User logged out successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error logging out user: $e');
      return false;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade600,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Text(
                'Login Failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,                    // Pure white start
              Color(0xFFFFE5E5),              // Very light red
              Color.fromARGB(255, 134, 24, 24),              // Medium red (matches button red.shade600)
              Color(0xFF1A1A1A),              // Dark red/black (matches button black87)         // Dark red/black (matches button black87)
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              _buildAnimatedBackground(),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildMainLogoSection(),
                          const SizedBox(height: 40),
                          _buildLoginCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        ...List.generate(8, (index) {
          final colors = [
            const Color(0xFFD32F2F).withOpacity(0.15),  // True red
            Colors.black.withOpacity(0.05),
            const Color(0xFFC62828).withOpacity(0.12),  // Deep red
            const Color(0xFFB71C1C).withOpacity(0.1),   // Dark red
          ];
          
          return Positioned(
            top: (index * 130.0) % MediaQuery.of(context).size.height,
            left: (index * 180.0) % MediaQuery.of(context).size.width,
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value + (index * 0.3),
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
              },
            ),
          );
        }),
        
        AnimatedBuilder(
          animation: _waveAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: EspritWavePainter(_waveAnimation.value),
              size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
            );
          },
        ),
        
        ...List.generate(4, (index) {
          return Positioned(
            top: 100 + (index * 200.0),
            right: 20 + (index * 50.0),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 20 + (index * 8.0),
                    height: 20 + (index * 8.0),
                    decoration: BoxDecoration(
                      color: index % 2 == 0 ? const Color(0xFFD32F2F).withOpacity(0.25) : const Color(0xFFC62828).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(index % 2 == 0 ? 10 : 0),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMainLogoSection() {
    return AnimatedBuilder(
      animation: _cardFlipController,
      builder: (context, child) {
        final animationValue = _cardFlipController.value;
        double flipValue;
        bool isShowingFront;
        
        if (animationValue <= 0.375) {
          flipValue = 0.0;
          isShowingFront = true;
        } else if (animationValue <= 0.5) {
          final progress = (animationValue - 0.375) / 0.125;
          flipValue = progress;
          isShowingFront = progress < 0.5;
        } else if (animationValue <= 0.875) {
          flipValue = 1.0;
          isShowingFront = false;
        } else {
          final progress = (animationValue - 0.875) / 0.125;
          flipValue = 1.0 - progress;
          isShowingFront = progress >= 0.5;
        }
        
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(flipValue * math.pi),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  Colors.red.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: const Color.fromARGB(255, 161, 37, 37), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.2),
                  blurRadius: 25,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: isShowingFront ? _buildFrontCard() : _buildBackCard(),
          ),
        );
      },
    );
  }

  Widget _buildFrontCard() {
    return Column(
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.shade600,
                Colors.red.shade800,
                Colors.black87,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: _buildGifWidget(),
          ),
        ),
        
        const SizedBox(height: 25),
        
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Colors.red.shade700,
              Colors.black87,
              Colors.red.shade600,
            ],
          ).createShader(bounds),
          child: const Text(
            'QuizMaster',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.withOpacity(0.1),
                Colors.black.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color.fromARGB(255, 161, 35, 35), width: 1),
          ),
          child: Text(
            'Learn • Play • Create Your Avatar',
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackCard() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Colors.black87,
                  Colors.red.shade800,
                  Colors.red.shade600,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.school,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'ESPRIT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    'EDUCATION',
                    style: TextStyle(
                      color: Colors.red.shade200,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 25),
          
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.black87,
                Colors.red.shade700,
                Colors.red.shade600,
              ],
            ).createShader(bounds),
            child: const Text(
              'Excellence',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.red.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.black38, width: 1),
            ),
            child: const Text(
              'Se former autrement',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGifWidget() {
    return Stack(
      children: [
        Image.asset(
          'assets/images/icon.gif',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/icon.gif',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'icon.gif',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildEspritAnimatedFallback();
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEspritAnimatedFallback() {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.shade600,
                Colors.red.shade800,
                Colors.black87,
                Colors.grey.shade800,
              ],
              transform: GradientRotation(_rotationAnimation.value * 0.5),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Icon(
                        Icons.auto_awesome,
                        color: Colors.white.withOpacity(0.3),
                        size: 60,
                      ),
                    ),
                    Transform.rotate(
                      angle: -_rotationAnimation.value * 0.5,
                      child: const Icon(
                        Icons.quiz,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'QUIZ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  'MASTER',
                  style: TextStyle(
                    color: Colors.red.shade200,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color.fromARGB(255, 156, 36, 48), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(35.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade50,
                      Colors.grey.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color.fromARGB(255, 163, 39, 39), width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 4,
                          height: 25,
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Text(
                          'Welcome',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Container(
                          width: 4,
                          height: 25,
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sign in to start your adventure !',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              _buildEspritTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.alternate_email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              _buildEspritTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.red.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 15),
              
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Forgot password feature coming soon!'),
                        backgroundColor: Color.fromARGB(255, 116, 24, 23),
                      ),
                    );
                  },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 25),
              
              _buildEspritButton(),
              
              const SizedBox(height: 25),
              
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              
              const SizedBox(height: 25),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Compact UNIVERSITY LOGO SECTION
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade50,
                      Colors.red.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color.fromARGB(255, 150, 41, 41), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Stylish "Powered by" with sign-in button colors
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.shade600,
                            Colors.red.shade700,
                            Colors.black87,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.electric_bolt,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'POWERED BY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.electric_bolt,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Compact ESPRIT Logo and text section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ESPRIT university logo
                        Container(
                          width: 70,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade300, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/university_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.red.shade100, Colors.red.shade200],
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.school,
                                          color: Colors.red.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'ESPRIT',
                                          style: TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    Colors.red.shade700,
                                    Colors.red.shade800,
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  'ESPRIT',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Se former autrement',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEspritTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade700],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.red.shade600, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.red.shade700, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.red.shade700, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildEspritButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.shade600,
                Colors.red.shade700,
                Colors.black87,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 15),
                      Text(
                        'Signing In...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class EspritWavePainter extends CustomPainter {
  final double animationValue;

  EspritWavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final redPaint = Paint()
      ..color = const Color.fromARGB(255, 112, 19, 19).withOpacity(0.15)  // True red wave
      ..style = PaintingStyle.fill;
    
    final lightRedPaint = Paint()
      ..color = const Color.fromARGB(255, 181, 42, 42).withOpacity(0.1)   // Light true red wave
      ..style = PaintingStyle.fill;

    final redPath = Path();
    final lightRedPath = Path();
    const waveHeight = 40.0;
    final waveLength = size.width / 1.5;

    redPath.moveTo(0, size.height * 0.8);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.8 +
          waveHeight * math.sin((x / waveLength * 2 * math.pi) + (animationValue * 2 * math.pi));
      redPath.lineTo(x, y);
    }
    redPath.lineTo(size.width, size.height);
    redPath.lineTo(0, size.height);
    redPath.close();

    lightRedPath.moveTo(0, size.height * 0.85);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.85 +
          (waveHeight * 0.7) * math.sin((x / waveLength * 2 * math.pi) + (animationValue * 2 * math.pi) + math.pi);
      lightRedPath.lineTo(x, y);
    }
    lightRedPath.lineTo(size.width, size.height);
    lightRedPath.lineTo(0, size.height);
    lightRedPath.close();

    canvas.drawPath(lightRedPath, lightRedPaint);
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}