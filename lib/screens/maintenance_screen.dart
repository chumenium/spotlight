import 'package:flutter/material.dart';
import '../services/maintenance_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// メンテナンス画面
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  String _message = '現在メンテナンス中です。\nしばらくお待ちください。';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaintenanceMessage();
  }

  /// メンテナンスメッセージを読み込む
  Future<void> _loadMaintenanceMessage() async {
    try {
      final message = await MaintenanceService.getMaintenanceMessage();
      if (mounted) {
        setState(() {
          _message = message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ メンテナンスメッセージ読み込みエラー: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// メンテナンスモードをチェック（定期的にチェックして自動的に解除を検知）
  void _checkMaintenanceStatus() {
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      
      final isEnabled = await MaintenanceService.isMaintenanceModeEnabled();
      if (!isEnabled) {
        // メンテナンスモードが無効化された場合は、アプリを再起動
        if (kDebugMode) {
          debugPrint('✅ メンテナンスモードが解除されました');
        }
        // アプリを再起動するために、Navigatorでスプラッシュ画面に戻る
        Navigator.of(context).pushReplacementNamed('/');
      } else {
        // まだメンテナンスモードが有効な場合は、再度チェック
        _checkMaintenanceStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 定期的にメンテナンス状態をチェック
    _checkMaintenanceStatus();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // メンテナンスアイコン
                const Icon(
                  Icons.build,
                  size: 80,
                  color: Color(0xFFFF6B35),
                ),
                const SizedBox(height: 32),
                
                // タイトル
                const Text(
                  'メンテナンス中',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // メッセージ
                if (_isLoading)
                  const CircularProgressIndicator(
                    color: Color(0xFFFF6B35),
                  )
                else
                  Text(
                    _message,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 48),
                
                // リロードボタン（開発者向け）
                if (kDebugMode)
                  ElevatedButton.icon(
                    onPressed: () async {
                      // メンテナンスモードを再チェック
                      final isEnabled = await MaintenanceService.isMaintenanceModeEnabled();
                      if (!isEnabled) {
                        // メンテナンスモードが無効化された場合は、アプリを再起動
                        Navigator.of(context).pushReplacementNamed('/');
                      } else {
                        // まだメンテナンスモードが有効な場合は、メッセージを再読み込み
                        await _loadMaintenanceMessage();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('メンテナンスモードは継続中です'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('再チェック'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

