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
        surface: Colors.white, // より明るい白に変更
        onSurface: const Color(0xFF1A1A1A), // より濃い色でコントラスト向上
        background: const Color(0xFFFAFAFA), // より明るくクリーンな背景
        onBackground: const Color(0xFF1A1A1A), // より濃い色でコントラスト向上
        error: const Color(0xFFE63946),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFFAFAFA), // より明るくクリーンな背景
      cardColor: Colors.white, // 純白のカード背景で視認性向上
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 3, // elevationを上げて立体感を出す
        shadowColor: Colors.black.withOpacity(0.08), // より明確な影
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A), // より濃い色でコントラスト向上
        elevation: 1, // 軽い影を追加して区別しやすく
        shadowColor: Colors.black.withOpacity(0.05),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF1A1A1A), // より濃い色でコントラスト向上
        ),
        titleTextStyle: const TextStyle(
          color: Color(0xFF1A1A1A), // より濃い色でコントラスト向上
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Color(0xFF1A1A1A)), // より濃い色
        displayMedium: TextStyle(color: Color(0xFF1A1A1A)),
        displaySmall: TextStyle(color: Color(0xFF1A1A1A)),
        headlineLarge: TextStyle(color: Color(0xFF1A1A1A)),
        headlineMedium: TextStyle(color: Color(0xFF1A1A1A)),
        headlineSmall: TextStyle(color: Color(0xFF1A1A1A)),
        titleLarge: TextStyle(color: Color(0xFF1A1A1A)),
        titleMedium: TextStyle(color: Color(0xFF1A1A1A)),
        titleSmall: TextStyle(color: Color(0xFF1A1A1A)),
        bodyLarge: TextStyle(color: Color(0xFF2C2C2C)), // より濃い色で視認性向上
        bodyMedium: TextStyle(color: Color(0xFF2C2C2C)), // より濃い色で視認性向上
        bodySmall: TextStyle(color: Color(0xFF5A5A5A)), // 適度なグレーで階層化
        labelLarge: TextStyle(color: Color(0xFF1A1A1A)),
        labelMedium: TextStyle(color: Color(0xFF2C2C2C)),
        labelSmall: TextStyle(color: Color(0xFF5A5A5A)),
      ),
      dividerColor: const Color(0xFFE0E0E0), // より明確な区切り線
      dividerTheme: DividerThemeData(
        color: const Color(0xFFE0E0E0), // より明確な区切り線
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFFFF6B35).withOpacity(0.4), // より明確なボーダー
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFFE0E0E0), // より明確なボーダー
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
        backgroundColor: const Color(0xFFF5F5F5), // より明るいグレーで視認性向上
        labelStyle: const TextStyle(
          color: Color(0xFF1A1A1A), // より濃い色でコントラスト向上
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
      return Colors.white; // 純白で視認性向上
    }
  }

  // セカンダリカード背景色を取得（テーマに応じた色を返す）
  Color getSecondaryCardColor(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return const Color(0xFF2A2A2A);
    } else {
      return const Color(0xFFF5F5F5); // より明るいグレーで階層化
    }
  }

  // テキスト色を取得（テーマに応じた色を返す）
  Color getTextColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyLarge?.color ?? 
           (theme.brightness == Brightness.dark ? Colors.white : const Color(0xFF1A1A1A));
  }

  // セカンダリテキスト色を取得（テーマに応じた色を返す）
  Color getSecondaryTextColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium?.color ?? 
           (theme.brightness == Brightness.dark ? Colors.grey[400]! : const Color(0xFF5A5A5A));
  }
}

