import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'history_list_screen.dart';
import 'playlist_list_screen.dart';
import 'spotlight_list_screen.dart';
import 'help_screen.dart';
import 'jwt_test_screen.dart';
import '../utils/spotlight_colors.dart';
import '../auth/auth_provider.dart';
import '../config/app_config.dart';
import '../services/jwt_service.dart';
import '../models/badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _spotlightCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSpotlightCount();
  }

  Future<void> _fetchSpotlightCount() async {
    if (kDebugMode) {
      debugPrint('🌟 バッジシステム: スポットライト数取得開始');
    }

    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ JWTトークンが取得できません');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (kDebugMode) {
        debugPrint('📡 リクエスト送信: ${AppConfig.backendUrl}/api/users/profile');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/users/profile'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        debugPrint('📥 レスポンス受信: ${response.statusCode}');
        debugPrint('📄 レスポンス内容: ${response.body}');
      }

      if (mounted && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _spotlightCount = data['spotlightnum'] ?? 0;
          _isLoading = false;
        });
        
        if (kDebugMode) {
          debugPrint('✅ スポットライト数取得成功: $_spotlightCount');
          debugPrint('🎖️ 解放バッジ数: ${BadgeManager.getUnlockedBadges(_spotlightCount).length}/8');
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ HTTPエラー: ${response.statusCode}');
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ スポットライト数取得エラー: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // プロフィールヘッダー
            _buildProfileHeader(),
            
            const SizedBox(height: 20),
            
            // スポットライトセクション
            _buildSpotlightSection(context),
            
            const SizedBox(height: 20),
            
            // 履歴セクション
            _buildHistorySection(context),
            
            const SizedBox(height: 20),
            
            // 再生リストセクション
            _buildPlaylistSection(context),
            
            const SizedBox(height: 20),
            
            // バッジセクション
            _buildBadgeSection(),
            
            const SizedBox(height: 20),
            
            // 統計・ヘルプセクション
            _buildStatsAndHelpSection(context),
            
            const SizedBox(height: 20),
            
            // ログアウトボタン
            _buildLogoutButton(context),
            
            const SizedBox(height: 100), // ボトムナビゲーション分の余白
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.currentUser;
          // バックエンドから取得したDBのusernameを優先表示
          final displayName = user?.backendUsername ?? 'ユーザー';
          
          return Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFFFF6B35),
                backgroundImage: user?.avatarUrl != null
                    ? NetworkImage(user!.avatarUrl!)
                    : null,
                child: user?.avatarUrl == null
                    ? const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 最大のバッジを表示
                        _buildMaxBadgeIcon(),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  // 設定画面への遷移
                },
                icon: const Icon(
                  Icons.settings,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMaxBadgeIcon() {
    // 解放されているバッジの中で最大のバッジを取得
    final unlockedBadges = BadgeManager.getUnlockedBadges(_spotlightCount);
    if (unlockedBadges.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final maxBadge = unlockedBadges.last; // 最後のバッジが最大（requiredSpotlightsが最大）
    
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: SpotLightColors.getGradient(maxBadge.id),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: maxBadge.badgeColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        maxBadge.icon,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildSpotlightSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'スポットライト',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SpotlightListScreen(),
                    ),
                  );
                },
                child: const Text(
                  '全て表示',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 8,
            itemBuilder: (context, index) {
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          // スポットライトアイコン
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: SpotLightColors.getSpotlightColor(index),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: SpotLightColors.getSpotlightColor(index).withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'スポットライト投稿 ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '履歴',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryListScreen(),
                    ),
                  );
                },
                child: const Text(
                  '全て表示',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 10,
            itemBuilder: (context, index) {
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '投稿タイトル ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '再生リスト',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlaylistListScreen(),
                    ),
                  );
                },
                child: const Text(
                  '全て表示',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Icon(
                              Icons.playlist_play,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${(index + 1) * 3}件',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '再生リスト ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeSection() {
    final unlockedBadges = BadgeManager.getUnlockedBadges(_spotlightCount);
    final allBadges = BadgeManager.allBadges;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'バッジ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${unlockedBadges.length}/${allBadges.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: allBadges.length,
            itemBuilder: (context, index) {
              final badge = allBadges[index];
              final isUnlocked = unlockedBadges.any((b) => b.id == badge.id);
              
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: isUnlocked 
                            ? LinearGradient(
                                colors: SpotLightColors.getGradient(index),
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isUnlocked ? null : Colors.grey[800],
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: isUnlocked
                            ? [
                                BoxShadow(
                                  color: badge.badgeColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isUnlocked ? badge.icon : Icons.lock,
                        color: isUnlocked ? Colors.white : Colors.grey[600],
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badge.name,
                      style: TextStyle(
                        color: isUnlocked ? Colors.white : Colors.grey[600],
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsAndHelpSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 総視聴時間
          
          
          const SizedBox(height: 16),
          
          // ヘルプ・フィードバック
          _buildMenuTile(
            icon: Icons.help_outline,
            title: 'ヘルプ',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpScreen(),
                ),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.feedback_outlined,
            title: 'フィードバック',
            onTap: () {},
          ),
          _buildMenuTile(
            icon: Icons.info_outline,
            title: 'アプリについて',
            onTap: () {},
          ),
          _buildMenuTile(
            icon: Icons.security,
            title: 'JWTトークンテスト',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const JwtTestScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.grey[400],
          size: 24,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
          size: 20,
        ),
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final isGuest = authProvider.currentUser?.id == 'guest';
          
          return Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade600,
                  Colors.red.shade700,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  // 確認ダイアログを表示
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF2A2A2A),
                      title: const Text(
                        'ログアウト',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        isGuest 
                            ? 'ログイン画面に戻りますか？' 
                            : 'ログアウトしてログイン画面に戻りますか？',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text(
                            'キャンセル',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            isGuest ? '戻る' : 'ログアウト',
                            style: TextStyle(color: Colors.red.shade400),
                          ),
                        ),
                      ],
                    ),
                  );

                  // ユーザーが確認した場合
                  if (confirmed == true && context.mounted) {
                    // ログアウト処理（ゲストモードもログイン中も同じ処理）
                    await authProvider.logout();
                    
                    if (kDebugMode) {
                      debugPrint('✅ ログアウト完了: ログイン画面へ遷移');
                    }
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isGuest ? Icons.exit_to_app : Icons.logout,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isGuest ? 'ログイン画面へ戻る' : 'ログアウト',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
