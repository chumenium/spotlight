import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../models/badge.dart';
import '../services/jwt_service.dart';
import '../services/user_service.dart';
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
  String? _bio; // 自己紹介文
  bool _isLoadingProfile = true;
  bool _isLoadingPosts = false;
  String? _errorMessage;
  // 投稿リスト
  List<Post> _userPosts = [];
  String? _myUid; // 自分のfirebase_uid
  bool _isBlocking = false; // ブロック/解除のロード中フラグ
  bool _isBlocked = false; // 対象ユーザーをブロック済みか
  bool _isLoadingBlockStatus = false; // ブロック状態の取得中
  String? _blockedTargetUid; // ブロック一覧から取得した正確なtarget_uid

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

    _loadMyUid();
    _fetchUserProfile();
    // 新しいAPIではプロフィール情報と投稿一覧を同時に取得するため、_fetchUserPostsは不要
  }

  Future<void> _loadMyUid() async {
    final info = await JwtService.getUserInfo();
    if (info != null && mounted) {
      setState(() {
        _myUid = info['firebase_uid']?.toString() ?? info['uid']?.toString();
      });
    }
    // 自分のUIDがわかった段階でブロック状態を取得
    await _fetchBlockStatus();
  }

  /// ユーザーのプロフィール情報と投稿一覧を取得（新しいAPIを使用）
  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _isLoadingPosts = true;
      _errorMessage = null;
    });

    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        setState(() {
          _errorMessage = '認証が必要です';
          _isLoadingProfile = false;
          _isLoadingPosts = false;
        });
        return;
      }

      // usernameを取得（userIdが空の場合はwidget.usernameを使用）
      final username = widget.username ?? '';

      if (username.isEmpty) {
        setState(() {
          _errorMessage = 'ユーザー名が必要です';
          _isLoadingProfile = false;
          _isLoadingPosts = false;
        });
        return;
      }

      // usericonパスを取得
      final usericon = widget.userIconPath ?? widget.userIconUrl ?? '';

      if (kDebugMode) {
        debugPrint('👤 ユーザープロフィール取得開始:');
        debugPrint('  username: $username');
        debugPrint('  usericon: $usericon');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/users/userhome'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'usericon': usericon,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('👤 ユーザープロフィール取得レスポンス:');
          debugPrint('  status: ${responseData['status']}');
          debugPrint('  data: ${responseData.toString()}');
        }

        // レスポンス形式: {"status": "success", "data": {...}}
        if (responseData['status'] != 'success' ||
            responseData['data'] == null) {
          if (mounted) {
            setState(() {
              _errorMessage = 'ユーザー情報の取得に失敗しました';
              _isLoadingProfile = false;
              _isLoadingPosts = false;
            });
          }
          return;
        }

        final userData = responseData['data'] as Map<String, dynamic>;

        if (kDebugMode) {
          debugPrint('👤 取得したユーザーデータ:');
          debugPrint('  username: ${userData['username']}');
          debugPrint('  usericon: ${userData['usericon']}');
          debugPrint('  spotlightnum: ${userData['spotlightnum']}');
          debugPrint('  contents: ${userData['contents']}');
        }

        // ユーザー情報を設定
        final resolvedUsername =
            userData['username'] as String? ?? widget.username ?? '';
        final userIcon = userData['usericon'] as String? ?? widget.userIconPath;
        final spotlightNum = userData['spotlightnum'] as int? ?? 0;
        final bio = userData['bio'] as String?;
        final contents = userData['contents'] as List<dynamic>? ?? [];

        if (kDebugMode) {
          debugPrint('👤 投稿データ数: ${contents.length}');
          if (contents.isNotEmpty) {
            debugPrint('👤 最初の投稿データ: ${contents.first}');
          }
        }

        // 投稿を取得（APIレスポンスをPost.fromJsonが期待する形式に変換）
        final posts = contents.map((json) {
          // APIレスポンスのフィールド名をPost.fromJsonが期待する形式に変換
          // thumbnailurlは既にCloudFront URLとして正規化されている可能性がある
          final thumbnailUrl = json['thumbnailurl'] as String?;

          final postJson = <String, dynamic>{
            'contentID': json['contentID'],
            'id': json['contentID']?.toString() ?? '',
            'title': json['title'] ?? '',
            'spotlightnum': json['spotlightnum'] ?? 0,
            'playnum': json['playnum'] ?? 0,
            'posttimestamp': json['posttimestamp'],
            'link': json['link'],
            // thumbnailurlをthumbnailpathとして設定
            // _normalizeContentUrlは既に完全なURLの場合はそのまま返す
            'thumbnailpath': thumbnailUrl,
            // メディア本体のURL（contentpath）があればそれを優先し、
            // 互換性のために存在しない場合は従来どおりlinkをfallbackとして使う
            'contentpath': json['contentpath'] ?? json['link'],
            // ユーザー名を追加（親のデータから）
            'username': resolvedUsername,
            // その他の必須フィールド
            'spotlightflag': false, // デフォルト値
            'textflag': false, // デフォルト値
            'commentnum': 0, // デフォルト値
          };

          if (kDebugMode) {
            debugPrint('📦 投稿データ変換:');
            debugPrint('  contentID: ${postJson['contentID']}');
            debugPrint('  title: ${postJson['title']}');
            debugPrint('  thumbnailurl: $thumbnailUrl');
            debugPrint('  link: ${json['link']}');
            debugPrint('  spotlightnum: ${postJson['spotlightnum']}');
            debugPrint('  playnum: ${postJson['playnum']}');
          }

          final post =
              Post.fromJson(postJson, backendUrl: AppConfig.backendUrl);

          if (kDebugMode) {
            debugPrint('📦 Post.fromJson完了:');
            debugPrint('  id: ${post.id}');
            debugPrint('  title: ${post.title}');
            debugPrint('  thumbnailUrl: ${post.thumbnailUrl}');
            debugPrint('  mediaUrl: ${post.mediaUrl}');
          }

          return post;
        }).toList();

        if (mounted) {
          setState(() {
            _displayUsername = resolvedUsername;
            _iconPath = userIcon;
            _spotlightCount = spotlightNum;
            _isAdmin = userData['admin'] as bool? ?? false;
            _bio = bio;
            _userPosts = posts;

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
            _isLoadingPosts = false;
          });
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ ユーザープロフィール取得エラー: ${response.statusCode}');
          debugPrint('レスポンス: ${response.body}');
        }
        if (mounted) {
          setState(() {
            _errorMessage = 'ユーザー情報の取得に失敗しました';
            _isLoadingProfile = false;
            _isLoadingPosts = false;
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
          _isLoadingPosts = false;
        });
      }
    }
  }

  // 注: 新しいAPIでは投稿も一緒に取得されるため、_fetchUserPostsメソッドは不要になりました
  // スポットライト数はAPIから直接取得されるため、_calculateSpotlightCountメソッドも不要です

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
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
                        },
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _fetchUserProfile();
                  },
                  color: SpotLightColors.primaryOrange,
                  child: CustomScrollView(
                    slivers: [
                      // プロフィールヘッダー
                      SliverToBoxAdapter(
                        child: _buildProfileHeader(),
                      ),
                      // 自己紹介文
                      if (_bio != null && _bio!.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _buildBioSection(),
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
        iconUrl = '${AppConfig.backendUrl}/icon/default_icon.png';
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
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
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 12),
          if (_myUid != null &&
              widget.userId.isNotEmpty &&
              _myUid != widget.userId)
            _buildBlockButtons(),
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

  /// 自己紹介文セクションを構築
  Widget _buildBioSection() {
    if (_bio == null || _bio!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _bio!,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 14,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
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
    final normalBadges =
        displayBadges.where((b) => b.id != 999 && b.id != 777).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'まだバッジがありません',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                )
              : Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: normalBadges.map((badge) {
                    return SizedBox(
                      width: 70,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                          Text(
                            badge.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[300],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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
                      padding: const EdgeInsets.all(2),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
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
    final thumbnailUrl = post.thumbnailUrl ?? post.mediaUrl;

    return GestureDetector(
      onTap: () {
        // ホーム画面に遷移して、その投稿を表示
        if (kDebugMode) {
          debugPrint('👤 投稿タップ: ${post.id} - ${post.title}');
        }
        final navigationProvider =
            Provider.of<NavigationProvider>(context, listen: false);
        navigationProvider.navigateToHome(
          postId: post.id.toString(),
          postTitle: post.title,
        );
        // ホーム画面に遷移
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // サムネイル画像
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: RobustNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: SpotLightColors.primaryOrange,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: Container(
                    color: Colors.grey[800],
                    child: Center(
                      child: Icon(
                        post.type == 'video'
                            ? Icons.play_circle_outline
                            : post.type == 'audio'
                                ? Icons.audiotrack
                                : Icons.image,
                        color: Colors.grey[600],
                        size: 32,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                color: Colors.grey[800],
                child: Center(
                  child: Icon(
                    post.type == 'video'
                        ? Icons.play_circle_outline
                        : post.type == 'audio'
                            ? Icons.audiotrack
                            : Icons.image,
                    color: Colors.grey[600],
                    size: 32,
                  ),
                ),
              ),

            // グラデーションオーバーレイ（下部）
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // タイトル
                    Text(
                      post.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 統計情報
                    Row(
                      children: [
                        Icon(
                          Icons.flashlight_on,
                          size: 12,
                          color: SpotLightColors.getSpotlightColor(0),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${post.likes}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.play_circle_outline,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${post.playNum}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ブロック/解除処理
  Future<void> _handleBlock(bool isBlock) async {
    setState(() {
      _isBlocking = true;
    });

    // ブロック解除時はブロック一覧から得たuidを優先、なければ元のid
    final targetUid = !isBlock && _blockedTargetUid != null
        ? _blockedTargetUid!
        : widget.userId;
    final success = isBlock
        ? await UserService.blockUser(targetUid)
        : await UserService.unblockUser(targetUid);

    if (mounted) {
      setState(() {
        _isBlocking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? (isBlock ? 'ブロックしました' : 'ブロックを解除しました')
              : (isBlock ? 'ブロックに失敗しました' : 'ブロック解除に失敗しました')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        setState(() {
          _isBlocked = isBlock;
          if (!isBlock) {
            _blockedTargetUid = null;
          }
        });
      }
    }
  }

  /// ブロック状態の取得
  Future<void> _fetchBlockStatus() async {
    if (_myUid == null || widget.userId.isEmpty || _myUid == widget.userId) {
      return;
    }

    setState(() {
      _isLoadingBlockStatus = true;
    });

    final blocked = await UserService.getBlockedUsers();
    if (mounted) {
      setState(() {
        _isLoadingBlockStatus = false;
        if (blocked != null) {
          _isBlocked = blocked.any((item) {
            final id = item['userID']?.toString();
            final name = item['username']?.toString();
            final targetId = widget.userId.toString();
            final targetName = widget.username?.toString();
            final matched =
                id == targetId || (targetName != null && name == targetName);
            if (matched && id != null) {
              _blockedTargetUid = id; // 正確なuidを保持して解除に使う
            }
            return matched;
          });
        }
      });
    }
  }

  /// ブロック/解除ボタンを構築（どちらか一方のみ表示）
  Widget _buildBlockButtons() {
    if (_isLoadingBlockStatus) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: SpotLightColors.primaryOrange,
            ),
          ),
        ),
      );
    }

    if (_isBlocked) {
      return OutlinedButton.icon(
        onPressed: _isBlocking ? null : () => _handleBlock(false),
        icon: const Icon(Icons.refresh),
        label: Text(_isBlocking ? '処理中...' : 'ブロック解除'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _isBlocking ? null : () => _handleBlock(true),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
      ),
      icon: const Icon(Icons.block),
      label: Text(_isBlocking ? '処理中...' : 'ブロック'),
    );
  }
}
