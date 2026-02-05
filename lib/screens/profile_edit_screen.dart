import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/spotlight_colors.dart';
import '../auth/auth_provider.dart';
import '../services/jwt_service.dart';
import '../config/app_config.dart';
import '../widgets/center_popup.dart';
import '../widgets/blur_app_bar.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final TextEditingController _bioController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  // 自己紹介の候補文
  final List<String> _bioTemplates = [
    '音楽が好きです',
    '動画制作をしています',
    '写真を撮るのが趣味です',
    'アートに興味があります',
    'クリエイターを目指しています',
    '新しいことに挑戦するのが好きです',
    '表現活動を楽しんでいます',
    '創作活動をしています',
    'アーティストです',
    'コンテンツ制作をしています',
    'クリエイティブな活動が好きです',
    '作品を作るのが好きです',
    '表現することが好きです',
    'アート作品を制作しています',
    'クリエイティブなことに興味があります',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentBio();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  /// 現在の自己紹介文を取得
  Future<void> _loadCurrentBio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        setState(() {
          _errorMessage = '認証が必要です';
          _isLoading = false;
        });
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        setState(() {
          _errorMessage = 'ユーザー情報が取得できませんでした';
          _isLoading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/users/getusername'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'firebase_uid': userId,
        }),
      );

        if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final userData = responseData['data'] as Map<String, dynamic>;
          final bio = userData['bio'] as String?;
          
          setState(() {
            _bioController.text = bio ?? '';
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 自己紹介文取得エラー: $e');
      }
      setState(() {
        _errorMessage = '自己紹介文の取得に失敗しました';
        _isLoading = false;
      });
    }
  }

  /// 自己紹介文を保存
  Future<void> _saveBio() async {
    if (_isSaving) return;

    final bio = _bioController.text.trim();
    
    // 文字数制限（200文字）
    if (bio.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('自己紹介文は200文字以内で入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final jwtToken = await JwtService.getJwtToken();
      if (jwtToken == null) {
        setState(() {
          _errorMessage = '認証が必要です';
          _isSaving = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/users/updatebio'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bio': bio,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          if (mounted) {
            CenterPopup.show(context, '自己紹介文を保存しました');
            Navigator.of(context).pop(true); // 保存成功を通知
          }
        } else {
          setState(() {
            _errorMessage = responseData['message'] ?? '保存に失敗しました';
            _isSaving = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = '保存に失敗しました';
          _isSaving = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 自己紹介文保存エラー: $e');
      }
      setState(() {
        _errorMessage = '保存に失敗しました: $e';
        _isSaving = false;
      });
    }
  }

  /// 候補文を選択
  void _selectTemplate(String template) {
    setState(() {
      _bioController.text = template;
    });
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
          'プロフィール編集',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveBio,
              child: const Text(
                '保存',
                style: TextStyle(
                  color: SpotLightColors.primaryOrange,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: SpotLightColors.primaryOrange,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // エラーメッセージ
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 自己紹介文入力
                  const Text(
                    '自己紹介',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'あなたについて簡単に紹介してください（200文字以内）',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bioController,
                    maxLength: 200,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '自己紹介文を入力してください',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: SpotLightColors.primaryOrange,
                          width: 2,
                        ),
                      ),
                      counterStyle: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 候補文セクション
                  const Text(
                    '候補から選ぶ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _bioTemplates.map((template) {
                      return GestureDetector(
                        onTap: () => _selectTemplate(template),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey[700]!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            template,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

