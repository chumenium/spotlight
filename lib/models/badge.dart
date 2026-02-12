import 'package:flutter/material.dart';
import '../utils/spotlight_colors.dart';

/// バッジモデル
class Badge {
  final int id;
  final String name;
  final IconData icon;
  final int requiredSpotlights;
  final Color badgeColor;

  const Badge({
    required this.id,
    required this.name,
    required this.icon,
    required this.requiredSpotlights,
    required this.badgeColor,
  });
}

/// バッジ管理クラス
class BadgeManager {
  /// 全バッジのリスト
  static List<Badge> get allBadges => [
        Badge(
          id: 0,
          name: '微星',
          icon: Icons.auto_awesome,
          requiredSpotlights: 0,  //バッジを貰うための条件
          badgeColor: SpotLightColors.getSpotlightColor(0),
        ),
        Badge(
          id: 1,
          name: '新星',
          icon: Icons.star,
          requiredSpotlights: 1,
          badgeColor: SpotLightColors.getSpotlightColor(1),
        ),
        Badge(
          id: 2,
          name: '耀星',
          icon: Icons.rocket_launch,
          requiredSpotlights: 5,
          badgeColor: SpotLightColors.getSpotlightColor(2),
        ),
        Badge(
          id: 3,
          name: '烈星',
          icon: Icons.wb_sunny,
          requiredSpotlights: 10,
          badgeColor: SpotLightColors.getSpotlightColor(3),
        ),
        Badge(
          id: 4,
          name: '超新星',
          icon: Icons.local_fire_department,
          requiredSpotlights: 20,
          badgeColor: SpotLightColors.getSpotlightColor(4),
        ),
        Badge(
          id: 5,
          name: '紅巨星',
          icon: Icons.workspace_premium,
          requiredSpotlights: 30,
          badgeColor: SpotLightColors.getSpotlightColor(5),
        ),
        Badge(
          id: 6,
          name: '白煌星',
          icon: Icons.bolt,
          requiredSpotlights: 50,
          badgeColor: SpotLightColors.getSpotlightColor(6),
        ),
        Badge(
          id: 7,
          name: '星王',
          icon: Icons.diamond,
          requiredSpotlights: 100,
          badgeColor: SpotLightColors.getSpotlightColor(7),
        ),
        Badge(
          id: 999,
          name: '管理者',
          icon: Icons.admin_panel_settings,
          requiredSpotlights: 0,
          badgeColor: SpotLightColors.getSpotlightColor(999),
        ),
      ];

  /// スポットライト数に基づいて解放されたバッジのリストを取得
  static List<Badge> getUnlockedBadges(int spotlightCount) {
    return allBadges.where((badge) => badge.requiredSpotlights <= spotlightCount).toList();
  }

  /// スポットライト数に基づいて解放されたバッジのIDリストを取得
  static List<int> getUnlockedBadgeIndices(int spotlightCount) {
    return getUnlockedBadges(spotlightCount).map((badge) => badge.id).toList();
  }

  /// IDでバッジを取得
  static Badge? getBadgeById(int id) {
    try {
      return allBadges.firstWhere((badge) => badge.id == id);
    } catch (e) {
      return null;
    }
  }
}

/// 広告視聴バッジモデル
class RewardAdBadge {
  final int id;
  final String name;
  final IconData icon;
  final int requiredViews;
  final Color badgeColor;

  const RewardAdBadge({
    required this.id,
    required this.name,
    required this.icon,
    required this.requiredViews,
    required this.badgeColor,
  });
}

/// 広告視聴バッジ管理
class RewardAdBadgeManager {
  static List<RewardAdBadge> get allBadges => const [
        RewardAdBadge(
          id: 1001,
          name: '広告ルーキー',
          icon: Icons.ondemand_video,
          requiredViews: 1,
          badgeColor: Color(0xFF4FC3F7),
        ),
        RewardAdBadge(
          id: 1002,
          name: '広告ビギナー',
          icon: Icons.play_circle_fill,
          requiredViews: 3,
          badgeColor: Color(0xFF4DD0E1),
        ),
        RewardAdBadge(
          id: 1003,
          name: '広告サポーター',
          icon: Icons.volunteer_activism,
          requiredViews: 5,
          badgeColor: Color(0xFF26A69A),
        ),
        RewardAdBadge(
          id: 1004,
          name: '広告ブースター',
          icon: Icons.flash_on,
          requiredViews: 10,
          badgeColor: Color(0xFF66BB6A),
        ),
        RewardAdBadge(
          id: 1005,
          name: '広告エキスパート',
          icon: Icons.stars,
          requiredViews: 25,
          badgeColor: Color(0xFFFFB74D),
        ),
        RewardAdBadge(
          id: 1006,
          name: '広告マスター',
          icon: Icons.workspace_premium,
          requiredViews: 50,
          badgeColor: Color(0xFFFF8A65),
        ),
        RewardAdBadge(
          id: 1007,
          name: '広告レジェンド',
          icon: Icons.military_tech,
          requiredViews: 100,
          badgeColor: Color(0xFFBA68C8),
        ),
      ];

  static List<RewardAdBadge> getUnlockedBadges(int watchCount) {
    return allBadges.where((b) => b.requiredViews <= watchCount).toList();
  }
}

