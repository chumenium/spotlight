import 'dart:convert';
import 'package:http/http.dart' as http;
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
  /// - uid: typeが"user"の時に通報された側のuserID（type="user"の場合のみ必須）
  /// - contentID: typeが"content"の時は該当contentID、typeが"comment"の時はコメントが投稿されているコンテンツのcontentID
  /// - commentID: typeが"comment"の時該当するcommentID（type="comment"の場合のみ必須）
  /// - currentUserId: 現在のユーザーID（自分の投稿チェック用）
  /// - postUserId: 投稿のユーザーID（自分の投稿チェック用、type="content"の場合）
  /// - commentUserId: コメントのユーザーID（自分のコメントチェック用、type="comment"の場合）
  ///
  /// 戻り値:
  /// - ReportResult: 通報送信結果（successとerrorMessageを含む）
  static Future<ReportResult> sendReport({
    required String type,
    required String reason,
    String? detail,
    String? uid,
    String? contentID,
    int? commentID,
    String? currentUserId,
    String? postUserId,
    String? commentUserId,
  }) async {
    try {
      // 自分の投稿かどうかをチェック（contentタイプの場合）
      if (type == 'content' && postUserId != null && currentUserId != null) {
        final targetUserIdStr = postUserId.toString().trim();
        final currentUserIdStr = currentUserId.toString().trim();

        if (currentUserIdStr.isNotEmpty &&
            targetUserIdStr.isNotEmpty &&
            currentUserIdStr == targetUserIdStr) {
          return ReportResult(
            success: false,
            errorMessage: '自分の投稿は通報できません',
          );
        }
      }

      // 自分のコメントかどうかをチェック（commentタイプの場合）
      if (type == 'comment' && commentUserId != null && currentUserId != null) {
        final targetUserIdStr = commentUserId.toString().trim();
        final currentUserIdStr = currentUserId.toString().trim();

        if (currentUserIdStr.isNotEmpty &&
            targetUserIdStr.isNotEmpty &&
            currentUserIdStr == targetUserIdStr) {
          return ReportResult(
            success: false,
            errorMessage: '自分のコメントは通報できません',
          );
        }
      }

      // コメント通報の場合、commentIDとcontentIDが必須
      if (type == 'comment') {
        if (commentID == null) {
          return ReportResult(
            success: false,
            errorMessage: 'コメントIDが指定されていません',
          );
        }
        if (contentID == null || contentID.isEmpty) {
          return ReportResult(
            success: false,
            errorMessage: 'コンテンツIDが指定されていません',
          );
        }
      }

      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return ReportResult(
          success: false,
          errorMessage: 'ログインが必要です',
        );
      }

      final url = '${AppConfig.apiBaseUrl}/users/report';

      // リクエストボディを構築（API仕様に従う）
      final Map<String, dynamic> body = {
        'type': type,
        'reason': reason,
      };

      // オプションフィールドを追加（必要に応じて）
      if (detail != null && detail.isNotEmpty) {
        body['detail'] = detail;
      }

      // type="user"の場合のみuidを追加
      if (type == 'user' && uid != null && uid.isNotEmpty) {
        body['uid'] = uid;
      }

      // type="content"またはtype="comment"の場合、contentIDを追加
      if ((type == 'content' || type == 'comment') &&
          contentID != null &&
          contentID.isNotEmpty) {
        body['contentID'] = contentID;
      }

      // type="comment"の場合のみcommentIDを追加
      if (type == 'comment' && commentID != null) {
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

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return ReportResult(success: true);
        } else {
          final errorMessage = responseData['message']?.toString() ?? '不明なエラー';
          return ReportResult(
            success: false,
            errorMessage: errorMessage,
          );
        }
      } else {
        final responseData = jsonDecode(response.body);
        final errorMessage = responseData['message']?.toString() ??
            '通報の送信に失敗しました (${response.statusCode})';
        return ReportResult(
          success: false,
          errorMessage: errorMessage,
        );
      }
    } catch (e) {
      return ReportResult(
        success: false,
        errorMessage: '通信エラーが発生しました',
      );
    }
  }
}
