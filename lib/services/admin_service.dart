import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/jwt_service.dart';

/// 管理者用APIサービス
class AdminService {
  /// 全ユーザーデータを取得
  ///
  /// パラメータ:
  /// - offset: 取得開始位置（デフォルト: 0、300件ずつ取得）
  ///
  /// 戻り値:
  /// - List<Map<String, dynamic>>?: ユーザーデータのリスト、失敗時はnull
  static Future<List<Map<String, dynamic>>?> getAllUsers({int offset = 0}) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return null;
      }

      // 管理者APIエンドポイント: /api/admin/getuser
      final url = '${AppConfig.backendUrl}/api/admin/getuser';

      // リクエストボディにoffsetを指定（API仕様に合わせる）
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'offset': offset}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success' &&
            responseData['userdatas'] != null) {
          final List<dynamic> userdatas = responseData['userdatas'];
          return userdatas
              .map((user) => user as Map<String, dynamic>)
              .toList();
        }
      }
    } catch (e) {
      // ignore
    }

    return null;
  }

  /// 管理者権限を有効化
  ///
  /// パラメータ:
  /// - userID: 管理者にしたいユーザーのuserID
  ///
  /// 戻り値:
  /// - bool: 成功時true、失敗時false
  static Future<bool> enableAdmin(String userID) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/enableadmin';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userID': userID}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return true;
        }
      }
    } catch (e) {
      // ignore
    }

    return false;
  }

  /// 管理者権限を無効化
  ///
  /// パラメータ:
  /// - userID: 一般ユーザーにしたいユーザーのuserID
  ///
  /// 戻り値:
  /// - bool: 成功時true、失敗時false
  static Future<bool> disableAdmin(String userID) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/disableadmin';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userID': userID}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return true;
        }
      }
    } catch (e) {
      // ignore
    }

    return false;
  }

  /// 通報一覧を取得
  ///
  /// パラメータ:
  /// - offset: 取得開始位置（デフォルト: 0）
  ///
  /// 戻り値:
  /// - List<Map<String, dynamic>>?: 通報データのリスト、失敗時はnull
  ///
  /// 注意: バックエンドAPIは`offset`パラメータのみを受け取ります。
  /// バックエンドのレスポンスには以下のフィールドが含まれます:
  /// - reportID: 通報のID
  /// - reporttype: 通報の種類("user","content","comment")
  /// - reportuidID: 通報したユーザーのID
  /// - username: 通報したユーザーの名前
  /// - targetuidID: 通報されたユーザーのID
  /// - targetusername: 通報されたユーザーの名前
  /// - contentID: 通報されたコンテンツのID
  /// - comCTID: 通報されたコメントのコンテンツID
  /// - comCMID: 通報されたコメントのコメントID
  /// - commenttext: コメントテキスト
  /// - title: 通報されたコンテンツのタイトル
  /// - processflag: 通報の処理状態(False: 未処理, True: 処理済み)
  /// - reason: 通報の理由
  /// - detail: 通報の詳細（nullの可能性あり）
  /// - reporttimestamp: 通報の時間
  static Future<List<Map<String, dynamic>>?> getReports({
    int offset = 0,
  }) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return null;
      }

      final url = '${AppConfig.backendUrl}/api/admin/report';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'offset': offset,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          // reportsがnullの場合は空のリストとして扱う
          final reports = responseData['reports'];
          if (reports != null && reports is List) {
            final List<dynamic> reportsList = reports;
            return reportsList
                .map((report) => report as Map<String, dynamic>)
                .toList();
          } else {
            // reportsがnullまたはリストでない場合は空のリストを返す
            return [];
          }
        } else {
          // エラーでも空のリストを返す（nullではなく）
          return [];
        }
      } else if (response.statusCode == 400) {
        // 管理者以外からのアクセスなど
        return null;
      } else if (response.statusCode == 404) {
        // 404の場合はnullを返して、画面側でエラーメッセージを表示
        return null;
      }
    } catch (e) {
      // ignore
    }

    return null;
  }

  /// 通報を処理済みにする
  ///
  /// パラメータ:
  /// - reportID: 処理する通報のID
  ///
  /// 戻り値:
  /// - bool: 成功時true、失敗時false
  static Future<bool> processReport({
    required String reportID,
  }) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/processreport';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reportID': reportID,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return true;
        }
      }
    } catch (e) {
      // ignore
    }

    return false;
  }

  /// 通報を未処理に戻す
  ///
  /// パラメータ:
  /// - reportID: 未処理に戻す通報のID
  ///
  /// 戻り値:
  /// - bool: 成功時true、失敗時false
  static Future<bool> unprocessReport({
    required String reportID,
  }) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/unprocessreport';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reportID': reportID,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return true;
        }
      }
    } catch (e) {
      // ignore
    }

    return false;
  }

  /// コンテンツを削除（管理者用）
  ///
  /// パラメータ:
  /// - contentID: 削除するコンテンツのID
  ///
  /// 戻り値:
  /// - bool: 成功時true、失敗時false
  static Future<bool> deleteContent(String contentID) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/deletecontent';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'contentID': contentID}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return true;
        }
      }
    } catch (e) {
      // ignore
    }

    return false;
  }

  /// コメントを削除（管理者用）
  ///
  /// パラメータ:
  /// - contentID: コメントが属するコンテンツのID
  /// - commentID: 削除するコメントのID
  ///
  /// 戻り値:
  /// - bool: 成功時true、失敗時false
  static Future<bool> deleteComment(String contentID, String commentID) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/deletecomment';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contentID': contentID,
          'commentID': commentID,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return true;
        }
      }
    } catch (e) {
      // ignore
    }

    return false;
  }

  /// 管理者通知を送信
  ///
  /// パラメータ:
  /// - title: 通知タイトル
  /// - message: 通知本文
  /// - targetUid: 送信対象ユーザーID（全員の場合は "all"）
  ///
  /// 戻り値:
  /// - bool: 成功時true、失敗時false
  static Future<bool> sendAdminNotification({
    required String title,
    required String message,
    required String targetUid,
  }) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/adminnotification';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'message': message,
          'targetuid': targetUid,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          return true;
        }
      }
    } catch (e) {
      // ignore
    }

    return false;
  }

  /// 全コンテンツ情報を取得（管理者用）
  ///
  /// パラメータ:
  /// - offset: 取得開始位置（デフォルト: 0、300件ずつ取得）
  ///
  /// 戻り値:
  /// - List<Map<String, dynamic>>?: コンテンツデータのリスト、失敗時はnull
  static Future<List<Map<String, dynamic>>?> getAllContents({
    int offset = 0,
  }) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return null;
      }

      final url = '${AppConfig.backendUrl}/api/admin/content';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'offset': offset,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          // contentsがnullの場合は空のリストとして扱う
          final contents = responseData['contents'];
          if (contents != null && contents is List) {
            final List<dynamic> contentsList = contents;
            return contentsList
                .map((content) => content as Map<String, dynamic>)
                .toList();
          } else {
            // contentsがnullまたはリストでない場合は空のリストを返す
            return [];
          }
        } else {
          // エラーでも空のリストを返す（nullではなく）
          return [];
        }
      } else if (response.statusCode == 400) {
        // 管理者以外からのアクセスなど
        return null;
      } else if (response.statusCode == 404) {
        // 404の場合はnullを返して、画面側でエラーメッセージを表示
        return null;
      }
    } catch (e) {
      // ignore
    }

    return null;
  }

  /// 全コンテンツ情報を取得（/api/admin/content2 を使用）
  ///
  /// パラメータ:
  /// - offset: 取得開始位置（デフォルト: 0、300件ずつ取得）
  ///
  /// 戻り値:
  /// - List<Map<String, dynamic>>?: コンテンツデータのリスト、失敗時はnull
  static Future<List<Map<String, dynamic>>?> getAllContentsV2({
    int offset = 0,
  }) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        return null;
      }

      final url = '${AppConfig.backendUrl}/api/admin/content2';

      // API仕様: POSTでoffsetを送信する
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'offset': offset}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          final contents = responseData['contents'];
          if (contents is List) {
            return contents
                .map((content) => content as Map<String, dynamic>)
                .toList();
          }
          // contentsがnullまたはリストでない場合は空リスト
          return [];
        }
      }
    } catch (e) {
      // ignore
    }

    return null;
  }
}

