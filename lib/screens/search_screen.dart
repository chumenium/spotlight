import 'dart:async';

import 'package:flutter/material.dart';

import '../models/search_history.dart';
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
  Timer? _searchDelayTimer;
  
  // サンプルデータ
  final List<SearchHistory> _searchHistory = List.generate(8, (index) => SearchHistory.sample(index));
  final List<SearchSuggestion> _allSuggestions = List.generate(10, (index) => SearchSuggestion.sample(index));
  List<SearchSuggestion> _filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    _filteredSuggestions = _allSuggestions;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDelayTimer?.cancel();
    _searchDelayTimer = null;
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
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

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
    });
    
    // 検索履歴に追加（実際のアプリでは永続化）
    final newHistory = SearchHistory(
      id: 'search_${DateTime.now().millisecondsSinceEpoch}',
      query: query,
      searchedAt: DateTime.now(),
      resultCount: '${(query.length * 10)}件',
    );
    
    setState(() {
      _searchHistory.insert(0, newHistory);
      if (_searchHistory.length > 20) {
        _searchHistory.removeLast();
      }
    });
    
    // 検索結果画面への遷移（仮実装）
    _searchDelayTimer?.cancel();
    _searchDelayTimer = Timer(const Duration(milliseconds: 500), () {
      _searchDelayTimer = null;
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
    });
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
          // 戻るボタン
          IconButton(
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                _searchController.clear();
                _searchFocusNode.unfocus();
              } else {
                // ホーム画面の投稿表示に戻る
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
          
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
          
          const SizedBox(width: 8),
          
          // 検索ボタン
          IconButton(
            onPressed: () => _performSearch(_searchController.text),
            icon: const Icon(
              Icons.search,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 検索履歴
          if (_searchHistory.isNotEmpty) ...[
            _buildSectionHeader('検索履歴'),
            _buildSearchHistory(),
            const SizedBox(height: 20),
          ],
          
          // おすすめ検索
          _buildSectionHeader('おすすめ検索'),
          _buildSuggestions(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
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