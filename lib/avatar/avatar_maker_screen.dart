// File: lib/avatar/avatar_maker_screen.dart

import 'package:flutter/material.dart';
import 'package:fluttermoji/fluttermoji.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'avatar_maker_controller.dart';
import '../services/firebase_avatar_service.dart';
import 'shared/background_shape.dart';

class AvatarMakerScreen extends StatefulWidget {
  const AvatarMakerScreen({super.key});

  @override
  State<AvatarMakerScreen> createState() => _AvatarMakerScreenState();
}

class _AvatarMakerScreenState extends State<AvatarMakerScreen> {
  // GlobalKey for capturing the avatar as an image
  final GlobalKey _avatarKey = GlobalKey();
  bool _isSaving = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  // Load the current user ID from SharedPreferences
  Future<void> _loadCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentUserId = prefs.getString('user_document_id');
      });
      
      print('🔍 Loaded current user ID: $_currentUserId');
      
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        print('⚠️ Warning: No user ID found in SharedPreferences');
        // Show warning to user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Warning: User ID not found. Avatar may not be linked to your account.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error loading user ID: $e');
    }
  }

  // Convert BackgroundShape enum to string
  String _backgroundShapeToString(BackgroundShape shape) {
    switch (shape) {
      case BackgroundShape.circle:
        return "circle";
      case BackgroundShape.square:
        return "square";
      case BackgroundShape.roundedSquare:
        return "roundedSquare";
    }
  }

  // Mark avatar customization as complete
  Future<void> _completeAvatarCustomization() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Set multiple flags to indicate user has completed setup
      await prefs.setBool('has_customized_avatar', true);
      await prefs.setBool('completed_onboarding', true);
      
      // Set completion timestamp
      await prefs.setInt('avatar_completed_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      print('✅ Avatar customization marked as complete');
      
    } catch (e) {
      print('❌ Error marking avatar customization as complete: $e');
    }
  }

  // Save avatar to Firebase with image capture
  Future<void> _saveAvatarWithImage(BuildContext context, {bool downloadToPC = false}) async {
    if (_isSaving) return; // Prevent multiple saves
    
    setState(() {
      _isSaving = true;
    });

    try {
      // Show loading indicator
      Get.dialog(
        Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
                ),
                SizedBox(height: 15),
                Text(
                  'Saving your avatar...',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 10),
                Text(
                  'This will only take a moment...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Get your existing controller
      final avatarController = Get.find<AvatarMakerController>();
      final firebaseService = Get.find<FirebaseAvatarService>();

      // Randomize avatar
      avatarController.randomize();

      // Wait for values to be updated (200 ms)
      await Future.delayed(Duration(milliseconds: 200));

      // Create AvatarData object with user ID
      final avatarData = AvatarData(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        avatarName: "My Custom Avatar",
        userId: _currentUserId, // Use the loaded user ID
        selectedCategory: avatarController.selectedCategory,
        selectedColor: avatarController.selectedColor,
        selectedBody: avatarController.selectedBody,
        selectedEyes: avatarController.selectedEyes,
        selectedNose: avatarController.selectedNose,
        selectedMouth: avatarController.selectedMouth,
        selectedHairType: avatarController.selectedHairType == HairType.short ? "short" : "long",
        selectedShortHair: avatarController.selectedShortHair,
        selectedLongHair: avatarController.selectedLongHair,
        selectedFacialHair: avatarController.selectedFacialHair,
        selectedFacialHairColor: avatarController.selectedFacialHairColor,
        selectedClothing: avatarController.selectedClothing,
        selectedClothingColor: avatarController.selectedClothingColor,
        selectedAccessory: avatarController.selectedAccessory,
        selectedAccessoryColor: avatarController.selectedAccessoryColor,
        selectedHat: avatarController.selectedHat,
        selectedBackgroundColor: avatarController.selectedBackgroundColor,
        selectedBackgroundShape: _backgroundShapeToString(avatarController.selectedBackgroundShape),
      );

      print('💾 Saving avatar with User ID: ${avatarData.userId}');

      // Save to Firebase with optional download
      String? avatarId = await firebaseService.saveAvatarWithImage(avatarData, _avatarKey, downloadToPC: downloadToPC);
      
      // Close loading dialog
      Get.back();
      
      if (avatarId != null) {
        // Also save using Fluttermoji for local display
        final fluttermojiController = Get.find<FluttermojiController>();
        await fluttermojiController.setFluttermoji();
        
        // IMPORTANT: Mark avatar customization as complete
        await _completeAvatarCustomization();
        
        // Show success dialog with the avatar ID
        _showSuccessDialog(context, avatarId, downloadToPC);
      }
      
    } catch (e) {
      // Close loading dialog
      Get.back();
      
      // Show error dialog
      _showErrorDialog(context, e.toString());
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Just download current avatar without saving to Firebase
  Future<void> _downloadCurrentAvatar() async {
    try {
      final firebaseService = Get.find<FirebaseAvatarService>();
      
      // Capture current avatar
      String? base64Image = await firebaseService.captureWidgetAsBase64(_avatarKey);
      
      if (base64Image != null) {
        String filename = 'avatar_${DateTime.now().millisecondsSinceEpoch}';
        await firebaseService.downloadImageToPC(base64Image, filename);
      } else {
        Get.snackbar(
          'Error',
          'Failed to capture avatar image',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to download avatar: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Navigate to quiz list after successful avatar completion
  Future<void> _navigateToQuizList() async {
    try {
      // Navigate to quiz list and remove all previous routes
      Navigator.of(context).pushNamedAndRemoveUntil('/listquiz', (route) => false); // Changed to /listquiz
    } catch (e) {
      print('Navigation error: $e');
      // Fallback navigation
      Navigator.of(context).pop();
    }
  }

  // Success dialog with avatar ID
  void _showSuccessDialog(BuildContext context, String avatarId, bool downloadedToPC) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                "Avatar Saved!",
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your avatar has been saved successfully!",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 15),
              
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Ready to start your quiz adventure!",
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _navigateToQuizList(); // Navigate to quiz list
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.quiz, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      "Start Quizzes!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Error dialog
  void _showErrorDialog(BuildContext context, String error) {
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
                Icons.error,
                color: Colors.red,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                "Save Failed",
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Failed to save avatar. Please try again.",
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // Add a "Skip Avatar" option for users who want to proceed without customizing
  void _showSkipAvatarDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.skip_next, color: Colors.orange),
              SizedBox(width: 10),
              Text("Skip Avatar Creation?"),
            ],
          ),
          content: Text(
            "You can skip avatar creation for now and proceed to your quizzes. You can always create your avatar later from the profile section.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                // Mark as completed even if skipped
                await _completeAvatarCustomization();
                Navigator.pop(context); // Close dialog
                _navigateToQuizList(); // Navigate to quiz list
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "Skip for Now",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    // Initialize all controllers
    final fluttermojiController = Get.put(FluttermojiController(), permanent: true);
    final avatarController = Get.put(AvatarMakerController());
    final firebaseService = Get.put(FirebaseAvatarService());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Avatar Maker",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          // Skip avatar button
          IconButton(
            onPressed: _showSkipAvatarDialog,
            icon: Icon(Icons.skip_next),
            tooltip: 'Skip Avatar Creation',
          ),
        ],
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xFFFFE5E5),
              Color(0xFFD32F2F),
              Color(0xFF1A1A1A),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                // Welcome message for first-time users (cleaned up)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.waving_hand, color: Colors.blue.shade600, size: 24),
                      SizedBox(height: 8),
                      Text(
                        "Welcome to QuizMaster!",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Create your personalized avatar to represent you in quizzes",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Avatar Display Container with RepaintBoundary for image capture
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.1),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: RepaintBoundary(
                    key: _avatarKey, // This key is used to capture the avatar as image
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: FluttermojiCircleAvatar(
                        backgroundColor: Colors.transparent,
                        radius: 80,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Customizer Container
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: FluttermojiCustomizer(
                    theme: FluttermojiThemeData(
                      boxDecoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.08),
                            blurRadius: 15,
                            offset: Offset(0, -8),
                          ),
                        ],
                      ),
                      selectedIconColor: Colors.red.shade700,
                      unselectedIconColor: Colors.grey.shade400,
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Save Your Avatar Button
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _saveAvatarWithImage(context, downloadToPC: false),
                    icon: Icon(Icons.save, size: 24),
                    label: Text(
                      _isSaving ? "Saving..." : "Save Your Avatar",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 5,
                      shadowColor: Colors.redAccent.withOpacity(0.3),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Randomize button
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: OutlinedButton(
                    onPressed: () {
                      // Use your existing randomize function
                      avatarController.randomize();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade700, width: 2),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shuffle,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Randomize Avatar",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  } 
}