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
    // API仕様: 検索履歴はオブジェクト配列 [{"serchID": 1, "query": "検索ワード"}, ...] で返される（直近順）
    if (json is String) {
      return SearchHistory(
        id: json,
        query: json,
        searchedAt: DateTime.now().toLocal(),
        resultCount: null,
      );
    }

    // オブジェクト形式（serchID, query）: 直近順で返るため serchID でソートキーを表現
    if (json is Map<String, dynamic>) {
      final serchId = json['serchID'];
      final query = json['query']?.toString() ?? '';
      final id = serchId?.toString() ?? json['id']?.toString() ?? query;
      // serchID が大きいほど直近 → searchedAt として扱いフロントのソートで直近が上になる
      final searchedAt = json['searched_at'] != null
          ? DateTime.tryParse(json['searched_at'])?.toLocal()
          : null;
      final orderTime = searchedAt ??
          (serchId != null
              ? DateTime.fromMillisecondsSinceEpoch(0).add(
                  Duration(
                    seconds: serchId is int
                        ? serchId
                        : (int.tryParse(serchId.toString()) ?? 0),
                  ),
                )
              : DateTime.now().toLocal());

      return SearchHistory(
        id: id,
        query: query,
        searchedAt: orderTime,
        resultCount: json['result_count']?.toString(),
      );
    }

    return SearchHistory(
      id: json.toString(),
      query: json.toString(),
      searchedAt: DateTime.now().toLocal(),
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
