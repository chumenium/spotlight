import 'package:flutter/material.dart';
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
          _filteredSuggestions = _allSuggestions;
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
      
      if (!_isDisposed && mounted) {
        setState(() {
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '検索',
                  hintStyle: TextStyle(color: Colors.grey[400]),
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'おすすめ検索がありません',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
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
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    
    if (kDebugMode) {
      debugPrint('🔍 ホーム画面に遷移: 投稿ID=${post.id}');
    }
    
    // ホーム画面に遷移して投稿IDを設定
    navigationProvider.navigateToHome(postId: post.id);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
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
          onDeleted: () {
            setState(() {
              _searchHistory.remove(history);
            });
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
          fontWeight: suggestion.isTrending 
              ? FontWeight.w600
              : FontWeight.normal,
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