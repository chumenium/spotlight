import 'package:flutter/material.dart';

class SpotLightColors {
  // プライマリカラー（オレンジ系）
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color deepOrange = Color(0xFFE55A2B);
  static const Color lightOrange = Color(0xFFFF8A65);
  
  // レッド系
  static const Color warmRed = Color(0xFFFF5722);
  static const Color coralRed = Color(0xFFFF7043);
  static const Color tomatoRed = Color(0xFFFF5722);
  
  // ピンク系
  static const Color warmPink = Color(0xFFE91E63);
  static const Color rosePink = Color(0xFFF06292);
  static const Color salmonPink = Color(0xFFFF8A80);
  
  // イエロー系
  static const Color goldenYellow = Color(0xFFFFC107);
  static const Color amberYellow = Color(0xFFFFB300);
  static const Color warmYellow = Color(0xFFFFD54F);
  
  // オレンジ系
  static const Color burntOrange = Color(0xFFFF9800);
  static const Color tangerine = Color(0xFFFFAB40);
  static const Color peach = Color(0xFFFFCC80);
  
  // パープル系（暖色寄り）
  static const Color warmPurple = Color(0xFF9C27B0);
  static const Color magenta = Color(0xFFE91E63);
  static const Color plum = Color(0xFFBA68C8);
  
  // ブラウン系
  static const Color warmBrown = Color(0xFF8D6E63);
  static const Color caramel = Color(0xFFA1887F);
  static const Color coffee = Color(0xFF6D4C41);
  
  // グラデーション用
  static const List<Color> orangeGradient = [
    Color(0xFFFF6B35),
    Color(0xFFFF8A65),
  ];
  
  static const List<Color> sunsetGradient = [
    Color(0xFFFF5722),
    Color(0xFFFF9800),
    Color(0xFFFFC107),
  ];
  
  static const List<Color> warmGradient = [
    Color(0xFFE91E63),
    Color(0xFFFF5722),
    Color(0xFFFF9800),
  ];
  
  static const List<Color> fireGradient = [
    Color(0xFFFF6B35),
    Color(0xFFFF5722),
    Color(0xFFE91E63),
  ];
  
  // スポットライト用ランダムカラー
  static const List<Color> spotlightColors = [
    primaryOrange,
    warmRed,
    warmPink,
    goldenYellow,
    burntOrange,
    warmPurple,
    coralRed,
    amberYellow,
    rosePink,
    tangerine,
  ];
  
  // インデックスに基づいて色を取得
  static Color getSpotlightColor(int index) {
    return spotlightColors[index % spotlightColors.length];
  }
  
  // ランダムなスポットライトカラーを取得
  static Color getRandomSpotlightColor() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return spotlightColors[random % spotlightColors.length];
  }
  
  // グラデーションを取得
  static List<Color> getGradient(int index) {
    final gradients = [orangeGradient, sunsetGradient, warmGradient, fireGradient];
    return gradients[index % gradients.length];
  }
  
  // カラーの明度を調整
  static Color lighten(Color color, double amount) {
    return Color.lerp(color, Colors.white, amount) ?? color;
  }
  
  static Color darken(Color color, double amount) {
    return Color.lerp(color, Colors.black, amount) ?? color;
  }
  
  // カラーの透明度を調整
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
}
