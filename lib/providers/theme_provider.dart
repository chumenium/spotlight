import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

class ThemeProvider with ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.system;
  static const String _themeModeKey = 'theme_mode';

  AppThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);
      if (savedMode != null) {
        _themeMode = AppThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedMode,
          orElse: () => AppThemeMode.system,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('テーマモードの読み込みエラー: $e');
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_themeModeKey, mode.toString());
      } catch (e) {
        debugPrint('テーマモードの保存エラー: $e');
      }
    }
  }

  ThemeData getLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.orange,
      primaryColor: const Color(0xFFFF6B35),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF6B35),
        brightness: Brightness.light,
        primary: const Color(0xFFFF6B35),
        onPrimary: Colors.white,
        secondary: const Color(0xFFFF8A65),
        onSecondary: Colors.white,
        surface: const Color(0xFFFFF5E6),
        onSurface: const Color(0xFF2C2C2C),
        background: const Color(0xFFFFFBF5),
        onBackground: const Color(0xFF2C2C2C),
        error: const Color(0xFFE63946),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFFFFBF5), // 温かみのあるクリーム色
      cardColor: const Color(0xFFFFF5E6), // 薄いオレンジ系のカード背景
      cardTheme: CardThemeData(
        color: const Color(0xFFFFF5E6),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C2C2C),
        elevation: 0,
        shadowColor: const Color(0xFFFF6B35).withOpacity(0.1),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF2C2C2C),
        ),
        titleTextStyle: const TextStyle(
          color: Color(0xFF2C2C2C),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Color(0xFF2C2C2C)),
        displayMedium: TextStyle(color: Color(0xFF2C2C2C)),
        displaySmall: TextStyle(color: Color(0xFF2C2C2C)),
        headlineLarge: TextStyle(color: Color(0xFF2C2C2C)),
        headlineMedium: TextStyle(color: Color(0xFF2C2C2C)),
        headlineSmall: TextStyle(color: Color(0xFF2C2C2C)),
        titleLarge: TextStyle(color: Color(0xFF2C2C2C)),
        titleMedium: TextStyle(color: Color(0xFF2C2C2C)),
        titleSmall: TextStyle(color: Color(0xFF2C2C2C)),
        bodyLarge: TextStyle(color: Color(0xFF3A3A3A)),
        bodyMedium: TextStyle(color: Color(0xFF3A3A3A)),
        bodySmall: TextStyle(color: Color(0xFF6B6B6B)),
        labelLarge: TextStyle(color: Color(0xFF2C2C2C)),
        labelMedium: TextStyle(color: Color(0xFF3A3A3A)),
        labelSmall: TextStyle(color: Color(0xFF6B6B6B)),
      ),
      dividerColor: const Color(0xFFFFE5CC).withOpacity(0.5),
      dividerTheme: DividerThemeData(
        color: const Color(0xFFFFE5CC).withOpacity(0.5),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFFFF6B35).withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFFFF6B35).withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFFF6B35),
            width: 2,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFFFE5CC),
        labelStyle: const TextStyle(
          color: Color(0xFF2C2C2C),
        ),
        selectedColor: const Color(0xFFFF6B35),
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  ThemeData getDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.orange,
      primaryColor: const Color(0xFFFF6B35),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF6B35),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
    );
  }

  ThemeMode getMaterialThemeMode() {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  // カード背景色を取得（テーマに応じた色を返す）
  Color getCardColor(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return const Color(0xFF1E1E1E);
    } else {
      return const Color(0xFFFFF5E6);
    }
  }

  // セカンダリカード背景色を取得（テーマに応じた色を返す）
  Color getSecondaryCardColor(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return const Color(0xFF2A2A2A);
    } else {
      return Colors.white;
    }
  }

  // テキスト色を取得（テーマに応じた色を返す）
  Color getTextColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyLarge?.color ?? 
           (theme.brightness == Brightness.dark ? Colors.white : const Color(0xFF2C2C2C));
  }

  // セカンダリテキスト色を取得（テーマに応じた色を返す）
  Color getSecondaryTextColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium?.color ?? 
           (theme.brightness == Brightness.dark ? Colors.grey[400]! : Colors.grey[600]!);
  }
}

