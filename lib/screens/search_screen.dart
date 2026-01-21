import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
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

      if (!_isDisposed && mounted) {
        setState(() {
          _searchHistory = history;
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
          // 検索結果を完全に置き換える（新しい検索の場合は既存の結果をクリア）
          _searchResults = results;
          _isSearching = false;
        });
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
                  cacheWidth: (160 * MediaQuery.of(context).devicePixelRatio).round(),
                  cacheHeight: (45 * MediaQuery.of(context).devicePixelRatio).round(),
                  errorBuilder: (context, error, stackTrace) {
                    // ロゴ画像が見つからない場合は何も表示しない
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // 検索バー
                _buildSearchBar(),

                // 検索結果または検索履歴・おすすめ
                Expanded(
                  child: _searchResults.isNotEmpty || _isSearching
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

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 検索入力フィールド
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                maxLength: 100,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF2C2C2C),
                ),
                decoration: InputDecoration(
                  hintText: '検索',
                  hintStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey[400] 
                        : Colors.grey[600],
                  ),
                  border: InputBorder.none,
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.grey,
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
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
            ),
          ),
        ],
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 検索履歴
          if (_searchHistory.isNotEmpty) ...[
            _buildSectionHeader('最近の検索'),
            _buildSearchHistoryChips(),
            const SizedBox(height: 20),
          ],

          // おすすめ検索
          _buildSectionHeader('おすすめ検索'),
          if (_allSuggestions.isEmpty)
            Padding(
              // 左詰めで固定（左端の余白を8pxに設定）
              padding:
                  const EdgeInsets.only(left: 8, top: 8, bottom: 8, right: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'おすすめ検索がありません',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            _buildSuggestionsChips(),
        ],
      ),
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
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFFF6B35),
            ),
            SizedBox(height: 16),
            Text(
              '検索中...',
              style: TextStyle(
                color: Colors.white,
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
              color: Colors.white70,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '「$_searchQuery」の検索結果はありません',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // TikTok風のタイル表示（グリッドレイアウト）
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2列のグリッド
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.75, // 縦長のタイル
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        return _buildSearchResultTile(post);
      },
    );
  }

  /// TikTok風のタイル表示
  Widget _buildSearchResultTile(Post post) {
    final thumbnailUrl = post.thumbnailUrl ?? post.mediaUrl;

    return GestureDetector(
      onTap: () {
        // ホーム画面に遷移して投稿を再生
        if (kDebugMode) {
          debugPrint('🔍 検索結果タップ: ${post.id} - ${post.title}');
        }
        _navigateToPost(post);
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
                child: Image.network(
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
                ),
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

  /// 検索履歴をチップ形式で表示
  Widget _buildSearchHistoryChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _searchHistory.take(10).map((history) {
          return _buildHistoryChip(history);
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryChip(SearchHistory history) {
    return GestureDetector(
      onTap: () {
        _searchController.text = history.query;
        _performSearch(history.query);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        child: Chip(
          avatar: const Icon(
            Icons.history,
            size: 16,
            color: Colors.grey,
          ),
          label: Text(
            history.query,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          backgroundColor: Colors.grey[800],
          deleteIcon: const Icon(
            Icons.close,
            size: 16,
            color: Colors.grey,
          ),
          onDeleted: () async {
            // バックエンドから検索履歴を削除
            final success = await SearchService.deleteSearchHistory(history.id);
            
            if (success) {
              // 削除成功時はローカルのリストからも削除
              if (mounted) {
                setState(() {
                  _searchHistory.remove(history);
                });
              }
            } else {
              // 削除失敗時はエラーメッセージを表示（オプション）
              if (kDebugMode) {
                debugPrint('⚠️ 検索履歴の削除に失敗しました: serchID=${history.id}');
              }
              // エラー時もローカルから削除（UIの一貫性のため）
              if (mounted) {
                setState(() {
                  _searchHistory.remove(history);
                });
              }
            }
          },
        ),
      ),
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
