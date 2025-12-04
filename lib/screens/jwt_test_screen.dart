import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../services/jwt_service.dart';
import '../services/fcm_service.dart';
import '../config/app_config.dart';

/// JWTトークンテスト画面
/// 
/// Firebase IDトークンとFCMトークンをバックエンドサーバーに送信して
/// JWTトークンを取得するテストを行います
class JwtTestScreen extends StatefulWidget {
  const JwtTestScreen({super.key});

  @override
  State<JwtTestScreen> createState() => _JwtTestScreenState();
}

class _JwtTestScreenState extends State<JwtTestScreen> {
  String _statusMessage = 'テストを開始してください';
  bool _isLoading = false;
  Map<String, dynamic>? _lastResponse;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'JWTトークンテスト',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // サーバー情報
            _buildServerInfo(),
            
            const SizedBox(height: 20),
            
            // テストボタン
            _buildTestButton(),
            
            const SizedBox(height: 20),
            
            // ステータス表示
            _buildStatusDisplay(),
            
            const SizedBox(height: 20),
            
            // レスポンス表示
            if (_lastResponse != null) _buildResponseDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildServerInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'サーバー情報',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'バックエンドURL: ${AppConfig.backendUrl}',
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            'エンドポイント: /api/auth/firebase',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF6B35),
                const Color(0xFFFF8A65),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : () => _runTest(authProvider),
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'JWTトークン取得テスト',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ステータス',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'レスポンス',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatJson(_lastResponse!),
              style: const TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatJson(Map<String, dynamic> json) {
    // JSONを整形して表示
    final buffer = StringBuffer();
    _formatJsonRecursive(json, buffer, 0);
    return buffer.toString();
  }

  void _formatJsonRecursive(dynamic value, StringBuffer buffer, int indent) {
    if (value is Map<String, dynamic>) {
      buffer.writeln('{');
      value.forEach((key, val) {
        buffer.write('  ' * (indent + 1));
        buffer.write('"$key": ');
        _formatJsonRecursive(val, buffer, indent + 1);
        buffer.writeln(',');
      });
      buffer.write('  ' * indent);
      buffer.write('}');
    } else if (value is List) {
      buffer.writeln('[');
      for (int i = 0; i < value.length; i++) {
        buffer.write('  ' * (indent + 1));
        _formatJsonRecursive(value[i], buffer, indent + 1);
        if (i < value.length - 1) buffer.write(',');
        buffer.writeln();
      }
      buffer.write('  ' * indent);
      buffer.write(']');
    } else if (value is String) {
      buffer.write('"$value"');
    } else {
      buffer.write(value.toString());
    }
  }

  Future<void> _runTest(AuthProvider authProvider) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'テストを開始しています...';
      _lastResponse = null;
    });

    try {
      // 1. Firebase認証状態を確認
      if (!authProvider.isLoggedIn) {
        setState(() {
          _statusMessage = '❌ Firebase認証が必要です。まずログインしてください。';
        });
        return;
      }

      setState(() {
        _statusMessage = '✅ Firebase認証済み\n📤 トークンを送信中...';
      });

      // 2. FCMトークンを初期化（エラーが発生した場合は無効化）
      try {
        await FcmService.initializeNotifications();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('🔔 FCM初期化エラー（無効化）: $e');
        }
        FcmService.disableFcm();
      }

      // 3. バックエンドにトークンを送信
      final result = await authProvider.sendTokensToBackend();

      if (result != null) {
        setState(() {
          _statusMessage = '✅ テスト成功！\n🔑 JWTトークンを取得しました';
          _lastResponse = result;
        });

        if (kDebugMode) {
          debugPrint('🎉 JWTトークンテスト成功');
          debugPrint('📋 レスポンス: $result');
        }
      } else {
        setState(() {
          _statusMessage = '❌ テスト失敗\nサーバーとの通信に失敗しました';
        });

        if (kDebugMode) {
          debugPrint('❌ JWTトークンテスト失敗');
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ エラーが発生しました: $e';
      });

      if (kDebugMode) {
        debugPrint('❌ JWTトークンテストエラー: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
