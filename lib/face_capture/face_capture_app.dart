import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/permission_screen.dart';

class FaceCaptureApp extends StatelessWidget {
  const FaceCaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Capture',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF00BFA5),
          surface: Color(0xFF1C1C1E),
          error: Color(0xFFFF5252),
        ),
        // Applies globally to all TextButtons
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF00E676),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        useMaterial3: true,
      ),
      home: const PermissionScreen(),
    );
  }
}
