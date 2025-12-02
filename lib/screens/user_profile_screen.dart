import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../models/badge.dart';
import '../services/post_service.dart';
import '../services/jwt_service.dart';
import '../config/app_config.dart';
import '../utils/spotlight_colors.dart';
import '../widgets/robust_network_image.dart';
import '../providers/navigation_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 他ユーザーのプロフィール画面
class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? username;
  final String? userIconUrl;
  final String? userIconPath;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.username,
    this.userIconUrl,
    this.userIconPath,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // ユーザー情報
  String? _displayUsername;
  String? _iconPath;
  String? _iconUrl;
  bool? _isAdmin;
  int _spotlightCount = 0;
  bool _isLoadingProfile = true;
  bool _isLoadingPosts = false;
  String? _errorMessage;
  String? _resolvedUserId; // プロフィール情報取得後に解決されたuserId

  // 投稿リスト
  List<Post> _userPosts = [];

  @override
  void initState() {
    super.initState();
    _displayUsername = widget.username;
    _iconUrl = widget.userIconUrl;
    _iconPath = widget.userIconPath;
    
    if (kDebugMode) {
      debugPrint('👤 UserProfileScreen初期化:');
      debugPrint('  userId: ${widget.userId}');
      debugPrint('  username: ${widget.username}');
      debugPrint('  userIconUrl: ${widget.userIconUrl}');
      debugPrint('  userIconPath: ${widget.userIconPath}');
    }
    
    _fetchUserProfile();
    // 投稿取得はプロフィール情報取得後に実行（userIdが解決されるため）
  }

  /// ユーザーのプロフィール情報を取得
  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _errorMessage = null;
    });

    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        setState(() {
          _errorMessage = '認証が必要です';
          _isLoadingProfile = false;
        });
        return;
      }

      // userIdが空の場合は、usernameのみで検索を試みる
      final requestBody = <String, dynamic>{};
      
      if (widget.userId.isNotEmpty && widget.userId.trim().isNotEmpty) {
        // firebase_uidで検索
        requestBody['firebase_uid'] = widget.userId;
      } else if (widget.username != null && widget.username!.isNotEmpty) {
        // usernameで検索（バックエンドがサポートしている場合）
        requestBody['username'] = widget.username;
        if (kDebugMode) {
          debugPrint('👤 userIdが空のため、usernameで検索を試みます: ${widget.username}');
        }
      } else {
        setState(() {
          _errorMessage = 'ユーザー情報が不足しています';
          _isLoadingProfile = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/users/getusername'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          debugPrint('👤 プロフィール情報取得レスポンス:');
          debugPrint('  status: ${responseData['status']}');
          debugPrint('  data: ${responseData['data']}');
        }
        
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final userInfo = responseData['data'] as Map<String, dynamic>;
          
          if (kDebugMode) {
            debugPrint('👤 取得したユーザー情報:');
            debugPrint('  username: ${userInfo['username']}');
            debugPrint('  iconimgpath: ${userInfo['iconimgpath']}');
            debugPrint('  admin: ${userInfo['admin']}');
          }
          
          // レスポンスからfirebase_uidを取得（投稿取得に使用）
          final resolvedFirebaseUid = (userInfo['firebase_uid'] as String?)?.isNotEmpty == true
              ? userInfo['firebase_uid'] as String
              : (widget.userId.isNotEmpty ? widget.userId : null);
          
          if (kDebugMode) {
            debugPrint('👤 解決されたfirebase_uid: $resolvedFirebaseUid');
          }
          
          if (mounted) {
            setState(() {
              _displayUsername = userInfo['username'] as String? ?? widget.username;
              _iconPath = userInfo['iconimgpath'] as String? ?? widget.userIconPath;
              _isAdmin = userInfo['admin'] as bool? ?? false;
              _resolvedUserId = resolvedFirebaseUid;
              
              // アイコンURLを生成
              if (_iconPath != null && _iconPath!.isNotEmpty) {
                if (_iconPath!.startsWith('http://') || 
                    _iconPath!.startsWith('https://')) {
                  _iconUrl = _iconPath;
                } else {
                  _iconUrl = '${AppConfig.backendUrl}$_iconPath';
                }
              } else {
                _iconUrl = widget.userIconUrl;
              }
              
              _isLoadingProfile = false;
            });
          }
          
          // 解決されたuserIdで投稿を取得
          if (resolvedFirebaseUid != null && resolvedFirebaseUid.isNotEmpty) {
            _fetchUserPosts();
          } else {
            if (kDebugMode) {
              debugPrint('⚠️ firebase_uidが解決できなかったため、投稿を取得できません');
            }
          }
          
          // スポットライト数を取得（ユーザーの投稿から集計）
          _calculateSpotlightCount();
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = 'ユーザー情報の取得に失敗しました';
              _isLoadingProfile = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'ユーザー情報の取得に失敗しました';
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ユーザープロフィール取得エラー: $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = 'エラーが発生しました';
          _isLoadingProfile = false;
        });
      }
    }
  }

  /// スポットライト数を計算（ユーザーの投稿から集計）
  void _calculateSpotlightCount() {
    int totalSpotlights = 0;
    for (var post in _userPosts) {
      totalSpotlights += post.likes;
    }
    if (mounted) {
      setState(() {
        _spotlightCount = totalSpotlights;
      });
    }
  }

  /// ユーザーの投稿を取得
  Future<void> _fetchUserPosts() async {
    setState(() {
      _isLoadingPosts = true;
    });

    try {
      // 解決されたuserIdを使用（空の場合はwidget.userIdを使用）
      final targetUserId = _resolvedUserId ?? widget.userId;
      
      if (targetUserId.isEmpty || targetUserId.trim().isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ ユーザーIDが解決できなかったため、投稿を取得できません');
        }
        if (mounted) {
          setState(() {
            _isLoadingPosts = false;
          });
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('👤 ユーザー投稿取得開始: userId=$targetUserId');
      }
      
      final posts = await PostService.getUserPostsByUserId(targetUserId);
      
      if (kDebugMode) {
        debugPrint('👤 ユーザー投稿取得完了: ${posts.length}件');
        if (posts.isNotEmpty) {
          debugPrint('👤 最初の投稿のuserId: ${posts.first.userId}');
          debugPrint('👤 期待されるuserId: ${widget.userId}');
          if (posts.first.userId != widget.userId) {
            debugPrint('⚠️ 警告: 取得した投稿のユーザーIDが一致しません！');
          }
        }
      }
      
      if (mounted) {
        // 取得した投稿が指定したユーザーのもののみをフィルタリング
        final filteredPosts = posts.where((post) => post.userId == widget.userId).toList();
        
        if (kDebugMode && filteredPosts.length != posts.length) {
          debugPrint('👤 フィルタリング: ${posts.length}件 -> ${filteredPosts.length}件');
        }
        
        setState(() {
          _userPosts = filteredPosts;
          _isLoadingPosts = false;
        });
        _calculateSpotlightCount();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ユーザー投稿取得エラー: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _displayUsername ?? 'ユーザープロフィール',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(
                color: SpotLightColors.primaryOrange,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          _fetchUserProfile();
                          _fetchUserPosts();
                        },
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _fetchUserProfile();
                    await _fetchUserPosts();
                  },
                  color: SpotLightColors.primaryOrange,
                  child: CustomScrollView(
                    slivers: [
                      // プロフィールヘッダー
                      SliverToBoxAdapter(
                        child: _buildProfileHeader(),
                      ),
                      // バッジ一覧
                      SliverToBoxAdapter(
                        child: _buildBadgeSection(),
                      ),
                      // 投稿一覧
                      SliverToBoxAdapter(
                        child: _buildPostsSection(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    // アイコンURLを生成
    String? iconUrl = _iconUrl;
    if (iconUrl == null || iconUrl.isEmpty) {
      if (_iconPath != null && _iconPath!.isNotEmpty) {
        if (_iconPath!.startsWith('http://') || 
            _iconPath!.startsWith('https://')) {
          iconUrl = _iconPath;
        } else {
          iconUrl = '${AppConfig.backendUrl}$_iconPath';
        }
      } else {
        iconUrl = '${AppConfig.backendUrl}/icon/default_icon.jpg';
      }
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // アイコン
          CircleAvatar(
            radius: 50,
            backgroundColor: SpotLightColors.primaryOrange,
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: iconUrl!,
                fit: BoxFit.cover,
                width: 100,
                height: 100,
                httpHeaders: const {
                  'Accept': 'image/webp,image/avif,image/*,*/*;q=0.8',
                  'User-Agent': 'Flutter-Spotlight/1.0',
                },
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (context, url) => Container(
                  color: SpotLightColors.primaryOrange,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: SpotLightColors.primaryOrange,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ユーザー名
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _displayUsername ?? 'ユーザー',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              // 管理者バッジ
              if (_isAdmin == true) _buildAdminBadgeIcon(),
            ],
          ),
          const SizedBox(height: 8),
          // スポットライト数
          Text(
            '${_spotlightCount} スポットライト',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminBadgeIcon() {
    final adminBadge = BadgeManager.getBadgeById(999);
    if (adminBadge == null) return const SizedBox.shrink();
    
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: SpotLightColors.getGradient(adminBadge.id),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: adminBadge.badgeColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        adminBadge.icon,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildBadgeSection() {
    final unlockedBadges = BadgeManager.getUnlockedBadges(_spotlightCount);
    
    // 管理者バッジを追加
    final displayBadges = List<Badge>.from(unlockedBadges);
    if (_isAdmin == true) {
      final adminBadge = BadgeManager.getBadgeById(999);
      if (adminBadge != null && !displayBadges.any((b) => b.id == 999)) {
        displayBadges.add(adminBadge);
      }
    }

    // 管理者バッジと開発者バッジを除外した通常バッジ
    final normalBadges = displayBadges.where((b) => b.id != 999 && b.id != 777).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'バッジ',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          normalBadges.isEmpty
              ? Text(
                  'まだバッジがありません',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                )
              : SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: normalBadges.length,
                    itemBuilder: (context, index) {
                      final badge = normalBadges[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 70,
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: SpotLightColors.getGradient(badge.id),
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: badge.badgeColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                badge.icon,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 70,
                              child: Text(
                                badge.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[300],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPostsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '投稿一覧',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _isLoadingPosts
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(
                      color: SpotLightColors.primaryOrange,
                    ),
                  ),
                )
              : _userPosts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'まだ投稿がありません',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _userPosts.length,
                      itemBuilder: (context, index) {
                        final post = _userPosts[index];
                        return _buildPostThumbnail(post);
                      },
                    ),
        ],
      ),
    );
  }

  Widget _buildPostThumbnail(Post post) {
    String? thumbnailUrl = post.thumbnailUrl ?? post.mediaUrl;
    
    return GestureDetector(
      onTap: () {
        // ホーム画面に遷移して、その投稿を表示
        final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
        navigationProvider.navigateToHome(
          postId: post.id.toString(),
          postTitle: post.title,
        );
        // ホーム画面に遷移
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[900],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: thumbnailUrl != null
              ? RobustNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: SpotLightColors.primaryOrange,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: Container(
                    color: Colors.grey[900],
                    child: Icon(
                      post.type == 'video'
                          ? Icons.play_circle_outline
                          : post.type == 'audio'
                              ? Icons.audiotrack
                              : Icons.image,
                      color: Colors.grey[600],
                      size: 40,
                    ),
                  ),
                )
              : Container(
                  color: Colors.grey[900],
                  child: Icon(
                    post.type == 'video'
                        ? Icons.play_circle_outline
                        : post.type == 'audio'
                            ? Icons.audiotrack
                            : Icons.image,
                    color: Colors.grey[600],
                    size: 40,
                  ),
                ),
        ),
      ),
    );
  }
}

