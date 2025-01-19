import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
          'DefaultFirebaseOptions have not been configured for Linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAWkQHxZN0he4s0K1GIgZcedmlrAWEqG5c',
    appId: '1:1014602044921:android:1293fd927a04bb594e9928',
    messagingSenderId: '1014602044921',
    projectId: 'k-photo-455a9',
    storageBucket: 'k-photo-455a9.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAnrf5QRvb68UnIIfCX6HkogKO-AvgVDIo',
    appId: '1:1014602044921:web:7863633b808ca2d84e9928',
    messagingSenderId: '1014602044921',
    projectId: 'k-photo-455a9',
    authDomain: 'k-photo-455a9.firebaseapp.com',
    storageBucket: 'k-photo-455a9.firebasestorage.app',
    measurementId: 'G-RT5G93Q4G0',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAgrStqBYlnQcr1wRImyxLoNuIs7L2cg3A',
    appId: '1:1014602044921:ios:ec3e88492d37267a4e9928',
    messagingSenderId: '1014602044921',
    projectId: 'k-photo-455a9',
    storageBucket: 'k-photo-455a9.firebasestorage.app',
    iosBundleId: 'com.kauanne.kPhoto',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAgrStqBYlnQcr1wRImyxLoNuIs7L2cg3A',
    appId: '1:1014602044921:ios:ec3e88492d37267a4e9928',
    messagingSenderId: '1014602044921',
    projectId: 'k-photo-455a9',
    storageBucket: 'k-photo-455a9.firebasestorage.app',
    iosBundleId: 'com.kauanne.kPhoto',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAnrf5QRvb68UnIIfCX6HkogKO-AvgVDIo',
    appId: '1:1014602044921:web:4ea7fad393c477484e9928',
    messagingSenderId: '1014602044921',
    projectId: 'k-photo-455a9',
    authDomain: 'k-photo-455a9.firebaseapp.com',
    storageBucket: 'k-photo-455a9.firebasestorage.app',
    measurementId: 'G-VH1GNSPWLT',
  );

}