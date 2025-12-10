import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// ホーム画面の投稿の並び順
enum SortOrder {
  random,   // ランダム
  newest,   // 新しい順
  oldest,   // 古い順
}

/// 並び順設定を管理するサービス
class SortOrderService {
  static const String _key = 'home_sort_order';

  /// 並び順を取得（デフォルトはランダム）
  static Future<SortOrder> getSortOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      
      if (value == null) {
        return SortOrder.random; // デフォルトはランダム
      }

      switch (value) {
        case 'random':
          return SortOrder.random;
        case 'newest':
          return SortOrder.newest;
        case 'oldest':
          return SortOrder.oldest;
        default:
          return SortOrder.random;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [SortOrderService] 並び順取得エラー: $e');
      }
      return SortOrder.random; // エラー時はデフォルト値を返す
    }
  }

  /// 並び順を保存
  static Future<bool> setSortOrder(SortOrder sortOrder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String value;
      
      switch (sortOrder) {
        case SortOrder.random:
          value = 'random';
          break;
        case SortOrder.newest:
          value = 'newest';
          break;
        case SortOrder.oldest:
          value = 'oldest';
          break;
      }

      final success = await prefs.setString(_key, value);
      
      if (kDebugMode) {
        debugPrint('📝 [SortOrderService] 並び順を保存: $value, 成功: $success');
      }
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [SortOrderService] 並び順保存エラー: $e');
      }
      return false;
    }
  }

  /// 並び順の表示名を取得
  static String getSortOrderDisplayName(SortOrder sortOrder) {
    switch (sortOrder) {
      case SortOrder.random:
        return 'ランダム';
      case SortOrder.newest:
        return '新しい順';
      case SortOrder.oldest:
        return '古い順';
    }
  }
}

