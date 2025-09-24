import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'firebase_options.dart'; // Your Firebase configuration file
import 'screens/login_screen.dart';
import 'screens/quiz_list.dart'; // Import your QuizListScreen
import 'screens/waiting_screen.dart';
import 'screens/quiz_code_entry_screen.dart'; // Import your QuizCodeEntryScreen  
import 'screens/islands_map_screen.dart'; // Import your IslandsMapScreen

// Import the new Python backend service
import 'services/python_group_service.dart';
import 'services/firebase_avatar_service.dart'; // Make sure avatar service is available

void main() async {
  // Ensure that plugin services are initialized so that Firebase can be used
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase with your configuration
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully for project: quizmaster-2e381');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
    // App can still run, but Firebase features won't work
  }
  
  // Initialize services
  _initializeServices();
  
  runApp(const QuizApp());
}

/// Initialize global services for the app
void _initializeServices() {
  try {
    // Initialize Firebase Avatar Service if not already initialized
    if (!Get.isRegistered<FirebaseAvatarService>()) {
      Get.put(FirebaseAvatarService(), permanent: true);
      debugPrint('✅ FirebaseAvatarService initialized globally');
    }

    // Initialize Python Group Service
    if (!Get.isRegistered<PythonGroupService>()) {
      Get.put(PythonGroupService(), permanent: true);
      debugPrint('✅ PythonGroupService initialized globally');
    }

    debugPrint('✅ All services initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing services: $e');
  }
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(  // Changed from MaterialApp to GetMaterialApp for GetX
      title: 'Quiz Avatar App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Red & White Theme Configuration
        primarySwatch: Colors.red,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          primary: Colors.red.shade600,
          secondary: Colors.red.shade400,
          surface: Colors.white,
          background: Colors.grey.shade50,
        ),
        
        // App Bar Theme
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.red.withOpacity(0.3),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        // Button Themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            elevation: 6,
            shadowColor: Colors.red.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.red.shade600,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        
        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade600, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade700, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.red.shade400),
          prefixIconColor: Colors.red.shade400,
          suffixIconColor: Colors.red.shade400,
        ),
        
        // Card Theme
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
        
        // Floating Action Button Theme
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: const CircleBorder(),
        ),
        
        // Snack Bar Theme
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.red.shade600,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        
        // Progress Indicator Theme
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: Colors.red.shade600,
          linearTrackColor: Colors.red.shade100,
          circularTrackColor: Colors.red.shade100,
        ),
        
        // Typography
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            color: Colors.red.shade600,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: Colors.red.shade600,
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            color: Colors.red.shade600,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            color: Colors.red.shade600,
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(
            color: Colors.red.shade600,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(
            color: Colors.black87,
          ),
          bodyMedium: const TextStyle(
            color: Colors.black87,
          ),
        ),
        
        // Icon Theme
        iconTheme: IconThemeData(
          color: Colors.red.shade600,
        ),
        
        // Navigation Bar Theme (for future use)
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.red.shade600,
          unselectedItemColor: Colors.grey.shade400,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        
        // Divider Theme
        dividerTheme: DividerThemeData(
          color: Colors.grey.shade300,
          thickness: 1,
        ),
        
        // Font Family (you can add custom fonts later)
        fontFamily: 'Roboto',
        
        // Material 3 Design
        useMaterial3: true,
      ),
      
      // Home Screen
      home: const LoginScreen(),
      
      // GetX Route Configuration (enhanced for GetX)
      getPages: [
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/listquiz', page: () => QuizListScreen()),
        GetPage(name: '/waiting', page: () => WaitingScreen()),
        GetPage(name: '/code', page: () => QuizCodeEntryScreen()),
        GetPage(name: '/islands', page: () => const IslandsMapScreen()),
        // Add more GetX routes as you create more screens
        // GetPage(name: '/avatar-maker', page: () => const AvatarMakerScreen()),
        // GetPage(name: '/quiz', page: () => const QuizScreen()),
        // GetPage(name: '/results', page: () => const ResultsScreen()),
      ],
      
      // Fallback routes for compatibility
      routes: {
        '/login': (context) => const LoginScreen(),
        '/listquiz': (context) => QuizListScreen(),
        '/waiting': (context) => WaitingScreen(),
        '/code': (context) => QuizCodeEntryScreen(),
        '/islands': (context) => const IslandsMapScreen(),
        
        // Add more routes as you create more screens
        // '/avatar-designer': (context) => AvatarDesignerScreen(),
        // '/quiz': (context) => QuizScreen(),
        // '/results': (context) => ResultsScreen(),
      },
      
      // Handle unknown routes
      unknownRoute: GetPage(
        name: '/not-found',
        page: () => Scaffold(
          appBar: AppBar(
            title: const Text('Page Not Found'),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Page Not Found',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The page you are looking for does not exist.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Get.offAllNamed('/login');  // Using GetX navigation
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
      
      // Optional: Handle initial route
      initialRoute: '/',
      
      // Optional: Add global snackbar configuration for GetX
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}