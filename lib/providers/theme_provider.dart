import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  static const String _fontSizeKey = 'font_size';
  static const String _highContrastKey = 'high_contrast';
  
  bool _isDarkMode = false;
  double _fontSizeMultiplier = 1.0;
  bool _isHighContrast = false;
  
  bool get isDarkMode => _isDarkMode;
  double get fontSizeMultiplier => _fontSizeMultiplier;
  bool get isHighContrast => _isHighContrast;
  
  ThemeProvider() {
    _loadThemePreference();
  }
  
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    _fontSizeMultiplier = prefs.getDouble(_fontSizeKey) ?? 1.0;
    _isHighContrast = prefs.getBool(_highContrastKey) ?? false;
    notifyListeners();
  }
  
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }
  
  Future<void> setFontSize(double multiplier) async {
    _fontSizeMultiplier = multiplier;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, multiplier);
    notifyListeners();
  }
  
  Future<void> toggleHighContrast() async {
    _isHighContrast = !_isHighContrast;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, _isHighContrast);
    notifyListeners();
  }
  
  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _isHighContrast 
      ? const ColorScheme.light(
          primary: Color(0xFF0d6b5c),
          secondary: Colors.white,
          surface: Colors.white,
        )
      : ColorScheme.fromSeed(
                  seedColor: const Color(0xFF0d6b5c),
          brightness: Brightness.light,
        ),
    primaryColor: const Color(0xFF0d6b5c),
    scaffoldBackgroundColor: _isHighContrast ? Colors.white : Colors.grey[50],
    textTheme: _buildTextTheme(Brightness.light),
    // Override default text styles to use theme-based scaling
    appBarTheme: AppBarTheme(
      backgroundColor: _isHighContrast ? const Color(0xFF0d6b5c) : const Color(0xFF0d6b5c),
      foregroundColor: Colors.white,
      elevation: 2,
      titleTextStyle: _buildTextTheme(Brightness.light).titleLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _isHighContrast ? const Color(0xFF0d6b5c) : const Color(0xFF0d6b5c),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _buildTextTheme(Brightness.light).bodyLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _isHighContrast ? const Color(0xFF0d6b5c) : const Color(0xFF0d6b5c);
        }
        return _isHighContrast ? Colors.grey[600] : Colors.grey[400];
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return (_isHighContrast ? const Color(0xFF0d6b5c) : const Color(0xFF0d6b5c)).withOpacity(0.5);
        }
        return Colors.grey[300];
      }),
    ),
  );
  
  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _isHighContrast 
      ? const ColorScheme.dark(
          primary: Colors.white,
          secondary: Color(0xFF0d6b5c),
          surface: Color(0xFF0d6b5c),
        )
      : ColorScheme.fromSeed(
          seedColor: const Color(0xFF0d6b5c),
          brightness: Brightness.dark,
        ),
    primaryColor: _isHighContrast ? Colors.white : const Color(0xFF0d6b5c),
    scaffoldBackgroundColor: _isHighContrast ? const Color(0xFF0d6b5c) : const Color(0xFF023a31),
    textTheme: _buildTextTheme(Brightness.dark),
    appBarTheme: AppBarTheme(
      backgroundColor: _isHighContrast ? Colors.white : const Color(0xFF0d6b5c),
      foregroundColor: _isHighContrast ? const Color(0xFF0d6b5c) : Colors.white,
      elevation: 2,
      titleTextStyle: _buildTextTheme(Brightness.dark).titleLarge?.copyWith(
        color: _isHighContrast ? const Color(0xFF0d6b5c) : Colors.white,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 4,
      color: _isHighContrast ? const Color(0xFF0d6b5c) : const Color(0xFF0d6b5c),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _isHighContrast ? Colors.white : const Color(0xFF0d6b5c),
        foregroundColor: _isHighContrast ? const Color(0xFF0d6b5c) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _buildTextTheme(Brightness.dark).bodyLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _isHighContrast ? Colors.white : const Color(0xFF0d6b5c);
        }
        return _isHighContrast ? Colors.grey[400] : Colors.grey[600];
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return (_isHighContrast ? Colors.white : const Color(0xFF0d6b5c)).withOpacity(0.5);
        }
        return _isHighContrast ? Colors.grey[800] : Colors.grey[700];
      }),
    ),
  );
  
  TextTheme _buildTextTheme(Brightness brightness) {
    final baseTheme = brightness == Brightness.light 
      ? ThemeData.light().textTheme 
      : ThemeData.dark().textTheme;
    
    return baseTheme.copyWith(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontSize: (baseTheme.displayLarge?.fontSize ?? 57) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.normal,
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontSize: (baseTheme.displayMedium?.fontSize ?? 45) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.normal,
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontSize: (baseTheme.displaySmall?.fontSize ?? 36) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.normal,
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontSize: (baseTheme.headlineLarge?.fontSize ?? 32) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.normal,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontSize: (baseTheme.headlineMedium?.fontSize ?? 28) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.normal,
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontSize: (baseTheme.headlineSmall?.fontSize ?? 24) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.normal,
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontSize: (baseTheme.titleLarge?.fontSize ?? 22) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.w500,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontSize: (baseTheme.titleMedium?.fontSize ?? 16) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.w500,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontSize: (baseTheme.titleSmall?.fontSize ?? 14) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.w500,
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontSize: (baseTheme.bodyLarge?.fontSize ?? 16) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.w500 : FontWeight.normal,
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontSize: (baseTheme.bodyMedium?.fontSize ?? 14) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.w500 : FontWeight.normal,
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontSize: (baseTheme.bodySmall?.fontSize ?? 12) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.w500 : FontWeight.normal,
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontSize: (baseTheme.labelLarge?.fontSize ?? 14) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.w500,
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontSize: (baseTheme.labelMedium?.fontSize ?? 12) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.w500,
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontSize: (baseTheme.labelSmall?.fontSize ?? 11) * _fontSizeMultiplier,
        fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.w500,
      ),
    );
  }
} 
