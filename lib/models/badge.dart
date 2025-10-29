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
          name: 'スターダスト',
          icon: Icons.auto_awesome,
          requiredSpotlights: 0,
          badgeColor: SpotLightColors.getSpotlightColor(0),
        ),
        Badge(
          id: 1,
          name: 'スーパースター',
          icon: Icons.star,
          requiredSpotlights: 1,
          badgeColor: SpotLightColors.getSpotlightColor(1),
        ),
        Badge(
          id: 2,
          name: 'ライジングスター',
          icon: Icons.rocket_launch,
          requiredSpotlights: 5,
          badgeColor: SpotLightColors.getSpotlightColor(2),
        ),
        Badge(
          id: 3,
          name: 'シャイニング',
          icon: Icons.wb_sunny,
          requiredSpotlights: 10,
          badgeColor: SpotLightColors.getSpotlightColor(3),
        ),
        Badge(
          id: 4,
          name: 'フェニックス',
          icon: Icons.local_fire_department,
          requiredSpotlights: 20,
          badgeColor: SpotLightColors.getSpotlightColor(4),
        ),
        Badge(
          id: 5,
          name: 'レジェンド',
          icon: Icons.workspace_premium,
          requiredSpotlights: 30,
          badgeColor: SpotLightColors.getSpotlightColor(5),
        ),
        Badge(
          id: 6,
          name: 'ゴッド',
          icon: Icons.bolt,
          requiredSpotlights: 50,
          badgeColor: SpotLightColors.getSpotlightColor(6),
        ),
        Badge(
          id: 7,
          name: 'エターナル',
          icon: Icons.diamond,
          requiredSpotlights: 100,
          badgeColor: SpotLightColors.getSpotlightColor(7),
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
      return allBadges[id];
    } catch (e) {
      return null;
    }
  }
}

