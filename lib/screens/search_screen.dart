import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/search_history.dart';
import '../models/post.dart';
import '../services/search_service.dart';
import '../utils/spotlight_colors.dart';
import '../providers/navigation_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  bool _isLoadingHistory = false;

  // バックエンドから取得
  List<SearchHistory> _searchHistory = [];
  final List<SearchSuggestion> _allSuggestions = [];
  List<SearchSuggestion> _filteredSuggestions = [];
  List<Post> _searchResults = [];
  String? _searchQuery;

  // ウィジェットの破棄状態を管理
  bool _isDisposed = false;
  int? _lastNavigationIndex; // 最後に処理したナビゲーションインデックス

  @override
  void initState() {
    super.initState();
    _filteredSuggestions = _allSuggestions;
    _searchController.addListener(_onSearchChanged);

    // バックエンドから検索履歴を取得
    _fetchSearchHistory();
  }

  /// バックエンドから検索履歴を取得
  Future<void> _fetchSearchHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final history = await SearchService.fetchSearchHistory();
      // 検索されたタイミングの新しい順（上に随時追加）で表示
      final sorted = List<SearchHistory>.from(history)
        ..sort((a, b) => b.searchedAt.compareTo(a.searchedAt));

      if (!_isDisposed && mounted) {
        setState(() {
          _searchHistory = sorted;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔍 検索履歴取得エラー: $e');
      }

      if (!_isDisposed && mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (!_isDisposed && mounted) {
      setState(() {
        if (query.isEmpty) {
          // 検索欄が空の場合は初期状態に戻す
          _filteredSuggestions = _allSuggestions;
          _searchResults = []; // 検索結果をクリア
          _searchQuery = null; // 検索クエリをクリア
          _isSearching = false; // 検索中フラグをリセット
        } else {
          // 検索履歴から候補を生成
          final historySuggestions = _searchHistory
              .where((history) =>
                  history.query.toLowerCase().contains(query.toLowerCase()))
              .map((history) => SearchSuggestion(
                    id: 'history_${history.id}',
                    query: history.query,
                    description: '検索履歴',
                    isTrending: false,
                  ))
              .toList();

          // おすすめ検索から候補を生成
          final suggestionMatches = _allSuggestions
              .where((suggestion) =>
                  suggestion.query.toLowerCase().contains(query.toLowerCase()))
              .toList();

          // 検索履歴とおすすめを結合（重複を除去）
          final allSuggestions = <String, SearchSuggestion>{};
          for (final suggestion in historySuggestions) {
            allSuggestions[suggestion.query] = suggestion;
          }
          for (final suggestion in suggestionMatches) {
            allSuggestions[suggestion.query] = suggestion;
          }

          _filteredSuggestions = allSuggestions.values.toList();
        }
      });
    }
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    if (!_isDisposed && mounted) {
      setState(() {
        _isSearching = true;
        _searchQuery = query;
      });
    }

    try {
      final results = await SearchService.searchPosts(query);

      if (kDebugMode) {
        debugPrint('🔍 検索結果取得: ${results.length}件');
        for (final post in results) {
          debugPrint('  - ID: ${post.id}, タイトル: ${post.title}');
        }
      }

      if (!_isDisposed && mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
        // 検索履歴を再取得して、今回の検索を上に追加した順で表示
        _fetchSearchHistory();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔍 検索エラー: $e');
      }

      if (!_isDisposed && mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // NavigationProviderの変更をリッスンして、検索画面が表示されたときに再取得
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, _) {
        final currentIndex = navigationProvider.currentIndex;

        // 検索画面が表示されている場合、かつ前回と異なる場合に再取得
        if (currentIndex == 1 && _lastNavigationIndex != 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDisposed) {
              setState(() {
                _lastNavigationIndex = 1;
              });
              _fetchSearchHistory();
            }
          });
        } else if (currentIndex != 1) {
          _lastNavigationIndex = currentIndex;
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            toolbarHeight: 56,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                final nav = Provider.of<NavigationProvider>(context, listen: false);
                nav.setCurrentIndex(0); // ホームタブへ
              },
              color: Theme.of(context).iconTheme.color,
            ),
            title: _buildSearchBar(),
            titleSpacing: 0,
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: (_isSearching || _searchQuery != null)
                      ? _buildSearchResults()
                      : _buildSearchContent(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 検索バー（アプリバー内・音声入力なし）。タップでキーボード表示。
  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 46,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(23),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        maxLength: 100,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.text,
        buildCounter: (
          BuildContext context, {
          required int currentLength,
          required bool isFocused,
          int? maxLength,
        }) =>
            null,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
          fontSize: 18,
        ),
        decoration: InputDecoration(
          hintText: 'Spotlightを検索',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 18,
          ),
          isDense: true,
          border: InputBorder.none,
          prefixIcon: null,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.grey,
                    size: 20,
                  ),
                )
              : null,
        ),
        onSubmitted: _performSearch,
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF6B35),
        ),
      );
    }

    final query = _searchController.text.trim();

    // 検索入力中は候補を表示
    if (query.isNotEmpty && _filteredSuggestions.isNotEmpty) {
      return _buildSearchSuggestions();
    }

    // 直近の検索を一列リスト表示（サムネイルなし）
    if (_searchHistory.isEmpty) {
      return Center(
        child: Text(
          '最近の検索はありません',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6) ?? Colors.grey,
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _searchHistory.length,
      itemBuilder: (context, index) {
        final history = _searchHistory[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _buildSearchHistoryRow(history),
        );
      },
    );
  }

  /// 検索候補を表示（入力中）
  Widget _buildSearchSuggestions() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _filteredSuggestions[index];
        return _buildSuggestionItem(suggestion);
      },
    );
  }

  Widget _buildSearchResults() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A1A);
    final secondaryTextColor =
        isDark ? Colors.white70 : const Color(0xFF5A5A5A);
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFFF6B35),
            ),
            SizedBox(height: 16),
            Text(
              '検索中...',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              color: secondaryTextColor,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '検索に該当するコンテンツはありませんでした。\n検索内容を変えてもう一度検索してみてください',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // サムネイル＋下にメタデータ（参考画像レイアウト）
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.58, // サムネイル＋下のメタデータ行の高さ
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        return _buildSearchResultTile(post);
      },
    );
  }

  /// 投稿日時を端末のローカル時刻に変換（Post.createdAt は UTC で保持されている前提）
  DateTime _postTimeLocal(Post post) {
    return post.createdAt.toLocal();
  }

  /// 投稿日時を相対表示（視聴履歴画面と同じロジック：.toLocal() 済みのローカル時刻で算出）
  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}日前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分前';
    } else {
      return 'たった今';
    }
  }

  /// 再生回数を表示用にフォーマット（1.8万 など）
  String _formatPlayCount(int playNum) {
    if (playNum >= 10000) {
      return '${(playNum / 10000).toStringAsFixed(1)}万';
    }
    return playNum.toString();
  }

  /// 投稿者のアイコン表示（URLがあればネットワーク画像、なければプレースホルダー）
  Widget _buildUserIcon(Post post, Color placeholderColor) {
    final iconUrl = post.userIconUrl;
    if (iconUrl != null && iconUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: iconUrl,
          fit: BoxFit.cover,
          width: 28,
          height: 28,
          errorWidget: (_, __, ___) => Icon(
            Icons.person,
            size: 20,
            color: placeholderColor,
          ),
        ),
      );
    }
    return Icon(
      Icons.person,
      size: 20,
      color: placeholderColor,
    );
  }

  /// 検索結果タイル：サムネイル内にタイトルのみ、メタデータはサムネイルの下（参考画像レイアウト）
  Widget _buildSearchResultTile(Post post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A1A);
    final overlayEndColor = isDark
        ? Colors.black.withOpacity(0.8)
        : SpotLightColors.peach.withOpacity(0.9);
    final metaTextColor =
        isDark ? Colors.white : const Color(0xFF1A1A1A);
    final metaSecondaryColor =
        isDark ? Colors.white70 : const Color(0xFF5A5A5A);
    final thumbnailUrl = post.thumbnailUrl ?? post.mediaUrl;

    return GestureDetector(
      onTap: () {
        if (kDebugMode) {
          debugPrint('🔍 検索結果タップ: ${post.id} - ${post.title}');
        }
        _navigateToPost(post);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // サムネイル（内側にタイトルのみオーバーレイ）
          Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                      Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(
                                Icons.image,
                                color: Colors.grey,
                                size: 32,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 32,
                          ),
                        ),
                      ),
                    // タイトルのみサムネイル内に表示
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              overlayEndColor,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          post.title,
                          style: TextStyle(
                            color: overlayTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // サムネイルの下：左にアイコン、右にユーザー名／回視聴・投稿日時（参考画像レイアウト）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左：円形アイコン
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                    child: _buildUserIcon(post, metaSecondaryColor),
                  ),
                  const SizedBox(width: 8),
                  // 右：ユーザー名＋回視聴・投稿日時（2行）
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.username.isNotEmpty
                              ? post.username
                              : 'ユーザー',
                          style: TextStyle(
                            color: metaTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatPlayCount(post.playNum)} 回視聴・${_formatRelativeTime(_postTimeLocal(post))}',
                          style: TextStyle(
                            color: metaSecondaryColor,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  /// ホーム画面に遷移して投稿を再生
  void _navigateToPost(Post post) {
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);

    if (kDebugMode) {
      debugPrint('🔍 ホーム画面に遷移: 投稿ID=${post.id}, contentID=${post.id}');
      debugPrint('🔍 投稿タイトル: ${post.title}');
    }

    // 投稿IDが空の場合はエラー
    if (post.id.isEmpty) {
      if (kDebugMode) {
        debugPrint('❌ 投稿IDが空です');
      }
      return;
    }

    // ホーム画面に遷移して投稿IDとタイトルを設定（タイトルは検証用）
    navigationProvider.navigateToHome(postId: post.id, postTitle: post.title);

    if (kDebugMode) {
      debugPrint(
          '✅ NavigationProviderに投稿IDを設定: ${navigationProvider.targetPostId}');
      debugPrint(
          '✅ NavigationProviderに投稿タイトルを設定: ${navigationProvider.targetPostTitle}');
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      // 左詰めで固定（左端の余白を8pxに設定）
      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8, right: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 検索履歴を1行表示（サムネイルなし・履歴アイコン＋クエリ＋矢印）
  Widget _buildSearchHistoryRow(SearchHistory history) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    return ListTile(
      leading: Icon(
        Icons.history,
        color: Colors.grey,
        size: 26,
      ),
      title: Text(
        history.query,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.north_east,
          color: Colors.grey,
          size: 20,
        ),
        onPressed: () {
          _searchController.text = history.query;
          _searchFocusNode.requestFocus();
        },
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
      onTap: () {
        _searchController.text = history.query;
        _performSearch(history.query);
      },
      onLongPress: () async {
        final success = await SearchService.deleteSearchHistory(history.id);
        if (success && mounted) {
          setState(() {
            _searchHistory.remove(history);
          });
        }
      },
    );
  }

  /// おすすめ検索をチップ形式で表示
  Widget _buildSuggestionsChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _allSuggestions.map((suggestion) {
          return _buildSuggestionChip(suggestion);
        }).toList(),
      ),
    );
  }

  Widget _buildSuggestionChip(SearchSuggestion suggestion) {
    return FilterChip(
      avatar: suggestion.isTrending
          ? Icon(
              Icons.trending_up,
              size: 16,
              color: SpotLightColors.getSpotlightColor(0),
            )
          : const Icon(
              Icons.search,
              size: 16,
              color: Colors.grey,
            ),
      label: Text(
        suggestion.query,
        style: TextStyle(
          color: suggestion.isTrending
              ? SpotLightColors.getSpotlightColor(0)
              : Colors.white,
          fontSize: 14,
          fontWeight:
              suggestion.isTrending ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      backgroundColor: Colors.grey[800],
      selectedColor: Colors.grey[700],
      onSelected: (selected) {
        _searchController.text = suggestion.query;
        _performSearch(suggestion.query);
      },
    );
  }

  Widget _buildSuggestionItem(SearchSuggestion suggestion) {
    return ListTile(
      leading: suggestion.isTrending
          ? Icon(
              Icons.trending_up,
              color: SpotLightColors.getSpotlightColor(0),
              size: 20,
            )
          : const Icon(
              Icons.search,
              color: Colors.grey,
              size: 20,
            ),
      title: Text(
        suggestion.query,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      subtitle: suggestion.description != null
          ? Text(
              suggestion.description!,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            )
          : null,
      onTap: () {
        _searchController.text = suggestion.query;
        _performSearch(suggestion.query);
      },
    );
  }
}
