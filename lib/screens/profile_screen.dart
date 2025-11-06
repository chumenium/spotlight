import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'history_list_screen.dart';
import 'playlist_list_screen.dart';
import 'spotlight_list_screen.dart';
import 'help_screen.dart';
import 'jwt_test_screen.dart';
import '../utils/spotlight_colors.dart';
import '../auth/auth_provider.dart';
import '../config/app_config.dart';
import '../services/jwt_service.dart';
import '../services/user_service.dart';
import '../services/icon_update_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _spotlightCount = 0;
  final ImagePicker _imagePicker = ImagePicker();
  
  /// アイコンキャッシュをクリア（アイコン更新時に呼び出し）
  Future<void> _clearIconCache() async {
    // cached_network_imageのキャッシュをクリア
    try {
      await CachedNetworkImage.evictFromCache('${AppConfig.backendUrl}/icon/default_icon.jpg');
      if (kDebugMode) {
        debugPrint('🗑️ アイコンキャッシュをクリアしました');
      }
    } catch (e) {
      // エラーは無視
    }
  }
  
  // 安全なメッセージ表示のためのヘルパーメソッド
  void _showSafeSnackBar(String message, {Color? backgroundColor}) {
    if (mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor ?? Colors.red,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ SnackBar表示に失敗: $e - メッセージ: $message');
        }
      }
    }
  }

  // 安全なダイアログ表示のためのヘルパーメソッド
  Future<T?> _showSafeDialog<T>(Widget dialog) async {
    if (!mounted) return null;
    
    try {
      return await showDialog<T>(
        context: context,
        barrierDismissible: true, // バックボタンで閉じられるように変更
        builder: (context) => dialog,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ ダイアログ表示に失敗: $e');
      }
      return null;
    }
  }

  // ローディングダイアログの状態管理
  bool _isLoadingDialogShown = false;

  // 安全なローディングダイアログ表示
  void _showSafeLoadingDialog() {
    if (mounted && !_isLoadingDialogShown) {
      try {
        _isLoadingDialogShown = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false, // バックボタンを無効化
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      } catch (e) {
        _isLoadingDialogShown = false;
        if (kDebugMode) {
          debugPrint('⚠️ ローディングダイアログ表示に失敗: $e');
        }
      }
    }
  }

  // 安全なローディングダイアログを閉じる
  void _closeSafeLoadingDialog() {
    if (mounted && _isLoadingDialogShown) {
      try {
        _isLoadingDialogShown = false;
        Navigator.of(context).pop();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ ローディングダイアログのクローズに失敗: $e');
        }
      }
    }
  }

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
        });
        
        if (kDebugMode) {
          debugPrint('✅ スポットライト数取得成功: $_spotlightCount');
          debugPrint('🎖️ 解放バッジ数: ${BadgeManager.getUnlockedBadges(_spotlightCount).length}/8');
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ HTTPエラー: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ スポットライト数取得エラー: $e');
      }
      // エラー時の処理（特に状態更新は不要）
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
              GestureDetector(
                onTap: () => _showIconMenu(context, authProvider),
                child: Builder(
                  builder: (context) {
                    return CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFFFF6B35),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user?.avatarUrl ?? '${AppConfig.backendUrl}/icon/default_icon.jpg',
                          fit: BoxFit.cover,
                          memCacheWidth: 160,
                          memCacheHeight: 160,
                          httpHeaders: const {
                            'Accept': 'image/webp,image/avif,image/*, */*;q=0.8',
                            'User-Agent': 'Flutter-Spotlight/1.0',
                          },
                          placeholder: (context, url) => Container(),
                          errorWidget: (context, url, error) => Container(),
                          fadeInDuration: const Duration(milliseconds: 200),
                        ),
                      ),
                    );
                  },
                ),
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

  /// アイコンメニューを表示
  void _showIconMenu(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.image_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'アイコンを設定',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadIcon(context, authProvider);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                title: const Text(
                  'アイコンを削除',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteIcon(context, authProvider);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// 画像を選択してアップロード
  Future<void> _pickAndUploadIcon(BuildContext context, AuthProvider authProvider) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      if (!mounted) return;

      // ローディング表示
      _showSafeLoadingDialog();

      final imageFile = File(pickedFile.path);
      final user = authProvider.currentUser;
      final username = user?.backendUsername;
      
      if (username == null) {
        _closeSafeLoadingDialog();
        if (mounted) {
          _showSafeSnackBar('ユーザー名が取得できません');
        }
        return;
      }

      final iconPath = await UserService.uploadIcon(username, imageFile);
      _closeSafeLoadingDialog();
      
      if (!mounted) return;

      if (iconPath != null) {
        if (kDebugMode) {
          debugPrint('📸 アイコンアップロード成功: $iconPath');
        }
        
        // 4. 画像のURLを取得
        final newIconUrl = '${AppConfig.backendUrl}/icon/$iconPath';
        
        if (kDebugMode) {
          debugPrint('🔗 新しいアイコンURL: $newIconUrl');
        }
        
        // 古いキャッシュをクリア
        await _clearIconCache();
        
        // 5. フロントにURLを元に画像を設定 & 6. キャッシュを更新
        // サーバー側で画像処理が完了するまで少し待機
        await Future.delayed(const Duration(milliseconds: 500));
        
        try {
          if (kDebugMode) {
            debugPrint('📥 新しい画像を事前ロード中...');
          }
          
          // cached_network_imageで新しい画像を事前にキャッシュ
          await CachedNetworkImage.evictFromCache(newIconUrl);
          
          if (kDebugMode) {
            debugPrint('✅ 新しい画像をキャッシュに準備しました');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ 画像事前ロードエラー: $e（続行します）');
          }
        }
        
        // バックエンドから最新のユーザー情報を再取得して反映
        final refreshed = await authProvider.refreshUserInfoFromBackend();
        
        if (kDebugMode) {
          debugPrint('📡 ユーザー情報再取得: ${refreshed ? "成功" : "失敗"}');
        }
        
        // 他の画面にアイコン更新を通知（ホーム画面など）
        IconUpdateService().notifyIconUpdate(
          username,
          iconPath: iconPath,
        );
        
        if (mounted) {
          // 画面を強制的に再構築して新しいアイコンを表示
          setState(() {});
          
          if (kDebugMode) {
            debugPrint('🔄 プロフィール画面を再構築しました');
          }
          
          // 7. レスポンスメッセージ表示
          if (refreshed) {
            _showSafeSnackBar('アイコンを設定しました', backgroundColor: Colors.green);
          } else {
            // 再取得に失敗した場合は、レスポンスのiconPathを使用
            await authProvider.updateUserInfo(iconPath: iconPath);
            _showSafeSnackBar('アイコンを設定しました', backgroundColor: Colors.green);
          }
        }
      } else {
        if (mounted) {
          _showSafeSnackBar('アイコンの設定に失敗しました');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ アイコンアップロードエラー: $e');
      }
      
      _closeSafeLoadingDialog();
      
      // 7. エラーメッセージ表示
      if (mounted) {
        String errorMessage = 'エラーが発生しました';
        
        // エラーの種類に応じてメッセージをカスタマイズ
        if (e.toString().contains('timeout') || e.toString().contains('タイムアウト')) {
          errorMessage = '通信がタイムアウトしました';
        } else if (e.toString().contains('network') || e.toString().contains('ネットワーク')) {
          errorMessage = 'ネットワークエラーが発生しました';
        } else if (e.toString().contains('404')) {
          errorMessage = 'サーバーが見つかりません';
        } else if (e.toString().contains('500')) {
          errorMessage = 'サーバーエラーが発生しました';
        }
        
        _showSafeSnackBar(errorMessage, backgroundColor: Colors.red);
      }
    }
  }

  /// アイコンを削除
  Future<void> _deleteIcon(BuildContext context, AuthProvider authProvider) async {
    // 確認ダイアログを表示
    final confirmed = await _showSafeDialog<bool>(
      Builder(
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            'アイコンを削除',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'アイコンを削除しますか？',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'キャンセル',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '削除',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    // ローディング表示
    _showSafeLoadingDialog();

    final user = authProvider.currentUser;
    final username = user?.backendUsername;
    
    if (username == null) {
      _closeSafeLoadingDialog();
      if (mounted) {
        _showSafeSnackBar('ユーザー名が取得できません');
      }
      return;
    }

    final success = await UserService.deleteIcon(username);
    _closeSafeLoadingDialog();
    
    if (!mounted) return;

    if (success) {
      if (kDebugMode) {
        debugPrint('🗑️ アイコン削除成功');
      }
      
      // アイコンキャッシュをクリア（アイコン削除を反映するため）
      _clearIconCache();
      
      // デフォルトアイコンの処理
      await _setDefaultIcon(authProvider);
      
      // サーバー側で処理が完了するまで待機（300ms）
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (kDebugMode) {
        debugPrint('📤 アイコン削除通知を送信: username=$username, iconPath=null (default)');
      }
      
      // 他の画面にアイコン削除を通知（ホーム画面など）
      IconUpdateService().notifyIconUpdate(
        username,
        iconPath: null, // nullでdefault_icon.jpgを使用
      );
      
      if (mounted) {
        // 画面を強制的に再構築してデフォルトアイコンを表示
        setState(() {});
        
        if (kDebugMode) {
          debugPrint('🔄 プロフィール画面を再構築しました（デフォルトアイコン）');
        }
        
        _showSafeSnackBar('アイコンをデフォルトに変更しました', backgroundColor: Colors.green);
        
        if (kDebugMode) {
          debugPrint('✅ アイコン削除完了: デフォルトアイコンに変更');
        }
      }
    } else {
      // 7. エラーメッセージ表示
      if (mounted) {
        _showSafeSnackBar('アイコンの削除に失敗しました', backgroundColor: Colors.red);
      }
    }
  }

  /// デフォルトアイコンを設定
  Future<void> _setDefaultIcon(AuthProvider authProvider) async {
    // バックエンドのデフォルトアイコンパスを設定
    const defaultIconPath = '/icon/default_icon.jpg';
    final defaultIconUrl = '${AppConfig.backendUrl}$defaultIconPath';
    
    if (kDebugMode) {
      debugPrint('🖼️ デフォルトアイコン確認中: $defaultIconUrl');
    }
    
    try {
      // バックエンドのデフォルトアイコンが利用可能かを確認
      final response = await http.head(Uri.parse(defaultIconUrl)).timeout(
        const Duration(seconds: 3),
        onTimeout: () => http.Response('', 404),
      );
      
      if (response.statusCode == 200) {
        // デフォルトアイコンが存在する場合は設定
        await authProvider.updateUserInfo(iconPath: defaultIconPath);
        
        if (kDebugMode) {
          debugPrint('✅ バックエンドのデフォルトアイコンを設定: $defaultIconPath');
        }
      } else {
        // デフォルトアイコンが存在しない場合はnullを設定（ローカルのPersonアイコンを表示）
        await authProvider.updateUserInfo(iconPath: '');
        
        if (kDebugMode) {
          debugPrint('⚠️ バックエンドのデフォルトアイコンが存在しません (${response.statusCode})');
          debugPrint('🖼️ ローカルのデフォルトアイコン（Person）を使用します');
        }
      }
    } catch (e) {
      // ネットワークエラーの場合もnullを設定（ローカルのPersonアイコンを表示）
      await authProvider.updateUserInfo(iconPath: '');
      
      if (kDebugMode) {
        debugPrint('❌ デフォルトアイコン確認エラー: $e');
        debugPrint('🖼️ ローカルのデフォルトアイコン（Person）を使用します');
      }
    }
    
    // アイコンキャッシュもクリアしてデフォルトアイコンを確実に表示
    _clearIconCache();
    
    // 画面を再描画
    if (mounted) {
      setState(() {});
    }
  }
}
