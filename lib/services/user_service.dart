import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import '../config/app_config.dart';
import '../services/jwt_service.dart';

// Webプラットフォームではdart:ioのFileが使えないため、条件付きインポート
import 'dart:io' if (dart.library.html) 'dart:html' as io;
// Android/iOS用のdart:ioのFile（Webではコンパイルされないが、型チェック用に必要）
import 'dart:io' as dart_io show File;
// Web用のFileReader（Webでのみ使用、条件付きインポート）
import 'dart:html' if (dart.library.io) 'html_stub.dart' as html
    show FileReader;

/// キャッシュされたユーザー情報
class _CachedUserInfo {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  _CachedUserInfo(this.data, this.timestamp);

  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inHours >= 1; // 1時間以上経過したら期限切れ
  }
}

/// ユーザーAPIサービス
class UserService {
  /// アイコン画像を変更（アップロード）
  ///
  /// パラメータ:
  /// - username: バックエンドで生成された一意で変更不可なusername（必須）
  /// - imageFile: アップロードする画像ファイル（WebではUint8Listも受け入れる）
  ///
  /// リクエスト:
  /// - username: ユーザー名（必須）
  /// - iconimg: base64エンコードした画像データ
  ///
  /// レスポンス:
  /// - iconimgpath: バックエンドで生成されたアイコンパス（username_icon.png形式）
  ///
  /// 戻り値:
  /// - String?: アップロード成功時のアイコンパス（iconimgpath）、失敗時はnull
  static Future<String?> uploadIcon(String username, dynamic imageFile) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ JWTトークンが取得できません');
        }
        return null;
      }

      // 画像をbase64にエンコード
      List<int> imageBytes;
      if (kIsWeb) {
        // Webプラットフォーム: imageFileはUint8Listまたはhtml.File
        if (imageFile is List<int>) {
          imageBytes = imageFile;
        } else if (imageFile is Uint8List) {
          imageBytes = imageFile.toList();
        } else {
          // html.Fileの場合、FileReaderを使用
          final file = imageFile as io.File;
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file as dynamic); // html.FileはBlobのサブタイプ
          await reader.onLoadEnd.first;
          final arrayBuffer = reader.result;
          if (arrayBuffer != null && arrayBuffer is ByteBuffer) {
            imageBytes = Uint8List.view(arrayBuffer);
          } else {
            throw Exception('ファイルの読み込みに失敗しました');
          }
        }
      } else {
        // Android/iOS: imageFileはdart:ioのFileまたはUint8List
        if (imageFile is Uint8List) {
          imageBytes = imageFile.toList();
        } else if (imageFile is List<int>) {
          imageBytes = imageFile;
        } else {
          // dart:ioのFileの場合
          final file = imageFile as dart_io.File;
          imageBytes = await file.readAsBytes();
        }
      }

      final base64Image = base64Encode(imageBytes);

      final url = '${AppConfig.backendUrl}/api/users/changeicon';

      if (kDebugMode) {
        debugPrint('📤 アイコン変更URL: $url');
        debugPrint('📤 username: $username');
        debugPrint('📤 base64画像サイズ: ${base64Image.length} 文字');
        debugPrint(
            '📤 base64画像プレビュー: ${base64Image.substring(0, base64Image.length > 50 ? 50 : base64Image.length)}...');
      }

      // リクエストボディを構築
      final requestData = <String, dynamic>{
        'username': username,
        'iconimg': base64Image,
      };

      if (kDebugMode) {
        debugPrint('📤 送信データ確認:');
        debugPrint('  - username: ${requestData['username']}');
        debugPrint('  - iconimg存在: ${requestData['iconimg'] != null}');
        debugPrint('  - iconimgサイズ: ${requestData['iconimg']?.length ?? 0}');
        debugPrint(
            '  - iconimg先頭50文字: ${requestData['iconimg']?.substring(0, 50) ?? 'null'}...');
      }

      final jsonBody = jsonEncode(requestData);

      if (kDebugMode) {
        debugPrint('📤 JSON化後のbodyサイズ: ${jsonBody.length}');
        debugPrint(
            '📤 JSON化後のbody（最初の300文字）: ${jsonBody.substring(0, jsonBody.length > 300 ? 300 : jsonBody.length)}...');

        // JSONが正しく構築されているかチェック
        try {
          final decoded = jsonDecode(jsonBody);
          debugPrint('📤 JSON検証: デコード成功');
          debugPrint('  - デコード後username: ${decoded['username']}');
          debugPrint('  - デコード後iconimg存在: ${decoded['iconimg'] != null}');
          debugPrint('  - デコード後iconimgサイズ: ${decoded['iconimg']?.length ?? 0}');
        } catch (e) {
          debugPrint('❌ JSON検証エラー: $e');
        }
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonBody,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('📥 アイコンアップロードレスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success') {
          // レスポンス構造: dataオブジェクト内、または直接iconimgpathが返される
          String? iconPath;

          if (responseData['data'] != null &&
              responseData['data']['iconimgpath'] != null) {
            iconPath = responseData['data']['iconimgpath'] as String?;
          } else if (responseData['iconimgpath'] != null) {
            iconPath = responseData['iconimgpath'] as String?;
          }

          // パスの形式を確認して処理
          if (iconPath != null) {
            // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
            if (iconPath.startsWith('http://') ||
                iconPath.startsWith('https://')) {
              if (kDebugMode) {
                debugPrint('✅ アイコンパス取得（完全なURL）: $iconPath');
              }
              // 完全なURLの場合はそのまま返す（CloudFront URLなど）
              return iconPath;
            }
            // 相対パス（/icon/で始まる）の場合はファイル名のみを抽出
            else if (iconPath.startsWith('/icon/')) {
              iconPath = iconPath.substring('/icon/'.length);
            }
          }

          if (kDebugMode) {
            debugPrint('✅ アイコンパス取得: $iconPath');
          }

          // アイコン変更後はキャッシュをクリア（次回取得時に最新情報を取得するため）
          // 注意: firebaseUidは取得できないため、すべてのキャッシュをクリア
          clearAllUserInfoCache();

          return iconPath;
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ アイコン変更エラー: ${response.statusCode}');
          debugPrint('レスポンス: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ アイコン変更例外: $e');
      }
    }

    return null;
  }

  /// アイコンを削除
  ///
  /// パラメータ:
  /// - username: バックエンドで生成された一意で変更不可なusername（必須）
  ///
  /// リクエスト:
  /// - username: ユーザー名（必須）
  /// - iconimgは送信しない（削除を意味する）
  ///
  /// レスポンス:
  /// - iconimgpathは空になる、またはデフォルトアイコンのパス
  ///
  /// 戻り値:
  /// - bool: 削除成功の場合true
  static Future<bool> deleteIcon(String username) async {
    try {
      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ JWTトークンが取得できません');
        }
        return false;
      }

      final url = '${AppConfig.backendUrl}/api/users/changeicon';

      if (kDebugMode) {
        debugPrint('🗑️ アイコン削除URL: $url');
        debugPrint('🗑️ username: $username');
      }

      // 削除時はiconimgを送信しない
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('📥 アイコン削除レスポンス: ${responseData.toString()}');
        }

        final success = responseData['status'] == 'success';

        // アイコン削除後はキャッシュをクリア（次回取得時に最新情報を取得するため）
        if (success) {
          clearAllUserInfoCache();
        }

        return success;
      } else {
        if (kDebugMode) {
          debugPrint('❌ アイコン削除エラー: ${response.statusCode}');
          debugPrint('レスポンス: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ アイコン削除例外: $e');
      }
    }

    return false;
  }

  // ユーザー情報のキャッシュ（firebaseUid -> {data, timestamp}）
  static final Map<String, _CachedUserInfo> _userInfoCache = {};

  /// ユーザー情報を再取得
  ///
  /// アイコン更新後にユーザー情報を再取得してAuthProviderを更新するために使用
  /// キャッシュ機能付き: 1時間以内の取得はキャッシュから返す
  ///
  /// パラメータ:
  /// - firebaseUid: Firebase UID（ユーザー識別用）
  /// - forceRefresh: trueの場合、キャッシュを無視して強制的に再取得
  ///
  /// 戻り値:
  /// - Map<String, dynamic>?: ユーザー情報（username, iconimgpath）、失敗時はnull
  static Future<Map<String, dynamic>?> refreshUserInfo(String firebaseUid,
      {bool forceRefresh = false}) async {
    try {
      // キャッシュをチェック（強制更新でない場合）
      if (!forceRefresh && _userInfoCache.containsKey(firebaseUid)) {
        final cached = _userInfoCache[firebaseUid]!;
        if (!cached.isExpired) {
          if (kDebugMode) {
            debugPrint('📥 ユーザー情報をキャッシュから取得: $firebaseUid');
            debugPrint('   - キャッシュ時刻: ${cached.timestamp}');
            debugPrint(
                '   - 経過時間: ${DateTime.now().difference(cached.timestamp).inMinutes}分');
          }
          return cached.data;
        } else {
          if (kDebugMode) {
            debugPrint('📥 ユーザー情報のキャッシュが期限切れ: $firebaseUid');
          }
          _userInfoCache.remove(firebaseUid);
        }
      }

      final jwtToken = await JwtService.getJwtToken();

      if (jwtToken == null) {
        if (kDebugMode) {
          debugPrint('❌ JWTトークンが取得できません');
        }
        return null;
      }

      if (kDebugMode) {
        debugPrint('📥 ユーザー情報をAPIから取得: $firebaseUid');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/users/getusername'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'firebase_uid': firebaseUid,
        }),
      );

      if (kDebugMode) {
        debugPrint('📥 ユーザー情報APIレスポンス: statusCode=${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('📥 ユーザー情報再取得レスポンス: ${responseData.toString()}');
        }

        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final userInfo = responseData['data'] as Map<String, dynamic>;
          
          if (kDebugMode) {
            debugPrint('📥 ユーザー情報抽出:');
            debugPrint('  username: ${userInfo['username']}');
            debugPrint('  iconimgpath: ${userInfo['iconimgpath']}');
            debugPrint('  admin: ${userInfo['admin']}');
          }

          // キャッシュに保存
          _userInfoCache[firebaseUid] = _CachedUserInfo(
            userInfo,
            DateTime.now(),
          );

          if (kDebugMode) {
            debugPrint('📥 ユーザー情報をキャッシュに保存: $firebaseUid');
          }

          return userInfo;
        } else {
          if (kDebugMode) {
            debugPrint('❌ ユーザー情報レスポンス形式が不正:');
            debugPrint('  status: ${responseData['status']}');
            debugPrint('  data: ${responseData['data']}');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ ユーザー情報取得失敗: statusCode=${response.statusCode}');
          debugPrint('  レスポンス本文: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ ユーザー情報再取得例外: $e');
      }
    }

    return null;
  }

  /// ユーザー情報のキャッシュをクリア
  ///
  /// アイコン変更後など、キャッシュを無効化する必要がある場合に呼び出す
  static void clearUserInfoCache(String firebaseUid) {
    _userInfoCache.remove(firebaseUid);
    if (kDebugMode) {
      debugPrint('🗑️ ユーザー情報のキャッシュをクリア: $firebaseUid');
    }
  }

  /// すべてのユーザー情報キャッシュをクリア
  static void clearAllUserInfoCache() {
    _userInfoCache.clear();
    if (kDebugMode) {
      debugPrint('🗑️ すべてのユーザー情報キャッシュをクリア');
    }
  }
}
