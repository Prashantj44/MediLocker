import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return macos;
      case TargetPlatform.windows:
        return windows;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAaRE8-30UJPbsoN7GEJTnWr8FpR_fD450',
    appId: '1:965263320155:web:20335d0520538f31984b7e', // Guessed web suffix
    messagingSenderId: '965263320155',
    projectId: 'medilocker-f1',
    authDomain: 'medilocker-f1.firebaseapp.com',
    storageBucket: 'medilocker-f1.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAaRE8-30UJPbsoN7GEJTnWr8FpR_fD450',
    appId: '1:965263320155:android:20335d0520538f31984b7e',
    messagingSenderId: '965263320155',
    projectId: 'medilocker-f1',
    storageBucket: 'medilocker-f1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAaRE8-30UJPbsoN7GEJTnWr8FpR_fD450',
    appId: '1:965263320155:ios:20335d0520538f31984b7e',
    messagingSenderId: '965263320155',
    projectId: 'medilocker-f1',
    storageBucket: 'medilocker-f1.firebasestorage.app',
    iosBundleId: 'com.medi.medilocker',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAaRE8-30UJPbsoN7GEJTnWr8FpR_fD450',
    appId: '1:965263320155:ios:20335d0520538f31984b7e',
    messagingSenderId: '965263320155',
    projectId: 'medilocker-f1',
    storageBucket: 'medilocker-f1.firebasestorage.app',
    iosBundleId: 'com.medi.medilocker',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAaRE8-30UJPbsoN7GEJTnWr8FpR_fD450',
    appId: '1:965263320155:web:20335d0520538f31984b7e',
    messagingSenderId: '965263320155',
    projectId: 'medilocker-f1',
    authDomain: 'medilocker-f1.firebaseapp.com',
    storageBucket: 'medilocker-f1.firebasestorage.app',
  );
}
