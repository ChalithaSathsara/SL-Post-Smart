import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding); // ← add this

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FlutterNativeSplash.remove(); // ← add this (after Firebase is ready)
  runApp(const PostalApp());
}

/// Root widget with Material 3 theme and login as home route.
class PostalApp extends StatelessWidget {
  const PostalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SLPost Smart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}
