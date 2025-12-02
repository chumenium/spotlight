import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../config/app_config.dart';
import '../services/jwt_service.dart';

/// 通報結果
class ReportResult {
  final bool success;
  final String? errorMessage;

  ReportResult({required this.success, this.errorMessage});
}

/// 通報APIサービス
class ReportService {
  /// 通報を送信
  ///
  /// パラメータ:
  /// - type: 通報の種類 ("user", "content", "comment")
  /// - reason: 通報理由
  /// - detail: 通報の詳細な理由（オプション）
  /// - targetuidID: 通報対象のユーザーID（必須）
  /// - uid: typeが"user"の時に通報された側のuserID（オプション、targetuidIDと重複する場合は不要）
  /// - contentID: typeが"content"の時は該当contentID、typeが"comment"の時はコメントが投稿されているコンテンツのcontentID（オプション）
  /// - commentID: typeが"comment"の時該当するcommentID（オプション）
  /// - currentUserId: 現在のユーザーID（自分の投稿チェック用）
  ///
  /// 戻り値:
  /// - ReportResult: 通報送信結果（successとerrorMessageを含む）
  static Future<ReportResult> sendReport({
    required String type,
    required String reason,
    String? detail,
    String? targetuidID,
    String? uid,
    String? contentID,
    int? commentID,
    String? currentUserId,
  }) async {
    try {
      // 自分の投稿かどうかをチェック（contentタイプの場合）
      if (type == 'content' && targetuidID != null && currentUserId != null) {
        final targetUserIdStr = targetuidID.toString().trim();
        final currentUserIdStr = currentUserId.toString().trim();

        if (kDebugMode) {
          debugPrint('🚨 ReportService: 自分の投稿チェック');
          debugPrint('  currentUserId: "$currentUserIdStr"');
          debugPrint('  targetuidID: "$targetUserIdStr"');
          debugPrint('  一致: ${currentUserIdStr == targetUserIdStr}');
        }

        if (currentUserIdStr.isNotEmpty &&
            targetUserIdStr.isNotEmpty &&
            currentUserIdStr == targetUserIdStr) {
          if (kDebugMode) {
            debugPrint('🚨 ReportService: 自分の投稿への通報をブロックしました');
          }
          return ReportResult(
            success: false,
            errorMessage: '自分の投稿は通報できません',
          );
        }
      }

      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ 通報送信: JWTトークンが取得できません');
        }
        return ReportResult(
          success: false,
          errorMessage: 'ログインが必要です',
        );
      }

      final url = '${AppConfig.apiBaseUrl}/users/report';

      if (kDebugMode) {
        debugPrint('📢 通報送信URL: $url');
        debugPrint('📢 通報内容: type=$type, reason=$reason');
      }

      // リクエストボディを構築
      final Map<String, dynamic> body = {
        'type': type,
        'reason': reason,
      };

      // 必須フィールド: targetuidID
      if (targetuidID != null && targetuidID.isNotEmpty) {
        body['targetuidID'] = targetuidID;
      }

      // オプションフィールドを追加
      if (detail != null && detail.isNotEmpty) {
        body['detail'] = detail;
      }
      if (uid != null && uid.isNotEmpty) {
        body['uid'] = uid;
      }
      if (contentID != null && contentID.isNotEmpty) {
        body['contentID'] = contentID;
      }
      if (commentID != null) {
        body['commentID'] = commentID;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        debugPrint('📢 通報送信レスポンス: ${response.statusCode}');
        debugPrint('📢 レスポンス内容: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          if (kDebugMode) {
            debugPrint('✅ 通報送信成功');
          }
          return ReportResult(success: true);
        } else {
          final errorMessage = responseData['message']?.toString() ?? '不明なエラー';
          if (kDebugMode) {
            debugPrint('⚠️ 通報送信失敗: $errorMessage');
          }
          return ReportResult(
            success: false,
            errorMessage: errorMessage,
          );
        }
      } else {
        final responseData = jsonDecode(response.body);
        final errorMessage = responseData['message']?.toString() ??
            '通報の送信に失敗しました (${response.statusCode})';
        if (kDebugMode) {
          debugPrint('❌ 通報送信HTTPエラー: ${response.statusCode}');
          debugPrint('❌ エラーメッセージ: $errorMessage');
        }
        return ReportResult(
          success: false,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 通報送信エラー: $e');
      }
      return ReportResult(
        success: false,
        errorMessage: '通信エラーが発生しました',
      );
    }
  }
}
