import 'package:flutter/material.dart';
import '../utils/spotlight_colors.dart';

// CreatePostModalは後でインポート時に使用

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    // 画面表示時に自動的にキーボードを表示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    
    // 文字数カウンターをリアルタイム更新
    _textController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _postContent() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('投稿内容を入力してください'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      // TODO: 実際の投稿処理を実装
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('投稿が完了しました！'),
            backgroundColor: Colors.green,
          ),
        );
        _textController.clear();
        // モーダルを閉じる
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('投稿に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: const Text(
          '新しい投稿',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _postContent,
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                    ),
                  )
                : Text(
                    '投稿',
                    style: TextStyle(
                      color: SpotLightColors.primaryOrange,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ユーザー情報セクション
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: SpotLightColors.primaryOrange,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'あなた',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '今すぐ投稿',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // テキスト入力エリア
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: '今何を考えていますか？\n\nあなたの考えや体験を共有してください...',
                    hintStyle: TextStyle(
                      color: Colors.grey,
                      fontSize: 18,
                      height: 1.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 文字数カウンター
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${_textController.text.length}/500',
                    style: TextStyle(
                      color: _textController.text.length > 500 
                          ? Colors.red 
                          : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 追加オプション
              Row(
                children: [
                  _buildOptionButton(
                    icon: Icons.image_outlined,
                    label: '写真',
                    onTap: () {
                      // TODO: 画像選択機能を実装
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('画像機能は準備中です'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildOptionButton(
                    icon: Icons.videocam_outlined,
                    label: '動画',
                    onTap: () {
                      // TODO: 動画選択機能を実装
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('動画機能は準備中です'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildOptionButton(
                    icon: Icons.location_on_outlined,
                    label: '位置情報',
                    onTap: () {
                      // TODO: 位置情報機能を実装
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('位置情報機能は準備中です'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: SpotLightColors.primaryOrange,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// モーダル表示用のラッパーウィジェット
class CreatePostModal extends StatelessWidget {
  const CreatePostModal({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Stack(
            children: [
              const CreatePostScreen(),
              // ドラッグハンドル
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
