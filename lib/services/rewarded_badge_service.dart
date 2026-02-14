import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'jwt_service.dart';

/// リワード広告バッジ関連API
class RewardedBadgeService {
  static int? _extractCount(dynamic data) {
    final direct = data['count'] ?? data['num'] ?? data['reward_ad_count'];
    final nestedData =
        data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : null;
    final nested = nestedData == null
        ? null
        : (nestedData['count'] ?? nestedData['num'] ?? nestedData['reward_ad_count']);
    final value = direct ?? nested;
    if (value == null) return null;
    return value is int ? value : int.tryParse(value.toString());
  }

  static Future<http.Response?> _postWithFallback({
    required String path,
    required String jwtToken,
    Map<String, dynamic>? jsonBody,
  }) async {
    final urls = <String>[
      '${AppConfig.backendUrl}$path',
      '${AppConfig.backendUrl}$path/',
    ];

    for (final url in urls) {
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: jsonBody == null ? null : jsonEncode(jsonBody),
        );
        if (response.statusCode == 404 || response.statusCode == 405) {
          continue;
        }
        return response;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// リワード広告の累計視聴回数を取得
  ///
  /// 期待レスポンス例:
  /// {"status":"success","count":12}
  /// {"status":"success","data":{"count":12}}
  static Future<int?> fetchRewardAdCount() async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) return null;

      final response = await _postWithFallback(
        path: '/api/users/getrewardadcount',
        jwtToken: jwtToken,
      );
      if (response == null || response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final status = data['status']?.toString().toLowerCase();
      if (status != 'success' && status != 'ok') return null;

      return _extractCount(data) ?? 0;
    } catch (e) {
      return null;
    }
  }

  /// リワード広告視聴を1回加算
  ///
  /// 期待レスポンス例:
  /// {"status":"success","count":13}
  /// {"status":"success","data":{"count":13}}
  static Future<RewardAdIncrementResult> incrementRewardAdCount() async {
    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        return const RewardAdIncrementResult(
          success: false,
          message: '認証情報が見つかりません',
        );
      }

      // 実装差分吸収:
      // 1) bodyなし
      // 2) bodyあり
      http.Response? response = await _postWithFallback(
        path: '/api/users/incrementrewardadcount',
        jwtToken: jwtToken,
      );
      response ??= await _postWithFallback(
        path: '/api/users/incrementrewardadcount',
        jwtToken: jwtToken,
        jsonBody: {'increment': 1},
      );
      if (response == null) {
        return const RewardAdIncrementResult(
          success: false,
          message: 'サーバーに接続できません',
        );
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        data = <String, dynamic>{
          'status': 'error',
          'message': response.body.isEmpty ? 'レスポンス形式が不正です' : response.body,
        };
      }

      if (response.statusCode == 429) {
        return RewardAdIncrementResult(
          success: false,
          rateLimited: true,
          message: data['message']?.toString() ?? 'リクエストが頻繁すぎます',
          count: _extractCount(data),
        );
      }

      final status = data['status']?.toString().toLowerCase();
      if (response.statusCode != 200 || (status != 'success' && status != 'ok')) {
        return RewardAdIncrementResult(
          success: false,
          message: data['message']?.toString() ??
              '視聴回数の更新に失敗しました (${response.statusCode})',
          count: _extractCount(data),
        );
      }

      final count = _extractCount(data);
      if (count == null) {
        final latest = await fetchRewardAdCount();
        return RewardAdIncrementResult(
          success: latest != null,
          count: latest,
          message: latest == null ? '最新回数の取得に失敗しました' : null,
        );
      }
      return RewardAdIncrementResult(success: true, count: count);
    } catch (e) {
      return const RewardAdIncrementResult(
        success: false,
        message: '通信エラーが発生しました',
      );
    }
  }
}

class RewardAdIncrementResult {
  const RewardAdIncrementResult({
    required this.success,
    this.count,
    this.message,
    this.rateLimited = false,
  });

  final bool success;
  final int? count;
  final String? message;
  final bool rateLimited;
}

