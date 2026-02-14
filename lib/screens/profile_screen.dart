import 'package:flutter/material.dart' hide Badge;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'history_list_screen.dart';
import 'playlist_list_screen.dart';
import 'playlist_detail_screen.dart';
import 'spotlight_list_screen.dart';
import 'help_screen.dart';
import 'feedback_screen.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'admin_screen.dart';
import 'settings_screen.dart';
import 'blocked_users_screen.dart';
import 'profile_edit_screen.dart';
import '../utils/spotlight_colors.dart';
import '../widgets/blur_app_bar.dart';

import '../auth/auth_provider.dart';
import '../config/app_config.dart';
import '../services/jwt_service.dart';
import '../services/user_service.dart';
import '../services/icon_update_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import '../models/badge.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../widgets/robust_network_image.dart';
import '../providers/navigation_provider.dart';
import '../services/playlist_service.dart';
import '../auth/social_login_screen.dart';
import '../services/ad_service.dart';
import '../services/rewarded_badge_service.dart';
import '../config/ad_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _spotlightCount = 0;
  int _previousSpotlightCount = 0; // 前回のspotlight数を保存
  final Set<int> _newlyUnlockedBadgeIds = {}; // 新しく解放されたバッジのID
  int _rewardAdWatchCount = 0;
  int _previousRewardAdWatchCount = 0;
  final Set<int> _newlyUnlockedRewardBadgeIds = {};
  RewardedAd? _rewardedBadgeAd;
  bool _isRewardedBadgeAdReady = false;
  bool _isRewardedBadgeAdLoading = false;
  bool _isRewardedBadgeSubmitting = false;
  final ImagePicker _imagePicker = ImagePicker();
  // 自分の投稿リスト
  List<Post> _myPosts = [];
  bool _isLoadingPosts = false;
  // 視聴履歴リスト
  List<Post> _historyPosts = [];
  bool _isLoadingHistory = false;
  // 再生リスト
  List<Playlist> _playlists = [];
  bool _isLoadingPlaylists = false;
  // 前回のナビゲーションインデックス（リロード制御用）
  int? _lastNavigationIndex;
  // 自己紹介文
  String? _bio;
  // 画像のアスペクト比をキャッシュ（URL -> アスペクト比）
  // 再生リストの最初のコンテンツのサムネイルURLをキャッシュ（playlistId -> thumbnailUrl）
  final Map<int, String?> _playlistFirstContentThumbnails = {};
  // バッジポップアップのオーバーレイ
  OverlayEntry? _badgeOverlayEntry;
  int _lastHistoryTrigger = 0;

  /// アイコンキャッシュをクリア（アイコン更新時に呼び出し）
  ///
  /// [oldIconUrl] 古いアイコンのURL（指定された場合のみクリア）
  Future<void> _clearIconCache({String? oldIconUrl}) async {
    try {
      // 古いアイコンURLのキャッシュをクリア
      if (oldIconUrl != null && oldIconUrl.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(oldIconUrl);
      }

      // デフォルトアイコンのキャッシュもクリア
      await CachedNetworkImage.evictFromCache(
          '${AppConfig.backendUrl}/icon/default_icon.png');

    } catch (e) {
    }
  }

  // 安全なメッセージ表示のためのヘルパーメソッド
  void _showSafeSnackBar(String message, {Color? backgroundColor}) {
    if (mounted) {
      try {
        if (backgroundColor == Colors.green) {
          return; // 成功系ポップアップは表示しない
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor ?? Colors.red,
          ),
        );
      } catch (e) {}
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
          builder: (context) => const PopScope(
            canPop: false, // バックボタンを無効化
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      } catch (e) {
        _isLoadingDialogShown = false;
      }
    }
  }

  // 安全なローディングダイアログを閉じる
  void _closeSafeLoadingDialog() {
    if (mounted && _isLoadingDialogShown) {
      try {
        _isLoadingDialogShown = false;
        Navigator.of(context).pop();
      } catch (e) {}
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchSpotlightCount();
    _fetchMyPosts();
    _fetchHistory();
    _fetchPlaylists();
    _fetchBio();
    _fetchRewardAdWatchCount();
    _loadRewardedBadgeAd();

    // 初期化時に前回のカウントを設定（初回は0）
    _previousSpotlightCount = 0;
    _previousRewardAdWatchCount = 0;
  }

  @override
  void dispose() {
    _hideBadgeOverlay();
    _rewardedBadgeAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    if (_lastHistoryTrigger !=
        navigationProvider.profileHistoryRefreshTrigger) {
      _lastHistoryTrigger = navigationProvider.profileHistoryRefreshTrigger;
      _fetchHistory();
    }
  }

  /// プロフィールデータをリフレッシュ（プルリフレッシュ用）
  Future<void> _refreshProfileData() async {
    // すべてのデータを並列で取得
    await Future.wait([
      _fetchSpotlightCount(),
      _fetchMyPosts(),
      _fetchHistory(),
      _fetchPlaylists(),
      _fetchBio(),
      _fetchRewardAdWatchCount(),
    ]);
  }

  /// 自己紹介文を取得
  Future<void> _fetchBio() async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) return;

      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;
      if (userId == null) return;

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/users/getusername'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'firebase_uid': userId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final userData = responseData['data'] as Map<String, dynamic>;
          final bio = userData['bio'] as String?;

          if (mounted) {
            setState(() {
              _bio = bio;
            });
          }
        }
      }
    } catch (e) {}
  }

  /// 視聴履歴を取得（最前の5件まで）
  Future<void> _fetchHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final posts = await PostService.getPlayHistory();

      if (mounted) {
        setState(() {
          // 最前の5件までを表示
          _historyPosts = posts.take(5).toList();
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  /// 自分の投稿を取得（最前の5件まで）
  Future<void> _fetchMyPosts() async {
    setState(() {
      _isLoadingPosts = true;
    });

    try {
      final posts = await PostService.getUserContents();

      if (mounted) {
        setState(() {
          // 最前の5件までを表示
          _myPosts = posts.take(5).toList();
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  /// 再生リストを取得（最前の5件まで）
  Future<void> _fetchPlaylists() async {
    setState(() {
      _isLoadingPlaylists = true;
    });

    try {
      final playlists = await PlaylistService.getPlaylists();

      if (mounted) {
        final sortedPlaylists = List<Playlist>.from(playlists);
        final spotlightIndex = sortedPlaylists.indexWhere(
          (playlist) => playlist.title == PlaylistService.spotlightPlaylistTitle,
        );
        if (spotlightIndex > 0) {
          final spotlightPlaylist = sortedPlaylists.removeAt(spotlightIndex);
          sortedPlaylists.insert(0, spotlightPlaylist);
        }

        setState(() {
          // 最前の5件までを表示（スポットライトを先頭に固定）
          _playlists = sortedPlaylists.take(5).toList();
          _isLoadingPlaylists = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPlaylists = false;
        });
      }
    }
  }

  Future<void> _fetchSpotlightCount() async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/users/getspotlightnum'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );

      if (mounted && response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // レスポンス形式: {"status": "success", "num": num}
        if (data['status'] != 'success' || data['num'] == null) {
          return;
        }

        final newSpotlightCount = data['num'] as int;

        // 前回のspotlight数と比較して、新しいバッジが解放されたかチェック
        final previousUnlockedBadges =
            BadgeManager.getUnlockedBadges(_previousSpotlightCount);
        final newUnlockedBadges =
            BadgeManager.getUnlockedBadges(newSpotlightCount);

        // 新しく解放されたバッジを取得
        final newlyUnlockedBadges = newUnlockedBadges
            .where(
                (badge) => !previousUnlockedBadges.any((b) => b.id == badge.id))
            .toList();

        setState(() {
          _spotlightCount = newSpotlightCount;
        });

        // 新しいバッジが解放された場合はハイライトのみ更新
        if (newlyUnlockedBadges.isNotEmpty && mounted) {
          // 新しく解放されたバッジのIDを保存（アニメーション用）
          setState(() {
            _newlyUnlockedBadgeIds.clear();
            _newlyUnlockedBadgeIds.addAll(newlyUnlockedBadges.map((b) => b.id));
          });

          // 3秒後にハイライトを解除
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _newlyUnlockedBadgeIds.clear();
              });
            }
          });
        }

        // 前回のspotlight数を更新
        _previousSpotlightCount = newSpotlightCount;
      } else {}
    } catch (e) {
      // エラー時の処理（特に状態更新は不要）
    }
  }

  Future<void> _fetchRewardAdWatchCount() async {
    final count = await RewardedBadgeService.fetchRewardAdCount();
    if (!mounted || count == null) return;

    final previousUnlocked =
        RewardAdBadgeManager.getUnlockedBadges(_previousRewardAdWatchCount);
    final currentUnlocked = RewardAdBadgeManager.getUnlockedBadges(count);
    final newlyUnlocked = currentUnlocked
        .where((badge) => !previousUnlocked.any((b) => b.id == badge.id))
        .toList();

    setState(() {
      _rewardAdWatchCount = count;
      _newlyUnlockedRewardBadgeIds
        ..clear()
        ..addAll(newlyUnlocked.map((b) => b.id));
    });

    if (newlyUnlocked.isNotEmpty) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _newlyUnlockedRewardBadgeIds.clear();
        });
      });
    }
    _previousRewardAdWatchCount = count;
  }

  void _loadRewardedBadgeAd() {
    if (!Platform.isIOS) {
      _isRewardedBadgeAdReady = false;
      _isRewardedBadgeAdLoading = false;
      _rewardedBadgeAd?.dispose();
      _rewardedBadgeAd = null;
      if (mounted) setState(() {});
      return;
    }
    if (_isRewardedBadgeAdLoading) return;
    _isRewardedBadgeAdLoading = true;

    _rewardedBadgeAd?.dispose();
    _rewardedBadgeAd = null;
    _isRewardedBadgeAdReady = false;

    AdService.instance.loadRewardedAd(
      adUnitId: AdConfig.getRewardBadgeAdUnitId(),
      listener: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _isRewardedBadgeAdLoading = false;
          _rewardedBadgeAd = ad;
          _isRewardedBadgeAdReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedBadgeAd = null;
              _isRewardedBadgeAdReady = false;
              _loadRewardedBadgeAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedBadgeAd = null;
              _isRewardedBadgeAdReady = false;
              _loadRewardedBadgeAd();
            },
          );
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (_) {
          _isRewardedBadgeAdLoading = false;
          _isRewardedBadgeAdReady = false;
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _watchRewardedAdForBadge() async {
    if (!Platform.isIOS) {
      _showSafeSnackBar('広告バッジはiOSのみ対応です', backgroundColor: Colors.orange);
      return;
    }
    if (_isRewardedBadgeSubmitting) return;
    if (!_isRewardedBadgeAdReady || _rewardedBadgeAd == null) {
      _showSafeSnackBar('広告を読み込み中です。少し待ってからお試しください', backgroundColor: Colors.orange);
      _loadRewardedBadgeAd();
      return;
    }

    _isRewardedBadgeSubmitting = true;
    final beforeCount = _rewardAdWatchCount;
    _rewardedBadgeAd!.show(
      onUserEarnedReward: (ad, reward) async {
        final result = await RewardedBadgeService.incrementRewardAdCount();
        if (!mounted) return;

        if (result.count != null) {
          setState(() {
            _rewardAdWatchCount = result.count!;
          });
        }

        final latestCount = await RewardedBadgeService.fetchRewardAdCount();
        if (!mounted) return;

        if (latestCount != null) {
          setState(() {
            _rewardAdWatchCount = latestCount;
          });
        }

        final actuallyIncremented =
            latestCount != null ? latestCount > beforeCount : false;

        if (result.success || actuallyIncremented) {
          await _fetchRewardAdWatchCount();
        } else if (result.rateLimited) {
          _showSafeSnackBar(
            result.message ?? 'リクエストが頻繁すぎます',
            backgroundColor: Colors.orange,
          );
        } else {
          _showSafeSnackBar(
            result.message ?? '報酬の反映に失敗しました',
            backgroundColor: Colors.red,
          );
        }
      },
    );
    _isRewardedBadgeSubmitting = false;
  }

  @override
  Widget build(BuildContext context) {
    // NavigationProviderを監視して、プロフィール画面が表示されたときにデータを再取得
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, child) {
        final currentIndex = navigationProvider.currentIndex;
        const profileIndex = 4; // プロフィール画面のインデックス

        // プロフィール画面が表示されたとき（インデックスが4になったとき）にデータを再取得
        if (currentIndex == profileIndex &&
            _lastNavigationIndex != profileIndex) {
          _lastNavigationIndex = profileIndex;
          // 次のフレームでデータを再取得（build中にsetStateを呼ばないように）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && navigationProvider.currentIndex == profileIndex) {
              _fetchSpotlightCount();
              _fetchMyPosts();
              _fetchHistory();
              _fetchPlaylists();
              _fetchBio();
              _fetchRewardAdWatchCount();
              _loadRewardedBadgeAd();
            }
          });
        } else if (currentIndex != profileIndex) {
          // プロフィール画面以外が表示された場合は、前回のインデックスをリセット
          _lastNavigationIndex = currentIndex;
        }

        return _buildScaffold(context);
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: BlurAppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        toolbarHeight: 60,
        leadingWidth: 160,
        leading: SizedBox(
          height: 45,
          width: 160,
          child: RepaintBoundary(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
              cacheWidth:
                  (160 * MediaQuery.of(context).devicePixelRatio).round(),
              cacheHeight:
                  (45 * MediaQuery.of(context).devicePixelRatio).round(),
              errorBuilder: (context, error, stackTrace) {
                // ロゴ画像が見つからない場合は何も表示しない
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshProfileData,
          color: const Color(0xFFFF6B35),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // プロフィールヘッダー
                _buildProfileHeader(),

                // 自己紹介文セクション
                _buildBioSection(),

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

                // 広告バッジセクション
                _buildRewardBadgeSection(),

                const SizedBox(height: 20),

                // 統計・ヘルプセクション
                _buildStatsAndHelpSection(context),

                const SizedBox(height: 24), // ログアウト前の隙間

                // ログアウトボタン
                _buildLogoutButton(context),

                const SizedBox(height: 100), // ボトムナビゲーション分の余白
              ],
            ),
          ),
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

          // iconPathを明示的に監視して、変更時に確実に再構築されるようにする
          final iconPath = user?.iconPath ?? '';

          // アイコンURLを生成（iconPathを優先、常に最新のキャッシュキーを使用）
          String? iconUrl;
          String? baseIconUrl;

          // iconPathを優先的に使用（バックエンドから取得した最新の値）
          if (iconPath.isNotEmpty) {
            // default_icon.pngの場合はS3のCloudFront URLを使用
            if (iconPath == 'default_icon.png' ||
                iconPath == '/icon/default_icon.png' ||
                iconPath.endsWith('/default_icon.png')) {
              baseIconUrl =
                  '${AppConfig.cloudFrontUrl}/spotlight-contents/icon/default_icon.png';
            }
            // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
            else if (iconPath.startsWith('http://') ||
                iconPath.startsWith('https://')) {
              baseIconUrl = iconPath;
            }
            // 相対パス（/icon/で始まる）の場合はbackendUrlを追加
            else if (iconPath.startsWith('/icon/')) {
              baseIconUrl = '${AppConfig.backendUrl}$iconPath';
            }
            // 相対パス（/で始まるが/icon/でない）の場合もbackendUrlを追加
            else if (iconPath.startsWith('/')) {
              baseIconUrl = '${AppConfig.backendUrl}$iconPath';
            }
            // ファイル名のみの場合は/icon/を追加
            else {
              baseIconUrl = '${AppConfig.backendUrl}/icon/$iconPath';
            }
          } else {
            // iconPathがない場合はS3のデフォルトアイコンを使用
            baseIconUrl =
                '${AppConfig.cloudFrontUrl}/spotlight-contents/icon/default_icon.png';

          }

          // アイコン変更時に即座に反映されるように、iconPathとタイムスタンプをキーに含める
          // 常に新しいキーを生成することで、Flutterの画像キャッシュを無効化
          final now = DateTime.now();
          final iconKey =
              '${user?.id ?? 'unknown'}_${iconPath}_${now.millisecondsSinceEpoch}';

          // 1時間ごとのキャッシュキーを追加（YYYYMMDDHH形式）
          final cacheKey =
              '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}';

          // URLにキャッシュキーを追加
          final separator = baseIconUrl.contains('?') ? '&' : '?';
          iconUrl = '$baseIconUrl$separator cache=$cacheKey';

          return Row(
            children: [
              GestureDetector(
                onTap: () => _showIconMenu(context, authProvider),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFFF6B35),
                  child: ClipOval(
                    key: ValueKey(
                        iconKey), // アイコン変更時に強制的に再構築（iconPath + タイムスタンプ）
                    child: CachedNetworkImage(
                      imageUrl: iconUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      memCacheHeight: 160,
                      httpHeaders: const {
                        'Accept': 'image/webp,image/avif,image/*,*/*;q=0.8',
                        'User-Agent': 'Flutter-Spotlight/1.0',
                      },
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (context, url) => Container(
                        color: const Color(0xFFFF6B35),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        // エラー時はS3のdefault_icon.pngを表示
                        return CachedNetworkImage(
                          imageUrl:
                              '${AppConfig.cloudFrontUrl}/spotlight-contents/icon/default_icon.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          httpHeaders: const {
                            'Accept': 'image/webp,image/avif,image/*,*/*;q=0.8',
                            'User-Agent': 'Flutter-Spotlight/1.0',
                          },
                          placeholder: (context, url) => Container(
                            color: const Color(0xFFFF6B35),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFFFF6B35),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
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
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 最大のバッジを表示
                        _buildMaxBadgeIcon(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileEditScreen(),
                          ),
                        );
                        if (result == true && mounted) {
                          await _refreshProfileData();
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit,
                            size: 16,
                            color:
                                Theme.of(context).textTheme.bodySmall?.color ??
                                    Colors.grey[400],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'プロフィール編集',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color ??
                                  Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
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

  /// 自己紹介文セクションを構築
  Widget _buildBioSection() {
    if (_bio == null || _bio!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
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

  Widget _buildMaxBadgeIcon() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final isAdmin = authProvider.currentUser?.admin == true;
        final unlockedBadges = BadgeManager.getUnlockedBadges(_spotlightCount);

        // 管理者バッジ（ID: 999）と開発者バッジ（ID: 777）を除外したリストを作成
        final normalBadges =
            unlockedBadges.where((b) => b.id != 999 && b.id != 777).toList();

        // 管理者ユーザーの場合、管理者バッジと通常の最大バッジの2つを表示
        if (isAdmin) {
          final adminBadge = BadgeManager.getBadgeById(999);
          final maxNormalBadge =
              normalBadges.isNotEmpty ? normalBadges.last : null;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 管理者バッジ
              if (adminBadge != null) _buildBadgeIcon(adminBadge),
              // 通常の最大バッジ（存在する場合）
              if (maxNormalBadge != null) ...[
                const SizedBox(width: 4),
                _buildBadgeIcon(maxNormalBadge),
              ],
            ],
          );
        }

        // 通常ユーザーの場合は最大バッジのみ表示
        // 管理者バッジと開発者バッジは既に除外済み
        if (normalBadges.isEmpty) {
          return const SizedBox.shrink();
        }

        final maxBadge = normalBadges.last;
        return _buildBadgeIcon(maxBadge);
      },
    );
  }

  /// バッジアイコンを生成するヘルパーメソッド
  Widget _buildBadgeIcon(Badge badge) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: SpotLightColors.getGradient(badge.id),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: badge.badgeColor.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        badge.icon,
        color: Colors.white,
        size: 24, //名前横バッジサイズ
      ),
    );
  }

  Widget _buildSpotlightSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '自分の投稿',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color ??
                          const Color(0xFF1A1A1A),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SpotlightListScreen(),
                        ),
                      );
                      if (mounted) {
                        await _refreshProfileData();
                      }
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
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[300],
                indent: 0,
                endIndent: 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _isLoadingPosts
            ? const SizedBox(
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF6B35),
                  ),
                ),
              )
            : _myPosts.isEmpty
                ? SizedBox(
                    height: 150,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_outlined,
                            color: Colors.grey[600],
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '投稿がありません',
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _myPosts.length,
                      itemBuilder: (context, index) {
                        final post = _myPosts[index];
                        return _buildPostThumbnail(context, post, index);
                      },
                    ),
                  ),
      ],
    );
  }

  /// サムネイルURLが有効かチェック（null/undefined/空文字列を安全にチェック）
  bool _hasValidThumbnail(String? thumbnailUrl) {
    if (thumbnailUrl == null) return false;
    try {
      return thumbnailUrl.isNotEmpty;
    } catch (e) {
      // undefinedやその他のエラーの場合もfalseを返す
      return false;
    }
  }

  /// タイトルを安全に取得（null/undefined/空文字列を安全にチェック）
  String _getSafeTitle(String? title) {
    if (title == null) return 'タイトルなし';
    try {
      if (title.isNotEmpty) {
        return title;
      }
      return 'タイトルなし';
    } catch (e) {
      // undefinedやその他のエラーの場合もデフォルト値を返す
      return 'タイトルなし';
    }
  }

  /// タイトルを20文字で切り詰めて「...」を追加
  String _getTruncatedTitle(String title) {
    if (title.length <= 20) {
      return title;
    }
    return '${title.substring(0, 20)}...';
  }

  /// 再生リストの最初のコンテンツのサムネイルURLを取得
  Future<String?> _getFirstContentThumbnail(int playlistId) async {
    // キャッシュを確認
    if (_playlistFirstContentThumbnails.containsKey(playlistId)) {
      return _playlistFirstContentThumbnails[playlistId];
    }

    try {
      // 再生リストのコンテンツを取得
      final contentsJson = await PlaylistService.getPlaylistDetail(playlistId);

      if (contentsJson.isEmpty) {
        // コンテンツがない場合はnullをキャッシュ
        _playlistFirstContentThumbnails[playlistId] = null;
        return null;
      }

      // 最初のコンテンツのサムネイルURLを取得
      final firstContent = contentsJson[0];
      final thumbnailpath = firstContent['thumbnailpath']?.toString();

      if (thumbnailpath == null || thumbnailpath.isEmpty) {
        // サムネイルがない場合はnullをキャッシュ
        _playlistFirstContentThumbnails[playlistId] = null;
        return null;
      }

      // サムネイルURLを構築
      String thumbnailUrl;
      if (thumbnailpath.startsWith('http://') ||
          thumbnailpath.startsWith('https://')) {
        // 既に完全なURLの場合はそのまま使用
        thumbnailUrl = thumbnailpath;
      } else {
        // 相対パスの場合は、backendUrlと結合
        final normalizedPath =
            thumbnailpath.startsWith('/') ? thumbnailpath : '/$thumbnailpath';
        thumbnailUrl = '${AppConfig.backendUrl}$normalizedPath';
      }

      // キャッシュに保存
      _playlistFirstContentThumbnails[playlistId] = thumbnailUrl;
      return thumbnailUrl;
    } catch (e) {
      // エラーの場合はnullをキャッシュ
      _playlistFirstContentThumbnails[playlistId] = null;
      return null;
    }
  }

  /// 固定サイズのサムネイルを構築（すべて同じサイズで表示）
  Widget _buildThumbnailWithAspectRatio(
      String thumbnailUrl, double itemWidth, Post post, int index) {
    // 固定サイズ（高さ120px）
    const thumbnailHeight = 120.0;

    // URLの検証
    if (thumbnailUrl.isEmpty) {
      return Container(
        width: itemWidth,
        height: thumbnailHeight,
        color: Colors.grey[800],
        child: Center(
          child: Icon(
            post.postType == PostType.video
                ? Icons.play_circle_outline
                : post.postType == PostType.image
                    ? Icons.image_outlined
                    : post.postType == PostType.audio
                        ? Icons.audiotrack_outlined
                        : Icons.text_fields_outlined,
            color: Colors.white,
            size: 32,
          ),
        ),
      );
    }

    // すべて同じサイズで表示（BoxFit.coverで中央を表示）
    return SizedBox(
      width: itemWidth,
      height: thumbnailHeight,
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: thumbnailUrl,
            width: itemWidth,
            height: thumbnailHeight,
            fit: BoxFit.cover,
            memCacheWidth: 320,
            memCacheHeight: 180,
            httpHeaders: const {
              'Accept': 'image/webp,image/avif,image/*,*/*;q=0.8',
              'User-Agent': 'Flutter-Spotlight/1.0',
            },
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (context, url) => Container(
              width: itemWidth,
              height: thumbnailHeight,
              color: Colors.grey[800],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF6B35),
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: itemWidth,
              height: thumbnailHeight,
              color: Colors.grey[800],
              child: Center(
                child: Icon(
                  post.postType == PostType.video
                      ? Icons.play_circle_outline
                      : post.postType == PostType.image
                          ? Icons.image_outlined
                          : post.postType == PostType.audio
                              ? Icons.audiotrack_outlined
                              : Icons.text_fields_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          // スポットライトアイコン
          if (post.isSpotlighted)
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
                      color: SpotLightColors.getSpotlightColor(index)
                          .withValues(alpha: 0.3),
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
    );
  }

  /// 投稿のサムネイルを表示
  Widget _buildPostThumbnail(BuildContext context, Post post, int index) {
    // 画面幅に応じて5つ分が表示されるようにアイテム幅を計算
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 20.0 * 2; // 左右のパディング
    const itemMargin = 15.0; // アイテム間のマージン
    const totalMargin = itemMargin * 4; // 5つのアイテム間のマージン（4箇所）
    final availableWidth = screenWidth - horizontalPadding - totalMargin;
    final itemWidth =
        (availableWidth / 5).clamp(140.0, 220.0); // 最小140px、最大220px

    return GestureDetector(
      onTap: () {
        // 投稿をタップしたらホーム画面に遷移してその投稿を表示
        if (!mounted) return;
        try {
          final postIdStr = post.id.toString();
          if (postIdStr.isNotEmpty) {
            final rootContext = context;
            final navigationProvider =
                Provider.of<NavigationProvider>(rootContext, listen: false);
            navigationProvider.navigateToHome(
              postId: postIdStr,
              postTitle: _getSafeTitle(post.title),
              post: post,
            );
          }
        } catch (e) {
          // ignore
        }
      },
      child: Container(
        width: itemWidth,
        height: 148, // サムネイル120px + マージン8px + タイトル20px = 148px
        margin: EdgeInsets.only(
            right: index < _myPosts.length - 1 ? itemMargin : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _hasValidThumbnail(post.thumbnailUrl)
                  ? _buildThumbnailWithAspectRatio(
                      post.thumbnailUrl ?? '',
                      itemWidth,
                      post,
                      index,
                    )
                  : Container(
                      width: itemWidth,
                      height: 120,
                      color: Colors.grey[800],
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              post.postType == PostType.video
                                  ? Icons.play_circle_outline
                                  : post.postType == PostType.image
                                      ? Icons.image_outlined
                                      : post.postType == PostType.audio
                                          ? Icons.audiotrack_outlined
                                          : Icons.text_fields_outlined,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          // スポットライトアイコン
                          if (post.isSpotlighted)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color:
                                      SpotLightColors.getSpotlightColor(index),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: SpotLightColors.getSpotlightColor(
                                              index)
                                          .withValues(alpha: 0.3),
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
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 20, // タイトル部分の高さを固定
              child: Text(
                _getTruncatedTitle(_getSafeTitle(post.title)),
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color ??
                      const Color(0xFF2C2C2C),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditPostDialog(Post post, int index) async {
    final titleController = TextEditingController(text: post.title);
    final tagController = TextEditingController();
    bool clearTag = false;

    await _showSafeDialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('投稿を編集'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'タイトル',
                      hintText: 'タイトルを入力',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagController,
                    decoration: const InputDecoration(
                      labelText: 'タグ',
                      hintText: '変更する場合のみ入力（例: タグ1 タグ2）',
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: clearTag,
                    onChanged: (value) {
                      setState(() {
                        clearTag = value ?? false;
                      });
                    },
                    title: const Text('タグを空にする'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () async {
                  final titleText = titleController.text.trim();
                  final tagText = tagController.text.trim();
                  final hasTitle = titleText.isNotEmpty;
                  final hasTag = clearTag || tagText.isNotEmpty;

                  if (!hasTitle && !hasTag) {
                    Navigator.pop(context);
                    _showSafeSnackBar('タイトルまたはタグを入力してください');
                    return;
                  }

                  if (hasTitle &&
                      titleText == post.title &&
                      !hasTag) {
                    Navigator.pop(context);
                    _showSafeSnackBar('変更内容がありません');
                    return;
                  }

                  Navigator.pop(context);
                  _showSafeLoadingDialog();

                  final success = await PostService.editContent(
                    contentId: post.id,
                    title: hasTitle ? titleText : null,
                    tag: clearTag ? '' : (tagText.isNotEmpty ? tagText : null),
                  );

                  _closeSafeLoadingDialog();

                  if (success && mounted) {
                    setState(() {
                      _myPosts[index] = Post(
                        id: post.id,
                        playId: post.playId,
                        userId: post.userId,
                        username: post.username,
                        userIconPath: post.userIconPath,
                        userIconUrl: post.userIconUrl,
                        title: hasTitle ? titleText : post.title,
                        content: post.content,
                        contentPath: post.contentPath,
                        type: post.type,
                        mediaUrl: post.mediaUrl,
                        thumbnailUrl: post.thumbnailUrl,
                        likes: post.likes,
                        playNum: post.playNum,
                        link: post.link,
                        comments: post.comments,
                        shares: post.shares,
                        isSpotlighted: post.isSpotlighted,
                        isText: post.isText,
                        nextContentId: post.nextContentId,
                        createdAt: post.createdAt,
                      );
                    });
                    _showSafeSnackBar('投稿を更新しました',
                        backgroundColor: Colors.green);
                  } else {
                    _showSafeSnackBar('投稿の更新に失敗しました');
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '視聴履歴',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color ??
                          const Color(0xFF1A1A1A),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HistoryListScreen(),
                        ),
                      );
                      if (mounted) {
                        await _refreshProfileData();
                      }
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
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[300],
                indent: 0,
                endIndent: 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _isLoadingHistory
            ? const SizedBox(
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF6B35),
                  ),
                ),
              )
            : _historyPosts.isEmpty
                ? SizedBox(
                    height: 150,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            color: Colors.grey[600],
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '視聴履歴がありません',
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _historyPosts.length,
                      itemBuilder: (context, index) {
                        final post = _historyPosts[index];
                        return _buildHistoryThumbnail(context, post, index);
                      },
                    ),
                  ),
      ],
    );
  }

  /// 視聴履歴のサムネイルを表示
  Widget _buildHistoryThumbnail(BuildContext context, Post post, int index) {
    // 画面幅に応じて5つ分が表示されるようにアイテム幅を計算
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 20.0 * 2; // 左右のパディング
    const itemMargin = 15.0; // アイテム間のマージン
    const totalMargin = itemMargin * 4; // 5つのアイテム間のマージン（4箇所）
    final availableWidth = screenWidth - horizontalPadding - totalMargin;
    final itemWidth =
        (availableWidth / 5).clamp(140.0, 220.0); // 最小140px、最大220px

    return GestureDetector(
      onTap: () {
        // 投稿をタップしたらホーム画面に遷移してその投稿を表示
        if (!mounted) return;
        try {
          final postIdStr = post.id.toString();
          if (postIdStr.isNotEmpty) {
            final rootContext = context;
            final navigationProvider =
                Provider.of<NavigationProvider>(rootContext, listen: false);
            navigationProvider.navigateToHome(
              postId: postIdStr,
              postTitle: _getSafeTitle(post.title),
              post: post,
            );
          }
        } catch (e) {
          // ignore
        }
      },
      child: Container(
        width: itemWidth,
        height: 148, // サムネイル120px + マージン8px + タイトル20px = 148px
        margin: EdgeInsets.only(
            right: index < _historyPosts.length - 1 ? itemMargin : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _hasValidThumbnail(post.thumbnailUrl)
                  ? _buildThumbnailWithAspectRatio(
                      post.thumbnailUrl ?? '',
                      itemWidth,
                      post,
                      index,
                    )
                  : Container(
                      width: itemWidth,
                      height: 120,
                      color: Colors.grey[800],
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              post.postType == PostType.video
                                  ? Icons.play_circle_outline
                                  : post.postType == PostType.image
                                      ? Icons.image_outlined
                                      : post.postType == PostType.audio
                                          ? Icons.audiotrack_outlined
                                          : Icons.text_fields_outlined,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          // スポットライトアイコン
                          if (post.isSpotlighted)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color:
                                      SpotLightColors.getSpotlightColor(index),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: SpotLightColors.getSpotlightColor(
                                              index)
                                          .withValues(alpha: 0.3),
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
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 20, // タイトル部分の高さを固定
              child: Text(
                _getTruncatedTitle(_getSafeTitle(post.title)),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 再生リストのサムネイルを表示
  Widget _buildPlaylistThumbnail(
      BuildContext context, Playlist playlist, int index) {
    // 画面幅に応じて5つ分が表示されるようにアイテム幅を計算
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 20.0 * 2; // 左右のパディング
    const itemMargin = 15.0; // アイテム間のマージン
    const totalMargin = itemMargin * 4; // 5つのアイテム間のマージン（4箇所）
    final availableWidth = screenWidth - horizontalPadding - totalMargin;
    final itemWidth =
        (availableWidth / 5).clamp(140.0, 220.0); // 最小140px、最大220px

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailScreen(
              playlistId: playlist.playlistid,
              playlistTitle: playlist.title,
            ),
          ),
        );
        // 戻ってきた時は必ず画面を更新
        if (mounted) {
          await _refreshProfileData();
        }
      },
      child: Container(
        width: itemWidth,
        margin: EdgeInsets.only(
            right: index < _playlists.length - 1 ? itemMargin : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 120,
                color: Colors.grey[800],
                child: FutureBuilder<String?>(
                  future: _getFirstContentThumbnail(playlist.playlistid),
                  builder: (context, snapshot) {
                    // 最初のコンテンツのサムネイルURLを取得
                    final thumbnailUrl = snapshot.data;

                    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
                      return Stack(
                        children: [
                          // サムネイル画像（中央に配置）
                          Positioned.fill(
                            child: RobustNetworkImage(
                              imageUrl: thumbnailUrl,
                              fit: BoxFit.cover,
                              maxWidth: 320,
                              maxHeight: 180,
                              placeholder: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF6B35),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          // 中央に再生リストアイコンを重ねて表示
                          const Center(
                            child: Icon(
                              Icons.playlist_play,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // サムネイルがない場合はデフォルトアイコンを表示
                      return const Center(
                        child: Icon(
                          Icons.playlist_play,
                          color: Colors.white,
                          size: 32,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              playlist.title,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color ??
                    const Color(0xFF2C2C2C),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '再生リスト',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color ??
                          const Color(0xFF1A1A1A),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PlaylistListScreen(),
                        ),
                      );
                      if (mounted) {
                        await _refreshProfileData();
                      }
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
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[300],
                indent: 0,
                endIndent: 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _isLoadingPlaylists
            ? const SizedBox(
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF6B35),
                  ),
                ),
              )
            : _playlists.isEmpty
                ? SizedBox(
                    height: 150,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.playlist_play,
                            color: Colors.grey[600],
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '再生リストがありません',
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = _playlists[index];
                        return _buildPlaylistThumbnail(
                            context, playlist, index);
                      },
                    ),
                  ),
      ],
    );
  }

  Widget _buildBadgeSection() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final unlockedBadges = BadgeManager.getUnlockedBadges(_spotlightCount);
        final allBadges = BadgeManager.allBadges;

        // 管理者ユーザーの場合、管理者バッジを追加
        final displayBadges = List<Badge>.from(allBadges);
        final isAdmin = authProvider.currentUser?.admin == true;

        // 管理者バッジがまだリストにない場合のみ追加
        final adminBadge = BadgeManager.getBadgeById(999);
        if (isAdmin &&
            adminBadge != null &&
            !displayBadges.any((b) => b.id == 999)) {
          displayBadges.add(adminBadge);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'バッジ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).textTheme.titleLarge?.color ??
                                  const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        '${unlockedBadges.length + (isAdmin ? 1 : 0)}/${displayBadges.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '総スポットライト数: $_spotlightCount',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[300],
                    indent: 0,
                    endIndent: 0,
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
                itemCount: displayBadges.length,
                itemBuilder: (context, index) {
                  final badge = displayBadges[index];
                  // 管理者バッジの場合は常に解放されているとみなす
                  final isAdminBadge = badge.id == 999;
                  final isUnlocked = isAdminBadge
                      ? isAdmin
                      : unlockedBadges.any((b) => b.id == badge.id);
                  final isNewlyUnlocked =
                      _newlyUnlockedBadgeIds.contains(badge.id);

                  return GestureDetector(
                    // 獲得済みのバッジのみタップ可能
                    onTapDown: isUnlocked
                        ? (_) => _showBadgeOverlay(context, badge)
                        : null,
                    onTapUp: isUnlocked ? (_) => _hideBadgeOverlay() : null,
                    onTapCancel: isUnlocked ? () => _hideBadgeOverlay() : null,
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: isUnlocked
                                  ? LinearGradient(
                                      colors:
                                          SpotLightColors.getGradient(index),
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isUnlocked ? null : Colors.grey[800],
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: isUnlocked
                                  ? [
                                      BoxShadow(
                                        color: badge.badgeColor.withValues(
                                            alpha: isNewlyUnlocked ? 0.6 : 0.3),
                                        blurRadius: isNewlyUnlocked ? 12 : 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                              border: isNewlyUnlocked
                                  ? Border.all(
                                      color: badge.badgeColor,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Icon(
                                isUnlocked ? badge.icon : Icons.lock,
                                color: isUnlocked
                                    ? Colors.white
                                    : Colors.grey[600],
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            badge.name,
                            style: TextStyle(
                              color: isUnlocked
                                  ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF2C2C2C))
                                  : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[600]
                                      : Colors.grey[700]),
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRewardBadgeSection() {
    final allBadges = RewardAdBadgeManager.allBadges;
    final unlockedBadges =
        RewardAdBadgeManager.getUnlockedBadges(_rewardAdWatchCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '広告バッジ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color ??
                          const Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    '${unlockedBadges.length}/${allBadges.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '視聴回数: $_rewardAdWatchCount回',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[300],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 108,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: allBadges.length,
            itemBuilder: (context, index) {
              final badge = allBadges[index];
              final isUnlocked =
                  unlockedBadges.any((b) => b.id == badge.id);
              final isNewlyUnlocked =
                  _newlyUnlockedRewardBadgeIds.contains(badge.id);
              return GestureDetector(
                onTapDown: isUnlocked
                    ? (_) => _showRewardBadgeOverlay(context, badge)
                    : null,
                onTapUp: isUnlocked ? (_) => _hideBadgeOverlay() : null,
                onTapCancel: isUnlocked ? () => _hideBadgeOverlay() : null,
                child: Container(
                  width: 84,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          gradient: isUnlocked
                              ? LinearGradient(
                                  colors: [
                                    badge.badgeColor.withValues(alpha: 0.85),
                                    badge.badgeColor,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isUnlocked ? null : Colors.grey[800],
                          borderRadius: BorderRadius.circular(31),
                          border: isNewlyUnlocked
                              ? Border.all(color: badge.badgeColor, width: 2)
                              : null,
                          boxShadow: isUnlocked
                              ? [
                                  BoxShadow(
                                    color:
                                        badge.badgeColor.withValues(alpha: 0.35),
                                    blurRadius: isNewlyUnlocked ? 14 : 8,
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
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 11,
                          fontWeight:
                              isUnlocked ? FontWeight.w600 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${badge.requiredViews}回',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '広告を視聴すると、視聴回数に応じて広告バッジが解放されます',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: !Platform.isIOS
                ? null
                : _isRewardedBadgeAdReady
                    ? _watchRewardedAdForBadge
                    : _loadRewardedBadgeAd,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFB347),
                    Color(0xFFFF6B35),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.55),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFB347).withValues(alpha: 0.35),
                    blurRadius: 26,
                    spreadRadius: 2,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    !Platform.isIOS
                        ? Icons.block
                        : _isRewardedBadgeAdReady
                            ? Icons.auto_awesome
                            : Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    !Platform.isIOS
                        ? 'iOSのみ対応'
                        : (_isRewardedBadgeAdReady
                            ? '広告視聴でバッジを解放する'
                            : '広告を準備する'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 広告バッジの詳細オーバーレイを表示（タップ中のみ）
  void _showRewardBadgeOverlay(BuildContext context, RewardAdBadge badge) {
    _hideBadgeOverlay();

    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;
    const popupWidth = 280.0;
    const popupHeight = 400.0;
    final left = (screenSize.width - popupWidth) / 2;
    final top = (screenSize.height - popupHeight) / 2;

    _badgeOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: popupWidth,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          badge.badgeColor.withValues(alpha: 0.75),
                          badge.badgeColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: badge.badgeColor.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      badge.icon,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    badge.name,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '獲得条件',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${badge.requiredViews}回の広告視聴で獲得',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_badgeOverlayEntry!);
  }

  /// バッジの詳細オーバーレイを表示（タップ中のみ）
  void _showBadgeOverlay(BuildContext context, Badge badge) {
    // 既存のオーバーレイがあれば削除
    _hideBadgeOverlay();

    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    // ポップアップのサイズを計算
    const popupWidth = 280.0;
    const popupHeight = 400.0;

    // ポップアップの位置を計算（画面中央に配置）
    final left = (screenSize.width - popupWidth) / 2;
    final top = (screenSize.height - popupHeight) / 2;

    _badgeOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // タップイベントを消費して閉じないようにする
            child: Container(
              width: popupWidth,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // バッジのイラスト（大きなアイコン）
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: SpotLightColors.getGradient(badge.id),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: badge.badgeColor.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      badge.icon,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // バッジ名
                  Text(
                    badge.name,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 獲得条件（管理者バッジの場合は特別な表示）
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '獲得条件',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge.id == 999
                              ? '管理者権限を持つユーザー'
                              : '${badge.requiredSpotlights}個のスポットライトを獲得',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_badgeOverlayEntry!);
  }

  /// バッジの詳細オーバーレイを非表示にする
  void _hideBadgeOverlay() {
    if (_badgeOverlayEntry != null) {
      _badgeOverlayEntry!.remove();
      _badgeOverlayEntry = null;
    }
  }

  Widget _buildStatsAndHelpSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 総視聴時間

          const SizedBox(height: 16),

          // 管理者画面（adminがtrueの場合のみ表示）
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              if (authProvider.currentUser?.admin == true) {
                return Column(
                  children: [
                    _buildMenuTile(
                      icon: Icons.admin_panel_settings,
                      title: '管理者画面',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuDivider(context),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // ブロックしたユーザー一覧
          _buildMenuTile(
            icon: Icons.block,
            title: 'ブロックしたユーザー',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BlockedUsersScreen(),
                ),
              );
            },
          ),
          _buildMenuDivider(context),
          const SizedBox(height: 24),

          // 設定
          _buildMenuTile(
            icon: Icons.settings_outlined,
            title: '設定',
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              // プロフィール編集が成功した場合は、プロフィール情報を更新
              if (result == true && mounted) {
                // プロフィール情報を更新
                _refreshProfileData();
              }
            },
          ),
          _buildMenuDivider(context),
          const SizedBox(height: 24),

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
          _buildMenuDivider(context),
          _buildMenuTile(
            icon: Icons.feedback_outlined,
            title: 'フィードバック',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FeedbackScreen(),
                ),
              );
            },
          ),
          _buildMenuDivider(context),
          _buildMenuTile(
            icon: Icons.info_outline,
            title: 'アプリについて',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutScreen(),
                ),
              );
            },
          ),
          _buildMenuDivider(context),
          const SizedBox(height: 24),
          _buildMenuTile(
            icon: Icons.description_outlined,
            title: '利用規約',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsOfServiceScreen(),
                ),
              );
            },
          ),
          _buildMenuDivider(context),
          _buildMenuTile(
            icon: Icons.privacy_tip_outlined,
            title: 'プライバシーポリシー',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          _buildMenuDivider(context),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: theme.textTheme.bodyLarge?.color ??
              (theme.brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF2C2C2C)),
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color ??
                (theme.brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF2C2C2C)),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
          size: 20,
        ),
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildMenuDivider(BuildContext context) {
    final theme = Theme.of(context);
    return Divider(
      height: 1,
      thickness: 1,
      color: theme.brightness == Brightness.dark
          ? Colors.grey[800]
          : Colors.grey[300],
      indent: 0,
      endIndent: 0,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final isGuest = authProvider.currentUser?.id == 'guest';

          final theme = Theme.of(context);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                isGuest ? Icons.exit_to_app : Icons.logout_rounded,
                color: theme.brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                size: 24,
              ),
              title: Text(
                isGuest ? 'ログイン画面へ戻る' : 'ログアウト',
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color ??
                      (theme.brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF2C2C2C)),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: theme.brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                size: 20,
              ),
              onTap: () async {
                // 確認ダイアログを表示
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Theme.of(context).cardColor,
                    title: Text(
                      'ログアウト',
                      style: TextStyle(
                          color: Theme.of(context).textTheme.titleLarge?.color),
                    ),
                    content: Text(
                      isGuest ? 'ログイン画面に戻りますか？' : 'ログアウトしてログイン画面に戻りますか？',
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color),
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
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                );

                // ユーザーが確認した場合
                if (confirmed == true && context.mounted) {
                  // ログアウト処理（ゲストモードもログイン中も同じ処理）
                  await authProvider.logout();

                  // ログイン画面に遷移
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const SocialLoginScreen(),
                      ),
                      (route) => false, // すべての前のルートを削除
                    );
                  }
                }
              },
              contentPadding: EdgeInsets.zero,
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
                leading: Icon(
                  Icons.image_outlined,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                title: Text(
                  'アイコンを設定',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color),
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

  /// 画像を正方形に切り取る（中央から）
  ///
  /// 画像が正方形でない場合、中央から正方形に切り取ります。
  /// 既に正方形の場合はそのまま返します。
  Future<Uint8List?> _cropImageToSquare(Uint8List imageBytes) async {
    try {
      // 画像をデコード
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        return null;
      }

      final width = originalImage.width;
      final height = originalImage.height;

      // 既に正方形の場合はそのまま返す
      if (width == height) {
        return imageBytes;
      }

      // 正方形のサイズを決定（短い辺の長さを使用）
      final size = width < height ? width : height;

      // 切り取る位置を計算（中央から）
      final x = (width - size) ~/ 2;
      final y = (height - size) ~/ 2;

      // 画像を切り取る
      final croppedImage = img.copyCrop(
        originalImage,
        x: x,
        y: y,
        width: size,
        height: size,
      );

      // PNG形式でエンコード（品質を保持）
      final croppedBytes = Uint8List.fromList(img.encodePng(croppedImage));

      return croppedBytes;
    } catch (e) {
      return null;
    }
  }

  /// 画像を選択してアップロード
  Future<void> _pickAndUploadIcon(
      BuildContext context, AuthProvider authProvider) async {
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

      // XFileから直接Uint8Listを取得（Web対応）
      final originalImageBytes = await pickedFile.readAsBytes();

      // 画像を正方形に切り取る
      final imageBytes = await _cropImageToSquare(originalImageBytes);

      if (imageBytes == null) {
        _closeSafeLoadingDialog();
        if (mounted) {
          _showSafeSnackBar('画像の処理に失敗しました');
        }
        return;
      }

      final user = authProvider.currentUser;
      final username = user?.backendUsername;

      if (username == null) {
        _closeSafeLoadingDialog();
        if (mounted) {
          _showSafeSnackBar('ユーザー名が取得できません');
        }
        return;
      }

      // Uint8Listを直接渡す（Webでも動作）
      final iconPath = await UserService.uploadIcon(username, imageBytes);
      _closeSafeLoadingDialog();

      if (!mounted) return;

      if (iconPath != null) {
        // 4. 画像のURLを取得
        // iconPathの形式を確認してURLを生成
        String newIconUrl;
        // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
        if (iconPath.startsWith('http://') || iconPath.startsWith('https://')) {
          newIconUrl = iconPath;
        }
        // 相対パス（/icon/で始まる）の場合はbackendUrlを追加
        else if (iconPath.startsWith('/icon/')) {
          newIconUrl = '${AppConfig.backendUrl}$iconPath';
        }
        // 相対パス（/で始まるが/icon/でない）の場合もbackendUrlを追加
        else if (iconPath.startsWith('/')) {
          newIconUrl = '${AppConfig.backendUrl}$iconPath';
        }
        // ファイル名のみの場合は/icon/を追加
        else {
          newIconUrl = '${AppConfig.backendUrl}/icon/$iconPath';
        }

        // 古いアイコンURLを取得
        String? oldIconUrl;
        if (user?.avatarUrl != null) {
          oldIconUrl = user!.avatarUrl;
        } else if (user?.iconPath != null && user!.iconPath!.isNotEmpty) {
          final oldIconPath = user.iconPath!;
          // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
          if (oldIconPath.startsWith('http://') ||
              oldIconPath.startsWith('https://')) {
            oldIconUrl = oldIconPath;
          }
          // 相対パス（/icon/で始まる）の場合はbackendUrlを追加
          else if (oldIconPath.startsWith('/icon/')) {
            oldIconUrl = '${AppConfig.backendUrl}$oldIconPath';
          }
          // 相対パス（/で始まるが/icon/でない）の場合もbackendUrlを追加
          else if (oldIconPath.startsWith('/')) {
            oldIconUrl = '${AppConfig.backendUrl}$oldIconPath';
          }
          // ファイル名のみの場合は/icon/を追加
          else {
            oldIconUrl = '${AppConfig.backendUrl}/icon/$oldIconPath';
          }
        }

        // 古いキャッシュをクリア（古いURLとデフォルトアイコン）
        await _clearIconCache(oldIconUrl: oldIconUrl);

        // 5. フロントにURLを元に画像を設定 & 6. キャッシュを更新
        // サーバー側で画像処理が完了するまで少し待機
        await Future.delayed(const Duration(milliseconds: 500));

        // バックエンドから最新のユーザー情報を再取得して反映（アイコン変更後は強制更新）
        // 注意: refreshUserInfoFromBackend()はupdateUserInfo()を内部で呼び出すため、
        // この時点でiconPathが更新される可能性がある
        final refreshed =
            await authProvider.refreshUserInfoFromBackend(forceRefresh: true);

        // すべてのアイコンURLのキャッシュをクリア（確実に再読み込み）
        final allIconUrls = <String>[];
        if (oldIconUrl != null) {
          allIconUrls.add(oldIconUrl);
        }
        allIconUrls.add(newIconUrl);

        // 再取得後のURLも追加
        final refreshedUser = authProvider.currentUser;
        String? refreshedIconUrl;
        if (refreshedUser?.iconPath != null &&
            refreshedUser!.iconPath!.isNotEmpty) {
          // iconPathの形式を確認
          final refreshedIconPath = refreshedUser.iconPath!;
          // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
          if (refreshedIconPath.startsWith('http://') ||
              refreshedIconPath.startsWith('https://')) {
            refreshedIconUrl = refreshedIconPath;
          }
          // 相対パス（/icon/で始まる）の場合はbackendUrlを追加
          else if (refreshedIconPath.startsWith('/icon/')) {
            refreshedIconUrl = '${AppConfig.backendUrl}$refreshedIconPath';
          }
          // 相対パス（/で始まるが/icon/でない）の場合もbackendUrlを追加
          else if (refreshedIconPath.startsWith('/')) {
            refreshedIconUrl = '${AppConfig.backendUrl}$refreshedIconPath';
          }
          // ファイル名のみの場合は/icon/を追加
          else {
            refreshedIconUrl =
                '${AppConfig.backendUrl}/icon/$refreshedIconPath';
          }
        } else {
          refreshedIconUrl = '${AppConfig.backendUrl}/icon/default_icon.png';
        }
        if (!allIconUrls.contains(refreshedIconUrl)) {
          allIconUrls.add(refreshedIconUrl);
        }

        // すべてのURLのキャッシュをクリア
        for (final url in allIconUrls) {
          try {
            await CachedNetworkImage.evictFromCache(url);
          } catch (e) {
            // ignore
          }
        }

        // キャッシュキー付きURLもクリア
        final now = DateTime.now();
        for (int i = 0; i < 60; i++) {
          final testTime = now.subtract(Duration(seconds: i));
          final cacheKey =
              '${testTime.year}${testTime.month.toString().padLeft(2, '0')}${testTime.day.toString().padLeft(2, '0')}${testTime.hour.toString().padLeft(2, '0')}${testTime.minute.toString().padLeft(2, '0')}${testTime.second.toString().padLeft(2, '0')}';
          for (final baseUrl in [newIconUrl, refreshedIconUrl]) {
            try {
              final cachedUrl = baseUrl.contains('?')
                  ? '$baseUrl&cache=$cacheKey'
                  : '$baseUrl?cache=$cacheKey';
              await CachedNetworkImage.evictFromCache(cachedUrl);
            } catch (e) {
              // エラーは無視（存在しないキャッシュの場合がある）
            }
          }
        }

        // 他の画面にアイコン更新を通知（ホーム画面など）
        // 通知を送信する前に、新しいアイコンURLを確実に反映させる
        // iconPathを正しい形式に変換
        String notificationIconPath;
        // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
        if (iconPath.startsWith('http://') || iconPath.startsWith('https://')) {
          notificationIconPath = iconPath;
        }
        // 相対パス（/icon/で始まる）の場合はそのまま使用
        else if (iconPath.startsWith('/icon/')) {
          notificationIconPath = iconPath;
        }
        // 相対パス（/で始まるが/icon/でない）の場合もそのまま使用
        else if (iconPath.startsWith('/')) {
          notificationIconPath = iconPath;
        }
        // ファイル名のみの場合は/icon/を追加
        else {
          notificationIconPath = '/icon/$iconPath';
        }
        IconUpdateService().notifyIconUpdate(
          username,
          iconPath: notificationIconPath,
        );

        if (mounted) {
          // iconPathを正しい形式に変換
          // uploadIconは完全なURLまたはファイル名のみを返す可能性がある
          String finalIconPath;
          if (iconPath.startsWith('http://') ||
              iconPath.startsWith('https://')) {
            // 完全なURLの場合はそのまま使用（CloudFront URLなど）
            finalIconPath = iconPath;
          } else if (iconPath.startsWith('/icon/')) {
            // /icon/で始まる相対パスの場合はそのまま使用
            finalIconPath = iconPath;
          } else if (iconPath.startsWith('/')) {
            // /で始まるが/icon/でない相対パスの場合もそのまま使用
            finalIconPath = iconPath;
          } else {
            // ファイル名のみの場合は/icon/を追加
            finalIconPath = '/icon/$iconPath';
          }

          // まず、手動でiconPathを更新（確実に反映させるため）
          await authProvider.updateUserInfo(iconPath: finalIconPath);

          // 更新直後に確認（notifyListeners()の処理を待つ）
          await Future.delayed(const Duration(milliseconds: 200));
          final afterUpdate = authProvider.currentUser;

          // iconPathがまだ更新されていない場合は、再度更新を試みる
          if (afterUpdate?.iconPath != finalIconPath) {
            await authProvider.updateUserInfo(iconPath: finalIconPath);
            await Future.delayed(const Duration(milliseconds: 200));
          }

          // refreshUserInfoFromBackend()は既にupdateUserInfo()を内部で呼び出しているため、
          // ここで再度updateUserInfo()を呼び出す必要はない
          // ただし、refreshUserInfoFromBackend()が失敗した場合や、
          // iconPathが期待する値と異なる場合は、手動でupdateUserInfo()を呼び出す
          if (refreshed) {
            final refreshedUserAfterRefresh = authProvider.currentUser;
            final refreshedIconPath = refreshedUserAfterRefresh?.iconPath;

            // 再取得後のiconPathが期待する値と異なる場合は、手動更新を試みる
            // バックエンドから取得した最新情報を優先する
            if (refreshedIconPath != null && refreshedIconPath.isNotEmpty) {
              // 再取得後のiconPathが期待する値と異なる場合
              if (refreshedIconPath != finalIconPath) {
                // 再取得後のiconPathを使用（バックエンドの最新情報を優先）
                await authProvider.updateUserInfo(iconPath: refreshedIconPath);
                // finalIconPathを更新（以降の処理で使用）
                finalIconPath = refreshedIconPath;
              }
            } else {
              // 再取得後のiconPathがnullまたは空の場合は、手動更新を試みる
              await authProvider.updateUserInfo(iconPath: finalIconPath);
            }
          } else {
            // refreshUserInfoFromBackend()が失敗した場合は、手動更新のみに依存
          }

          // 現在のユーザー情報を確認（updateUserInfo後の最新情報）
          final currentUser = authProvider.currentUser;

          // アイコンURLのキャッシュを完全にクリア（新しいiconPathに対応）
          // finalIconPathの形式を確認してURLを生成
          String expectedIconUrl;
          // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
          if (finalIconPath.startsWith('http://') ||
              finalIconPath.startsWith('https://')) {
            expectedIconUrl = finalIconPath;
          }
          // 相対パス（/icon/で始まる）の場合はbackendUrlを追加
          else if (finalIconPath.startsWith('/icon/')) {
            expectedIconUrl = '${AppConfig.backendUrl}$finalIconPath';
          }
          // 相対パス（/で始まるが/icon/でない）の場合もbackendUrlを追加
          else if (finalIconPath.startsWith('/')) {
            expectedIconUrl = '${AppConfig.backendUrl}$finalIconPath';
          }
          // ファイル名のみの場合は/icon/を追加
          else {
            expectedIconUrl = '${AppConfig.backendUrl}/icon/$finalIconPath';
          }

          // すべてのアイコンURLのキャッシュをクリア（確実に再読み込み）
          final allUrlsToClear = <String>[
            expectedIconUrl,
            newIconUrl,
            if (oldIconUrl != null) oldIconUrl,
            refreshedIconUrl, // refreshedIconUrlは既にnullチェック済み
          ];

          // DefaultCacheManagerを使用して、すべてのキャッシュをクリア
          try {
            final cacheManager = DefaultCacheManager();
            await cacheManager.emptyCache();
          } catch (e) {
            // ignore
          }

          for (final url in allUrlsToClear) {
            try {
              // ベースURLをクリア（キャッシュキーを除いたURL）
              final baseUrl = url.split('?').first.split('&').first;
              await CachedNetworkImage.evictFromCache(baseUrl);
              await CachedNetworkImage.evictFromCache(url);

              // DefaultCacheManagerでもクリア
              try {
                final cacheManager = DefaultCacheManager();
                await cacheManager.removeFile(baseUrl);
                await cacheManager.removeFile(url);
              } catch (e) {
                // エラーは無視
              }

              // iconPathに関連するすべてのキャッシュキー付きURLもクリア
              // キャッシュキーはiconPathなので、iconPathを含むすべてのURLをクリア
              final iconPathForCache = finalIconPath;
              if (iconPathForCache.isNotEmpty) {
                // iconPathを含むすべてのURLパターンをクリア
                final urlPatterns = [
                  baseUrl,
                  url,
                  '$baseUrl?cache=$iconPathForCache',
                  '$baseUrl&cache=$iconPathForCache',
                ];
                for (final pattern in urlPatterns) {
                  try {
                    await CachedNetworkImage.evictFromCache(pattern);
                    final cacheManager = DefaultCacheManager();
                    await cacheManager.removeFile(pattern);
                  } catch (e) {
                    // エラーは無視
                  }
                }
              }
            } catch (e) {
              // ignore
            }
          }

          // 追加で、すべての可能性のあるURLパターンをクリア
          // 完全なURLの場合はそのまま、相対パスの場合はbackendUrlを追加したURLもクリア
          final additionalUrlsToClear = <String>[];
          for (final url in allUrlsToClear) {
            // ベースURLを取得
            final baseUrl = url.split('?').first.split('&').first;
            additionalUrlsToClear.add(baseUrl);

            // 完全なURLの場合は、相対パス形式も試す
            if (baseUrl.startsWith('http://') ||
                baseUrl.startsWith('https://')) {
              // CloudFront URLの場合は、backendUrl形式も試す
              if (baseUrl.contains('cloudfront.net')) {
                final pathMatch = RegExp(r'/icon/([^/]+)$').firstMatch(baseUrl);
                if (pathMatch != null) {
                  final filename = pathMatch.group(1);
                  additionalUrlsToClear
                      .add('${AppConfig.backendUrl}/icon/$filename');
                }
              }
            }
          }

          // 追加のURLもクリア
          for (final url in additionalUrlsToClear) {
            if (!allUrlsToClear.contains(url)) {
              try {
                await CachedNetworkImage.evictFromCache(url);
              } catch (e) {
                // エラーは無視
              }
            }
          }

          // 画面を再構築してアイコンを更新（即座に反映）
          // Consumer<AuthProvider>はupdateUserInfo内でnotifyListeners()が呼ばれるため、
          // 自動的に再構築される。しかし、確実に反映させるためにsetState()も呼び出す
          if (mounted) {
            // キャッシュクリア後に少し待ってからsetState()を呼び出す（確実に再構築されるようにする）
            await Future.delayed(const Duration(milliseconds: 100));

            setState(() {
              // iconPathが変更されたことを確実に反映するため、空のsetStateを呼び出す
              // Consumer<AuthProvider>が再構築されるようにする
            });

            // さらに少し待ってから再度setState()を呼び出す（確実に再構築されるようにする）
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              setState(() {
                // 再度setState()を呼び出して、確実に再構築されるようにする
              });
            }
          }

          // 少し待ってから再度再構築（サーバー側の処理完了を待つ）
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            // 再度ユーザー情報を確認
            final updatedUser = authProvider.currentUser;

            // iconPathがまだ更新されていない場合は、再度手動更新
            if (updatedUser?.iconPath != finalIconPath) {
              // 再度updateUserInfoを呼び出して、notifyListeners()を確実に呼ぶ
              await authProvider.updateUserInfo(iconPath: finalIconPath);

              // 少し待ってからsetStateを呼び出す（notifyListeners()の処理を待つ）
              await Future.delayed(const Duration(milliseconds: 200));
            }

            // アイコンキャッシュを再度クリア（確実に再読み込み）
            // finalIconPathの形式を確認してURLを生成
            String expectedIconUrlForRetry;
            // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
            if (finalIconPath.startsWith('http://') ||
                finalIconPath.startsWith('https://')) {
              expectedIconUrlForRetry = finalIconPath;
            }
            // 相対パス（/icon/で始まる）の場合はbackendUrlを追加
            else if (finalIconPath.startsWith('/icon/')) {
              expectedIconUrlForRetry = '${AppConfig.backendUrl}$finalIconPath';
            }
            // 相対パス（/で始まるが/icon/でない）の場合もbackendUrlを追加
            else if (finalIconPath.startsWith('/')) {
              expectedIconUrlForRetry = '${AppConfig.backendUrl}$finalIconPath';
            }
            // ファイル名のみの場合は/icon/を追加
            else {
              expectedIconUrlForRetry =
                  '${AppConfig.backendUrl}/icon/$finalIconPath';
            }
            try {
              // ベースURLをクリア（キャッシュキーを除いたURL）
              final baseUrlForRetry =
                  expectedIconUrlForRetry.split('?').first.split('&').first;
              await CachedNetworkImage.evictFromCache(baseUrlForRetry);
              await CachedNetworkImage.evictFromCache(expectedIconUrlForRetry);

              // DefaultCacheManagerでもクリア
              try {
                final cacheManager = DefaultCacheManager();
                await cacheManager.removeFile(baseUrlForRetry);
                await cacheManager.removeFile(expectedIconUrlForRetry);
              } catch (e) {
                // エラーは無視
              }

              // iconPathに関連するすべてのキャッシュキー付きURLもクリア
              // キャッシュキーはiconPathなので、iconPathを含むすべてのURLをクリア
              final iconPathForRetry = finalIconPath;
              if (iconPathForRetry.isNotEmpty) {
                // iconPathを含むすべてのURLパターンをクリア
                final urlPatterns = [
                  baseUrlForRetry,
                  expectedIconUrlForRetry,
                  '$baseUrlForRetry?cache=$iconPathForRetry',
                  '$baseUrlForRetry&cache=$iconPathForRetry',
                ];
                for (final pattern in urlPatterns) {
                  try {
                    await CachedNetworkImage.evictFromCache(pattern);
                    final cacheManager = DefaultCacheManager();
                    await cacheManager.removeFile(pattern);
                  } catch (e) {
                    // エラーは無視
                  }
                }
              }
            } catch (e) {
              // ignore
            }

            // 最終的にsetStateを呼び出して、Consumer<AuthProvider>が再構築されるようにする
            setState(() {
              // iconPathが変更されたことを確実に反映するため、空のsetStateを呼び出す
              // Consumer<AuthProvider>が再構築されるようにする
            });

          }

          // 7. レスポンスメッセージ表示
          _showSafeSnackBar('アイコンを設定しました', backgroundColor: Colors.green);
        }
      } else {
        if (mounted) {
          _showSafeSnackBar('アイコンの設定に失敗しました');
        }
      }
    } catch (e) {
      _closeSafeLoadingDialog();

      // 7. エラーメッセージ表示
      if (mounted) {
        String errorMessage = 'エラーが発生しました';

        // エラーの種類に応じてメッセージをカスタマイズ
        if (e.toString().contains('timeout') ||
            e.toString().contains('タイムアウト')) {
          errorMessage = '通信がタイムアウトしました';
        } else if (e.toString().contains('network') ||
            e.toString().contains('ネットワーク')) {
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
  Future<void> _deleteIcon(
      BuildContext context, AuthProvider authProvider) async {
    // 確認ダイアログを表示
    final confirmed = await _showSafeDialog<bool>(
      Builder(
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text(
              'アイコンを削除',
              style: TextStyle(color: theme.textTheme.titleLarge?.color),
            ),
            content: Text(
              'アイコンを削除しますか？',
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
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
          );
        },
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
      // アイコンキャッシュをクリア（アイコン削除を反映するため）
      _clearIconCache();

      // デフォルトアイコンの処理
      await _setDefaultIcon(authProvider);

      // サーバー側で処理が完了するまで待機（500ms）
      await Future.delayed(const Duration(milliseconds: 500));

      // 他の画面にアイコン削除を通知（ホーム画面など）
      // nullの代わりに/icon/default_icon.pngを明示的に指定
      IconUpdateService().notifyIconUpdate(
        username,
        iconPath: '/icon/default_icon.png', // デフォルトアイコンを明示的に指定
      );

      if (mounted) {
        // 画面を強制的に再構築してデフォルトアイコンを表示
        setState(() {});

        _showSafeSnackBar('アイコンをデフォルトに変更しました', backgroundColor: Colors.green);
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
    // S3のCloudFront URLからデフォルトアイコンを読み込む
    // DB上ではdefault_icon.pngになっているが、S3のspotlight-contents/icon/default_icon.pngを使用
    const defaultIconPath = '/icon/default_icon.png';
    final defaultIconUrl =
        '${AppConfig.cloudFrontUrl}/spotlight-contents/icon/default_icon.png';

    bool refreshed = false;

    try {
      // S3のデフォルトアイコンが利用可能かを確認（非同期で実行、エラーは無視）
      http
          .head(Uri.parse(defaultIconUrl))
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => http.Response('', 404),
          )
          .then((response) {
        // S3のデフォルトアイコン確認（結果はログに出力しない）
      }).catchError((e) {
        // エラーは無視（S3の確認はオプション）
      });

      // バックエンドから最新のユーザー情報を再取得して反映（admin情報も含む）
      // refreshUserInfoFromBackendはupdateUserInfoを内部で呼び出すため、
      // バックエンドから取得したadmin情報も正しく反映される
      refreshed =
          await authProvider.refreshUserInfoFromBackend(forceRefresh: true);
    } catch (e) {
      // ignore
    }

    // refreshUserInfoFromBackendが失敗した場合のみ、フォールバックとしてupdateUserInfoを使用
    if (!refreshed) {
      try {
        await authProvider.updateUserInfo(iconPath: defaultIconPath);
      } catch (e) {
        // ignore
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
