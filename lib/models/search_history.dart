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

  // サンプルデータ生成用ファクトリ
  factory SearchHistory.sample(int index) {
    final queries = [
      'Flutter開発',
      'Dart言語',
      'モバイルアプリ',
      'UI/UXデザイン',
      'プログラミング',
      'Web開発',
      'React Native',
      'Swift開発',
      'Kotlin開発',
      'JavaScript',
    ];
    
    return SearchHistory(
      id: 'search_$index',
      query: queries[index % queries.length],
      searchedAt: DateTime.now().subtract(Duration(hours: index)),
      resultCount: '${(index + 1) * 10}件',
    );
  }
}

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

  // サンプルデータ生成用ファクトリ
  factory SearchSuggestion.sample(int index) {
    final suggestions = [
      {'query': 'Flutter開発', 'description': 'モバイルアプリ開発'},
      {'query': 'Dart言語', 'description': 'プログラミング言語'},
      {'query': 'UI/UXデザイン', 'description': 'デザイン手法'},
      {'query': 'モバイルアプリ', 'description': 'アプリケーション'},
      {'query': 'プログラミング', 'description': 'コーディング'},
      {'query': 'Web開発', 'description': 'ウェブサイト制作'},
      {'query': 'React Native', 'description': 'クロスプラットフォーム'},
      {'query': 'Swift開発', 'description': 'iOS開発'},
      {'query': 'Kotlin開発', 'description': 'Android開発'},
      {'query': 'JavaScript', 'description': 'Web言語'},
    ];
    
    final suggestion = suggestions[index % suggestions.length];
    
    return SearchSuggestion(
      id: 'suggestion_$index',
      query: suggestion['query']!,
      description: suggestion['description'],
      isTrending: index < 3, // 最初の3つをトレンドとして表示
    );
  }
}
