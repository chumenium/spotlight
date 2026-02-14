import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../utils/spotlight_colors.dart';
import '../widgets/blur_app_bar.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _targetUidController = TextEditingController();

  bool _sendToAll = false;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _targetUidController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (_isSending) return;

    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final targetUid =
        _sendToAll ? 'all' : _targetUidController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      setState(() {
        _errorMessage = 'タイトルと本文を入力してください';
      });
      return;
    }

    if (!_sendToAll && targetUid.isEmpty) {
      setState(() {
        _errorMessage = '送信対象のユーザーIDを入力してください';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final success = await AdminService.sendAdminNotification(
        title: title,
        message: message,
        targetUid: targetUid,
      );

      if (!mounted) return;

      if (success) {
        _titleController.clear();
        _messageController.clear();
        if (!_sendToAll) {
          _targetUidController.clear();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('通知を送信しました'),
            backgroundColor: SpotLightColors.primaryOrange,
          ),
        );
      } else {
        setState(() {
          _errorMessage = '通知の送信に失敗しました';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'エラーが発生しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: BlurAppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '管理者通知送信',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SpotLightColors.primaryOrange.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '送信設定',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _sendToAll,
                    onChanged: (value) {
                      setState(() {
                        _sendToAll = value;
                        _errorMessage = null;
                      });
                    },
                    activeColor: SpotLightColors.primaryOrange,
                    title: const Text(
                      '全員に送信',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _sendToAll
                          ? 'targetuid に "all" を送信します'
                          : '対象ユーザーIDを指定して送信します',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _titleController,
              label: 'タイトル',
              hint: '通知のタイトル',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _messageController,
              label: '本文',
              hint: '通知したい内容',
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _targetUidController,
              label: '送信対象ユーザーID',
              hint: 'ユーザーIDを入力',
              enabled: !_sendToAll,
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpotLightColors.primaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '送信',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
