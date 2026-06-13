import 'package:flutter/material.dart';

const kBg = Color(0xFF0D1117);
const kSurface = Color(0xFF161B22);
const kCard = Color(0xFF1C2333);
const kBorder = Color(0xFF30363D);
const kPrimary = Color(0xFF238636);
const kGreen = Color(0xFF3FB950);
const kRed = Color(0xFFF85149);
const kYellow = Color(0xFFD29922);
const kBlue = Color(0xFF58A6FF);
const kText = Color(0xFFE6EDF3);
const kMuted = Color(0xFF8B949E);

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.dark(
    primary: kPrimary,
    surface: kSurface,
    onSurface: kText,
    error: kRed,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kBg,
    foregroundColor: kText,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: kText,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: const CardThemeData(
    color: kCard,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      side: BorderSide(color: kBorder, width: 1),
    ),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: kSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: kBlue, width: 2),
    ),
    labelStyle: TextStyle(color: kMuted),
    hintStyle: TextStyle(color: kMuted),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: kSurface,
    indicatorColor: kCard,
    labelTextStyle: WidgetStatePropertyAll(TextStyle(color: kText, fontSize: 12)),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(color: kText, fontSize: 22, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(color: kText, fontSize: 15),
    bodyMedium: TextStyle(color: kText, fontSize: 14),
    bodySmall: TextStyle(color: kMuted, fontSize: 12),
    labelSmall: TextStyle(color: kMuted, fontSize: 11),
  ),
);
