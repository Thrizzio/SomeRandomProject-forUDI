import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    FirebaseOptions options;

    if (kIsWeb) {
      options = web;
      _validateConfigured(options, 'web');
      return options;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        options = android;
        _validateConfigured(options, 'android');
        return options;
      case TargetPlatform.iOS:
        options = ios;
        _validateConfigured(options, 'ios');
        return options;
      case TargetPlatform.macOS:
        options = macos;
        _validateConfigured(options, 'macos');
        return options;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static void _validateConfigured(FirebaseOptions options, String platform) {
    final looksPlaceholder = <String>[
      options.apiKey,
      options.appId,
      options.messagingSenderId,
      options.projectId,
    ].any((value) =>
        value.trim().isEmpty ||
        value.contains('YOUR_') ||
        value.contains('your-firebase-project-id'));

    if (looksPlaceholder) {
      throw UnsupportedError(
        'Firebase options for $platform are still placeholder values. '
        'Run `flutterfire configure` and replace lib/firebase_options.dart before shipping.',
      );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_WEB_MESSAGING_SENDER_ID',
    projectId: 'your-firebase-project-id',
    authDomain: 'your-firebase-project-id.firebaseapp.com',
    databaseURL: 'https://your-firebase-project-id.firebaseio.com',
    storageBucket: 'your-firebase-project-id.appspot.com',
    measurementId: 'G-YOUR_MEASUREMENT_ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_ANDROID_MESSAGING_SENDER_ID',
    projectId: 'your-firebase-project-id',
    databaseURL: 'https://your-firebase-project-id.firebaseio.com',
    storageBucket: 'your-firebase-project-id.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_IOS_MESSAGING_SENDER_ID',
    projectId: 'your-firebase-project-id',
    databaseURL: 'https://your-firebase-project-id.firebaseio.com',
    storageBucket: 'your-firebase-project-id.appspot.com',
    iosBundleId: 'com.example.gigtax',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_MACOS_MESSAGING_SENDER_ID',
    projectId: 'your-firebase-project-id',
    databaseURL: 'https://your-firebase-project-id.firebaseio.com',
    storageBucket: 'your-firebase-project-id.appspot.com',
    iosBundleId: 'com.example.gigtax',
  );
}
