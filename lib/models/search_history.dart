/// 検索履歴モデル
class SearchHistory {
  final String id;
  final String query;
  final DateTime searchedAt;
  final String? resultCount;

  SearchHistory({
    required this.id,
    required this.query,
    required this.searchedAt,
    this.resultCount,
  });

  factory SearchHistory.fromJson(Map<String, dynamic> json) {
    return SearchHistory(
      id: json['id'] as String,
      query: json['query'] as String,
      searchedAt: DateTime.parse(json['searched_at'] as String),
      resultCount: json['result_count'] as String?,
    );
  }

  // サンプルデータ用（テスト・開発用）
  factory SearchHistory.sample(int index) {
    final queries = [
      'フラッター開発',
      'Dart言語',
      'モバイルアプリ',
      'UIデザイン',
      'Firebase',
      'バックエンド',
      'REST API',
      '認証システム',
    ];
    
    return SearchHistory(
      id: 'history_$index',
      query: queries[index % queries.length],
      searchedAt: DateTime.now().subtract(Duration(hours: index)),
      resultCount: '${(queries[index % queries.length].length * 10)}件',
    );
  }
}

/// 検索候補モデル
class SearchSuggestion {
  final String id;
  final String query;
  final String? description;
  final bool isTrending;

  SearchSuggestion({
    required this.id,
    required this.query,
    this.description,
    required this.isTrending,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      id: json['id'] as String? ?? json['query'],
      query: json['query'] as String,
      description: json['description'] as String?,
      isTrending: json['is_trending'] as bool? ?? false,
    );
  }

  // サンプルデータ用（テスト・開発用）
  factory SearchSuggestion.sample(int index) {
    final suggestions = [
      {'query': '話題の音楽', 'isTrending': true},
      {'query': '人気の映画', 'isTrending': true},
      {'query': '本日のスポットライト', 'isTrending': false},
      {'query': 'トレンド動画', 'isTrending': true},
      {'query': 'おすすめアーティスト', 'isTrending': false},
      {'query': '最新ニュース', 'isTrending': false},
      {'query': 'スポーツハイライト', 'isTrending': true},
      {'query': 'グルメ情報', 'isTrending': false},
      {'query': '旅行先', 'isTrending': false},
      {'query': 'テクノロジー', 'isTrending': true},
    ];
    
    final data = suggestions[index % suggestions.length];
    
    return SearchSuggestion(
      id: 'suggestion_$index',
      query: data['query'] as String,
      description: null,
      isTrending: data['isTrending'] as bool,
    );
  }
}

