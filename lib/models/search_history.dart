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

  factory SearchHistory.fromJson(dynamic json) {
    // API仕様: 検索履歴は文字列の配列として返される
    if (json is String) {
      return SearchHistory(
        id: json,
        query: json,
        searchedAt: DateTime.now(), // 履歴には日時情報がないため現在時刻を使用
        resultCount: null,
      );
    }
    
    // オブジェクト形式の場合
    if (json is Map<String, dynamic>) {
      return SearchHistory(
        id: json['id']?.toString() ?? json['query']?.toString() ?? '',
        query: json['query']?.toString() ?? json.toString(),
        searchedAt: json['searched_at'] != null 
            ? DateTime.tryParse(json['searched_at']) ?? DateTime.now()
            : DateTime.now(),
        resultCount: json['result_count']?.toString(),
      );
    }
    
    // フォールバック
    return SearchHistory(
      id: json.toString(),
      query: json.toString(),
      searchedAt: DateTime.now(),
      resultCount: null,
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

