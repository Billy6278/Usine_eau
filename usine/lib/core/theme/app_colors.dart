import 'package:flutter/material.dart';

class AppColors {
  // Theme brand colors
  static const Color primary = Color(0xFF0284C7);      // Ocean blue (Sky 600)
  static const Color primaryDark = Color(0xFF0369A1);  // Sky 700
  static const Color primaryLight = Color(0xFFE0F2FE); // Sky 100
  
  // Neutral darks and slate (Sidebar / Header / Text)
  static const Color slate900 = Color(0xFF0F172A);    // Dark sidebar
  static const Color slate800 = Color(0xFF1E293B);    // Accent header
  static const Color slate700 = Color(0xFF334155);    // Primary text
  static const Color slate400 = Color(0xFF94A3B8);    // Muted text
  static const Color slate100 = Color(0xFFF1F5F9);    // Background alternative
  static const Color slate50 = Color(0xFFF8FAFC);     // Main background
  
  // Status and Alerts
  static const Color success = Color(0xFF10B981);      // Emerald 500 (Profits / Stock Good)
  static const Color warning = Color(0xFFF59E0B);      // Amber 500 (Low Stock Warning)
  static const Color danger = Color(0xFFEF4444);       // Red 500 (Losses / Debt)
  static const Color info = Color(0xFF3B82F6);         // Blue 500
  
  // Accent colors
  static const Color accent = Color(0xFF06B6D4);       // Cyan 500
  static const Color white = Colors.white;
}
