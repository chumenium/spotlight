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
}
