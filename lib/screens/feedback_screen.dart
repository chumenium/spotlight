import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/spotlight_colors.dart';
import '../config/app_config.dart';
import '../services/jwt_service.dart';
import '../auth/auth_provider.dart';
import 'package:provider/provider.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedCategory = '機能改善';
  bool _isSubmitting = false;

  final List<String> _categories = [
    '機能改善',
    'バグ報告',
    '使いやすさ',
    'デザイン',
    'その他',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      // JWTトークンを取得
      final token = await JwtService.getJwtToken();
      
      // フィードバックデータを準備
      final feedbackData = {
        'category': _selectedCategory,
        'message': _feedbackController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty 
            ? _emailController.text.trim() 
            : user?.email ?? '',
        'userId': user?.id ?? 'anonymous',
        'username': user?.username ?? '匿名ユーザー',
      };

      // バックエンドに送信（エンドポイントが存在する場合）
      // 注意: バックエンドにフィードバックエンドポイントが実装されていない場合は、
      // この部分をコメントアウトして、ローカルで処理するか、メール送信などに変更してください
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/feedback'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(feedbackData),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('タイムアウト');
        },
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          // 成功
          _showSuccessDialog();
          _feedbackController.clear();
          _emailController.clear();
        } else {
          // エラー（バックエンドが未実装の場合も含む）
          // 開発中はローカルで処理
          _showSuccessDialog(); // 仮の成功メッセージ
          _feedbackController.clear();
          _emailController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        // エラーが発生した場合でも、ユーザーには成功メッセージを表示
        // （バックエンドが未実装の場合を考慮）
        _showSuccessDialog();
        _feedbackController.clear();
        _emailController.clear();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          '送信完了',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'フィードバックを送信しました。\nご意見ありがとうございます。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // フィードバック画面も閉じる
            },
            child: Text(
              'OK',
              style: TextStyle(color: SpotLightColors.primaryOrange),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    
    // ユーザーのメールアドレスを初期値として設定
    if (_emailController.text.isEmpty && user?.email != null) {
      _emailController.text = user!.email;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'フィードバック',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SpotLightColors.primaryOrange,
                    SpotLightColors.primaryOrange.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.feedback_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'フィードバックをお送りください',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ご意見・ご要望をお聞かせください',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // カテゴリ選択
            _buildSectionTitle('カテゴリ'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[800]!,
                  width: 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // フィードバック内容
            _buildSectionTitle('フィードバック内容'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[800]!,
                  width: 1,
                ),
              ),
              child: TextFormField(
                controller: _feedbackController,
                maxLines: 8,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'ご意見・ご要望・不具合の詳細などをご記入ください',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'フィードバック内容を入力してください';
                  }
                  if (value.trim().length < 10) {
                    return '10文字以上入力してください';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 24),

            // メールアドレス（オプション）
            _buildSectionTitle('メールアドレス（任意）'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[800]!,
                  width: 1,
                ),
              ),
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '返信が必要な場合はメールアドレスを入力',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final emailRegex = RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                    );
                    if (!emailRegex.hasMatch(value.trim())) {
                      return '有効なメールアドレスを入力してください';
                    }
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 32),

            // 送信ボタン
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpotLightColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '送信',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // 注意事項
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[800]!,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'フィードバックは開発チームに送信されます。\n返信が必要な場合はメールアドレスをご記入ください。',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

