import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
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
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return null;
      }

      // 管理者APIエンドポイント: /api/admin/getuser
      final url = '${AppConfig.backendUrl}/api/admin/getuser';

      if (kDebugMode) {
        debugPrint('👤 管理者API: 全ユーザー取得URL: $url');
        debugPrint('👤 管理者API: offset: $offset');
      }

      // リクエストボディにoffsetを指定（API仕様に合わせる）
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'offset': offset}),
      );

      if (kDebugMode) {
        debugPrint('👤 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('👤 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('👤 管理者API: レスポンスデータ: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success' &&
            responseData['userdatas'] != null) {
          final List<dynamic> userdatas = responseData['userdatas'];
          if (kDebugMode) {
            debugPrint('✅ 管理者API: ${userdatas.length}件のユーザーデータを取得');
          }
          return userdatas
              .map((user) => user as Map<String, dynamic>)
              .toList();
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: レスポンス形式が不正');
            debugPrint('  status: ${responseData['status']}');
            debugPrint('  message: ${responseData['message'] ?? 'なし'}');
            debugPrint('  userdatas存在: ${responseData['userdatas'] != null}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
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
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/enableadmin';

      if (kDebugMode) {
        debugPrint('👤 管理者API: 管理者権限有効化URL: $url');
        debugPrint('👤 管理者API: userID: $userID');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userID': userID}),
      );

      if (kDebugMode) {
        debugPrint('👤 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('👤 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          if (kDebugMode) {
            debugPrint('✅ 管理者API: 管理者権限を有効化しました');
          }
          return true;
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: ${responseData['message'] ?? 'エラー'}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
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
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/disableadmin';

      if (kDebugMode) {
        debugPrint('👤 管理者API: 管理者権限無効化URL: $url');
        debugPrint('👤 管理者API: userID: $userID');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userID': userID}),
      );

      if (kDebugMode) {
        debugPrint('👤 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('👤 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          if (kDebugMode) {
            debugPrint('✅ 管理者API: 管理者権限を無効化しました');
          }
          return true;
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: ${responseData['message'] ?? 'エラー'}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
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
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return null;
      }

      final url = '${AppConfig.backendUrl}/api/admin/report';

      if (kDebugMode) {
        debugPrint('📋 管理者API: 通報取得URL: $url');
        debugPrint('📋 管理者API: offset: $offset');
      }

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

      if (kDebugMode) {
        debugPrint('📋 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('📋 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('📋 管理者API: レスポンスデータ: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success') {
          // reportsがnullの場合は空のリストとして扱う
          final reports = responseData['reports'];
          if (reports != null && reports is List) {
            final List<dynamic> reportsList = reports;
            if (kDebugMode) {
              debugPrint('✅ 管理者API: ${reportsList.length}件の通報データを取得');
              // 最初の通報データのフィールドを確認
              if (reportsList.isNotEmpty) {
                final firstReport = reportsList[0] as Map<String, dynamic>;
                debugPrint('📋 通報データのフィールド: ${firstReport.keys.toList()}');
                debugPrint('📋 通報データの内容: $firstReport');
                debugPrint('📋 reasonフィールド: ${firstReport['reason']} (type: ${firstReport['reason']?.runtimeType})');
                debugPrint('📋 detailフィールド: ${firstReport['detail']} (type: ${firstReport['detail']?.runtimeType})');
              }
            }
            return reportsList
                .map((report) => report as Map<String, dynamic>)
                .toList();
          } else {
            // reportsがnullまたはリストでない場合は空のリストを返す
            if (kDebugMode) {
              debugPrint('⚠️ 管理者API: reportsがnullまたはリストではありません');
              debugPrint('  reportsの型: ${reports.runtimeType}');
              debugPrint('  空のリストを返します');
            }
            return [];
          }
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: レスポンス形式が不正');
            debugPrint('  status: ${responseData['status']}');
            debugPrint('  message: ${responseData['message'] ?? 'なし'}');
            debugPrint('  reports存在: ${responseData['reports'] != null}');
            debugPrint('  空のリストを返します');
          }
          // エラーでも空のリストを返す（nullではなく）
          return [];
        }
      } else if (response.statusCode == 400) {
        // 管理者以外からのアクセスなど
        final responseData = jsonDecode(response.body);
        if (kDebugMode) {
          debugPrint('❌ 管理者API: アクセス拒否 (400)');
          debugPrint('  message: ${responseData['message'] ?? '管理者以外からのアクセス'}');
        }
        return null;
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エンドポイントが見つかりません (404)');
          debugPrint('  通報管理APIエンドポイントが実装されていない可能性があります');
        }
        // 404の場合はnullを返して、画面側でエラーメッセージを表示
        return null;
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
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
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/processreport';

      if (kDebugMode) {
        debugPrint('📋 管理者API: 通報処理済みURL: $url');
        debugPrint('📋 管理者API: reportID: $reportID');
      }

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

      if (kDebugMode) {
        debugPrint('📋 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('📋 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          if (kDebugMode) {
            debugPrint('✅ 管理者API: 通報を処理済みにしました');
          }
          return true;
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: ${responseData['message'] ?? 'エラー'}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
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
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/unprocessreport';

      if (kDebugMode) {
        debugPrint('📋 管理者API: 通報未処理URL: $url');
        debugPrint('📋 管理者API: reportID: $reportID');
      }

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

      if (kDebugMode) {
        debugPrint('📋 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('📋 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          if (kDebugMode) {
            debugPrint('✅ 管理者API: 通報を未処理に戻しました');
          }
          return true;
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: ${responseData['message'] ?? 'エラー'}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
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
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/deletecontent';

      if (kDebugMode) {
        debugPrint('🗑️ 管理者API: コンテンツ削除URL: $url');
        debugPrint('🗑️ 管理者API: contentID: $contentID');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'contentID': contentID}),
      );

      if (kDebugMode) {
        debugPrint('🗑️ 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('🗑️ 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          if (kDebugMode) {
            debugPrint('✅ 管理者API: コンテンツを削除しました');
          }
          return true;
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: ${responseData['message'] ?? 'エラー'}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
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
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/admin/deletecomment';

      if (kDebugMode) {
        debugPrint('🗑️ 管理者API: コメント削除URL: $url');
        debugPrint('🗑️ 管理者API: contentID: $contentID, commentID: $commentID');
      }

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

      if (kDebugMode) {
        debugPrint('🗑️ 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('🗑️ 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          if (kDebugMode) {
            debugPrint('✅ 管理者API: コメントを削除しました');
          }
          return true;
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: ${responseData['message'] ?? 'エラー'}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
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
        if (kDebugMode) {
          debugPrint('❌ 管理者API: JWTトークンが取得できません');
        }
        return null;
      }

      final url = '${AppConfig.backendUrl}/api/admin/content';

      if (kDebugMode) {
        debugPrint('📋 管理者API: コンテンツ取得URL: $url');
        debugPrint('📋 管理者API: offset: $offset');
      }

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

      if (kDebugMode) {
        debugPrint('📋 管理者API: レスポンス statusCode=${response.statusCode}');
        debugPrint('📋 管理者API: レスポンス本文: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('📋 管理者API: レスポンスデータ: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success') {
          // contentsがnullの場合は空のリストとして扱う
          final contents = responseData['contents'];
          if (contents != null && contents is List) {
            final List<dynamic> contentsList = contents;
            if (kDebugMode) {
              debugPrint('✅ 管理者API: ${contentsList.length}件のコンテンツデータを取得');
              // 最初のコンテンツデータのフィールドを確認
              if (contentsList.isNotEmpty) {
                final firstContent = contentsList[0] as Map<String, dynamic>;
                debugPrint('📋 コンテンツデータのフィールド: ${firstContent.keys.toList()}');
              }
            }
            return contentsList
                .map((content) => content as Map<String, dynamic>)
                .toList();
          } else {
            // contentsがnullまたはリストでない場合は空のリストを返す
            if (kDebugMode) {
              debugPrint('⚠️ 管理者API: contentsがnullまたはリストではありません');
              debugPrint('  contentsの型: ${contents.runtimeType}');
              debugPrint('  空のリストを返します');
            }
            return [];
          }
        } else {
          if (kDebugMode) {
            debugPrint('❌ 管理者API: レスポンス形式が不正');
            debugPrint('  status: ${responseData['status']}');
            debugPrint('  message: ${responseData['message'] ?? 'なし'}');
            debugPrint('  contents存在: ${responseData['contents'] != null}');
            debugPrint('  空のリストを返します');
          }
          // エラーでも空のリストを返す（nullではなく）
          return [];
        }
      } else if (response.statusCode == 400) {
        // 管理者以外からのアクセスなど
        final responseData = jsonDecode(response.body);
        if (kDebugMode) {
          debugPrint('❌ 管理者API: アクセス拒否 (400)');
          debugPrint('  message: ${responseData['message'] ?? '管理者以外からのアクセス'}');
        }
        return null;
      } else if (response.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エンドポイントが見つかりません (404)');
          debugPrint('  コンテンツ管理APIエンドポイントが実装されていない可能性があります');
        }
        // 404の場合はnullを返して、画面側でエラーメッセージを表示
        return null;
      } else {
        if (kDebugMode) {
          debugPrint('❌ 管理者API: エラー statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API: 例外: $e');
      }
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
        if (kDebugMode) {
          debugPrint('❌ 管理者API(content2): JWTトークンが取得できません');
        }
        return null;
      }

      final url = '${AppConfig.backendUrl}/api/admin/content2';

      if (kDebugMode) {
        debugPrint('📋 管理者API(content2): コンテンツ取得URL: $url');
        debugPrint('📋 管理者API(content2): offset: $offset');
      }

      // API仕様: POSTでoffsetを送信する
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'offset': offset}),
      );

      if (kDebugMode) {
        debugPrint('📋 管理者API(content2): statusCode=${response.statusCode}');
        debugPrint('📋 管理者API(content2): body=${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          final contents = responseData['contents'];
          if (contents is List) {
            if (kDebugMode && contents.isNotEmpty) {
              final first = contents.first as Map<String, dynamic>;
              debugPrint('📋 content2 fields: ${first.keys.toList()}');
            }
            return contents
                .map((content) => content as Map<String, dynamic>)
                .toList();
          }
          // contentsがnullまたはリストでない場合は空リスト
          return [];
        }

        if (kDebugMode) {
          debugPrint(
              '❌ 管理者API(content2): status=${responseData['status']}, message=${responseData['message']}');
        }
      } else {
        if (kDebugMode) {
          debugPrint(
              '❌ 管理者API(content2): エラー statusCode=${response.statusCode}');
          debugPrint('  body: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 管理者API(content2): 例外: $e');
      }
    }

    return null;
  }
}

