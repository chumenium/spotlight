import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/search_history.dart';
import '../models/post.dart';
import '../services/search_service.dart';
import '../utils/spotlight_colors.dart';

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
    final query = _searchController.text;
    if (!_isDisposed && mounted) {
      setState(() {
        if (query.isEmpty) {
          _filteredSuggestions = _allSuggestions;
        } else {
          _filteredSuggestions = _allSuggestions
              .where((suggestion) => 
                  suggestion.query.toLowerCase().contains(query.toLowerCase()))
              .toList();
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
              child: _isSearching 
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 検索履歴
          if (_searchHistory.isNotEmpty) ...[
            _buildSectionHeader('検索履歴'),
            _buildSearchHistory(),
            const SizedBox(height: 20),
          ] else ...[
            _buildSectionHeader('検索履歴'),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '検索履歴がありません',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
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
            _buildSuggestions(),
        ],
      ),
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
    
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        return _buildSearchResultItem(post);
      },
    );
  }

  Widget _buildSearchResultItem(Post post) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty
            ? Image.network(
                post.thumbnailUrl!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey[800],
                    child: Icon(
                      Icons.image,
                      color: Colors.grey[600],
                    ),
                  );
                },
              )
            : Container(
                width: 56,
                height: 56,
                color: Colors.grey[800],
                child: Icon(
                  Icons.image,
                  color: Colors.grey[600],
                ),
              ),
      ),
      title: Text(
        post.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.flashlight_on,
                size: 14,
                color: SpotLightColors.getSpotlightColor(0),
              ),
              const SizedBox(width: 4),
              Text(
                '${post.likes}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.play_circle_outline,
                size: 14,
                color: Colors.grey[400],
              ),
              const SizedBox(width: 4),
              Text(
                '${post.playNum}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _getTimeAgo(post.createdAt),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        // 検索結果の投稿詳細に遷移（後で実装）
      },
    );
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

  Widget _buildSearchHistory() {
    return Column(
      children: _searchHistory.take(5).map((history) {
        return _buildHistoryItem(history);
      }).toList(),
    );
  }

  Widget _buildHistoryItem(SearchHistory history) {
    return ListTile(
      leading: const Icon(
        Icons.history,
        color: Colors.grey,
        size: 20,
      ),
      title: Text(
        history.query,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        _getTimeAgo(history.searchedAt),
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        onPressed: () {
          setState(() {
            _searchHistory.remove(history);
          });
        },
        icon: const Icon(
          Icons.close,
          color: Colors.grey,
          size: 16,
        ),
      ),
      onTap: () {
        _searchController.text = history.query;
        _performSearch(history.query);
      },
    );
  }

  Widget _buildSuggestions() {
    return Column(
      children: _filteredSuggestions.map((suggestion) {
        return _buildSuggestionItem(suggestion);
      }).toList(),
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

  String _getTimeAgo(DateTime dateTime) {
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
}