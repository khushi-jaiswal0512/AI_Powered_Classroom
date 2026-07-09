import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6C63FF); // Modern bright purple/blue
  static const Color secondary = Color(0xFF00C9A7); // Teal/Cyan accent
  static const Color backgroundStart = Color(0xFF1E1E2C); // Dark theme start
  static const Color backgroundEnd = Color(0xFF2D2B55); // Dark theme end
  
  static const Color surface = Color(0xFF2A2D3E);
  static const Color border = Color(0xFF404052);
  
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A3BD);
  
  static const Color error = Color(0xFFFF5252);
  static const Color success = Color(0xFF00E676);

  // Futuristic Theme Additions
  static const Color deepBlack = Color(0xFF050510);
  static const Color visionBlue = Color(0xFF00F5FF);
  static const Color neonPurple = Color(0xFFBC13FE);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF8A82FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundStart, backgroundEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient futuristicGradient = LinearGradient(
    colors: [deepBlack, Color(0xFF0A0A2E), Color(0xFF1A1A4A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
