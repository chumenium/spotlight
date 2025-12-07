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
      resultCount: '${(index + 1) * 10}',
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
    this.isTrending = false,
  });

  // サンプルデータ用（テスト・開発用）
  factory SearchSuggestion.sample(int index) {
    final suggestions = [
      {'query': 'フラッター開発', 'description': 'モバイルアプリ開発', 'trending': true},
      {'query': 'Dart言語', 'description': 'プログラミング言語', 'trending': false},
      {'query': 'UIデザイン', 'description': 'ユーザーインターフェース', 'trending': true},
      {'query': 'Firebase', 'description': 'バックエンドサービス', 'trending': false},
      {'query': 'モバイルアプリ', 'description': 'スマートフォンアプリ', 'trending': true},
      {'query': 'REST API', 'description': 'API設計', 'trending': false},
      {'query': '認証システム', 'description': 'セキュリティ', 'trending': false},
      {'query': 'バックエンド', 'description': 'サーバーサイド', 'trending': true},
      {'query': 'データベース', 'description': 'データ管理', 'trending': false},
      {'query': 'クラウド', 'description': 'クラウドサービス', 'trending': true},
    ];

    final suggestion = suggestions[index % suggestions.length];
    return SearchSuggestion(
      id: 'suggestion_$index',
      query: suggestion['query'] as String,
      description: suggestion['description'] as String?,
      isTrending: suggestion['trending'] as bool,
    );
  }
}
