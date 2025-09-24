// File: lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios; 
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // UPDATED: QuizMaster project configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCt08wSov0LhGB2n-8XIA7E0fvuUoF8jNY',
    appId: '1:666452813332:web:0893826a52515f9ddca901',
    messagingSenderId: '666452813332',
    projectId: 'quizmaster-2e381',
    authDomain: 'quizmaster-2e381.firebaseapp.com',
    storageBucket: 'quizmaster-2e381.firebasestorage.app',
    measurementId: 'G-6B6FFB3SKH',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCt08wSov0LhGB2n-8XIA7E0fvuUoF8jNY',
    appId: '1:666452813332:android:YOUR_ANDROID_APP_ID', // You'll need to add Android app to get this
    messagingSenderId: '666452813332',
    projectId: 'quizmaster-2e381',
    storageBucket: 'quizmaster-2e381.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCt08wSov0LhGB2n-8XIA7E0fvuUoF8jNY',
    appId: '1:666452813332:ios:YOUR_IOS_APP_ID', // You'll need to add iOS app to get this
    messagingSenderId: '666452813332',
    projectId: 'quizmaster-2e381',
    storageBucket: 'quizmaster-2e381.firebasestorage.app',
    iosBundleId: 'com.example.quizMaster',
  );
}