import 'package:flutter/material.dart';
import 'pages/login_page.dart';

// --- NEW: Define the Ocean Blue Color Palette ---
const Color primaryBlue = Color(0xFF02367B);
const Color accentBlue = Color(0xFF006CA5);
const Color brightBlue = Color(0xFF0496C7);
const Color lightBlue = Color(0xFF55E2E9);
const Color offWhite = Color(0xFFF8F9FA);

void main() {
  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PHARMAKOLE POS',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.light(
          primary: primaryBlue,
          secondary: accentBlue,
          onPrimary: Colors.white,
          surface: offWhite,
          onSurface: Colors.black87,
        ),
        scaffoldBackgroundColor: offWhite,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white, // Text and icon color
          elevation: 2,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.black54),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: primaryBlue,
          unselectedItemColor: Colors.grey,
          elevation: 4,
        ),
      ),
      home: const LoginPage(),
    );
  }
}