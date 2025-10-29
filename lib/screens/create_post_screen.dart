import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
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
  
  // 画像・動画選択用
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedMedia;
  bool get _hasMedia => _selectedMedia != null || _selectedAudio != null;
  
  // 音声ファイル選択用
  PlatformFile? _selectedAudio;
  AudioPlayer? _audioPlayer;
  bool _isAudioPlaying = false;

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
    _audioPlayer?.dispose();
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
              
              // 選択済みメディア表示
              if (_selectedMedia != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildSelectedMediaPreview(),
                ),
              
              // 選択済み音声ファイル表示
              if (_selectedAudio != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildSelectedAudioPreview(),
                ),
              
              // 追加オプション
              Row(
                children: [
                  _buildOptionButton(
                    icon: Icons.image_outlined,
                    label: '写真',
                    onTap: () => _pickMedia(ImageSource.gallery, isVideo: false),
                  ),
                  const SizedBox(width: 16),
                  _buildOptionButton(
                    icon: Icons.videocam_outlined,
                    label: '動画',
                    onTap: () => _pickMedia(ImageSource.gallery, isVideo: true),
                  ),
                  const SizedBox(width: 16),
                  _buildOptionButton(
                    icon: Icons.audiotrack_outlined,
                    label: '音声',
                    onTap: _pickAudioFile,
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

  // メディア選択メソッド
  Future<void> _pickMedia(ImageSource source, {required bool isVideo}) async {
    try {
      final XFile? pickedFile = isVideo
          ? await _imagePicker.pickVideo(source: source)
          : await _imagePicker.pickImage(source: source);

      if (pickedFile != null) {
        setState(() {
          _selectedMedia = pickedFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('メディアの選択に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 選択済みメディアのプレビュー表示
  Widget _buildSelectedMediaPreview() {
    if (_selectedMedia == null) return const SizedBox.shrink();

    final isVideo = _selectedMedia!.path.toLowerCase().endsWith('.mp4') || 
                    _selectedMedia!.path.toLowerCase().endsWith('.mov') ||
                    _selectedMedia!.path.toLowerCase().endsWith('.avi') ||
                    _selectedMedia!.path.toLowerCase().endsWith('.mkv') ||
                    _selectedMedia!.path.toLowerCase().endsWith('.webm') ||
                    _selectedMedia!.mimeType?.startsWith('video/') == true;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isVideo
              ? Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(
                      Icons.video_file,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                )
              : Image.file(
                  File(_selectedMedia!.path),
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
        ),
        // 削除ボタン
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedMedia = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // 音声ファイル選択メソッド
  Future<void> _pickAudioFile() async {
    // プラットフォームチェック - Android端末のみ対応
    if (!Platform.isAndroid) {
      _showAudioFeatureDialog();
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'], // 音声ファイルのみ許可
        allowMultiple: false,
        dialogTitle: '音声ファイルを選択',
      );

      if (result != null && result.files.single.path != null) {
        // ファイルが有効な音声ファイルかチェック
        final filePath = result.files.single.path!;
        final fileExtension = filePath.toLowerCase().split('.').last;
        final validExtensions = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'];
        
        if (!validExtensions.contains(fileExtension)) {
          _showSnackBar(
            '音声ファイルのみ選択できます',
            Colors.red,
          );
          return;
        }

        // ファイルサイズチェック（50MB制限）
        final fileSize = File(filePath).lengthSync();
        if (fileSize > 50 * 1024 * 1024) {
          _showSnackBar(
            '音声ファイルが大きすぎます（50MB以下にしてください）',
            Colors.red,
          );
          return;
        }

        setState(() {
          _selectedAudio = result.files.single;
          _selectedMedia = null; // メディアファイルをクリア
        });
        
        // 音声プレイヤーを初期化
        _audioPlayer = AudioPlayer();
        try {
          await _audioPlayer!.setFilePath(_selectedAudio!.path!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('音声ファイルの読み込みに失敗しました: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('音声ファイルの選択に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 選択済み音声ファイルのプレビュー表示
  Widget _buildSelectedAudioPreview() {
    if (_selectedAudio == null) return const SizedBox.shrink();

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.audiotrack,
                    color: SpotLightColors.primaryOrange,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedAudio!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_selectedAudio!.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 再生コントロール
              Row(
                children: [
                  IconButton(
                    onPressed: _toggleAudioPlayback,
                    icon: Icon(
                      _isAudioPlaying ? Icons.pause : Icons.play_arrow,
                      color: SpotLightColors.primaryOrange,
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<Duration>(
                      stream: _audioPlayer?.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final duration = _audioPlayer?.duration ?? Duration.zero;
                        
                        return Column(
                          children: [
                            Slider(
                              value: duration.inMilliseconds > 0
                                  ? position.inMilliseconds / duration.inMilliseconds
                                  : 0.0,
                              onChanged: (value) {
                                if (_audioPlayer != null && duration.inMilliseconds > 0) {
                                  final newPosition = Duration(
                                    milliseconds: (value * duration.inMilliseconds).round(),
                                  );
                                  _audioPlayer!.seek(newPosition);
                                }
                              },
                              activeColor: SpotLightColors.primaryOrange,
                              inactiveColor: Colors.grey[600],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 削除ボタン
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              _audioPlayer?.stop();
              _audioPlayer?.dispose();
              setState(() {
                _selectedAudio = null;
                _audioPlayer = null;
                _isAudioPlaying = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // 音声の再生/停止を切り替え
  Future<void> _toggleAudioPlayback() async {
    if (_audioPlayer == null) return;

    try {
      if (_isAudioPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.play();
      }
      
      // 再生状態のリスナーを追加
      _audioPlayer!.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isAudioPlaying = state.playing;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('音声の再生に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // 時間表示用のフォーマット
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // 音声機能ダイアログ（非Android端末用）
  void _showAudioFeatureDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.mic, color: Color(0xFFFF6B35)),
            SizedBox(width: 8),
            Text(
              '音声機能',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Android端末でのみ利用可能です！',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              '対応フォーマット:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildFeatureItem('🎵 MP3'),
            _buildFeatureItem('🎵 M4A'),
            _buildFeatureItem('🎵 AAC'),
            _buildFeatureItem('🎵 WAV'),
            _buildFeatureItem('🎵 OGG'),
            _buildFeatureItem('🎵 FLAC'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '了解',
              style: TextStyle(color: Color(0xFFFF6B35)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '• $text',
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  // スナックバー表示ヘルパー
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
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
