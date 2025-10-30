import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:flutter/rendering.dart';
import '../utils/spotlight_colors.dart';

// テキストオーバーレイ用のモデル
class TextOverlay {
  String text;
  Offset position;
  bool isFocused;
  TextEditingController controller;
  FocusNode focusNode;
  String id;
  double width;

  TextOverlay({
    required this.text,
    required this.position,
    this.isFocused = false,
    required this.controller,
    required this.focusNode,
    required this.id,
    this.width = 220,
  });

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  bool _isPosting = false;
  
  // 背景メディア選択用（写真または動画）
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedMedia;
  
  // テキストオーバーレイ管理
  final List<TextOverlay> _textOverlays = [];
  String? _selectedOverlayId;
  
  // 音声ファイル選択用
  PlatformFile? _selectedAudio;
  AudioPlayer? _audioPlayer;
  bool _isAudioPlaying = false;
  
  // 動画プレイヤー
  VideoPlayerController? _videoPlayerController;
  bool _isVideoPlaying = false;

  // 画像+テキスト合成用
  final GlobalKey _compositeKey = GlobalKey();
  Uint8List? _compositedImageBytes;

  @override
  void initState() {
    super.initState();
    
    // タイトル文字数カウンターをリアルタイム更新
    _titleController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var overlay in _textOverlays) {
      overlay.dispose();
    }
    _textOverlays.clear();
    _audioPlayer?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _postContent() async {
    // タイトルチェック
    if (_titleController.text.trim().isEmpty) {
      _showSnackBar('タイトルを入力してください', Colors.red);
      return;
    }

    // コンテンツチェック（写真/動画/音声のいずれかが必要）
    if (_selectedMedia == null && _selectedAudio == null) {
      _showSnackBar('写真、動画、または音声を選択してください', Colors.red);
      return;
    }

    // 画像 + テキストの場合は合成して単一の画像にする
    if (_selectedMedia != null && !_isSelectedMediaVideo() && _textOverlays.isNotEmpty) {
      final bytes = await _exportCompositeImage();
      if (bytes != null) {
        _compositedImageBytes = bytes; // このPNGが投稿用の単一画像になります
      } else {
        _showSnackBar('画像の合成に失敗しました', Colors.red);
        return;
      }
    } else {
      _compositedImageBytes = null;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      // コンテンツタイプ判定
      final String type = _selectedMedia != null
          ? (_isSelectedMediaVideo() ? 'video' : 'image')
          : (_selectedAudio != null ? 'audio' : 'text');

      // backend要件: file(base64), thumbnail(base64) 必須
      String? fileBase64;
      String? thumbBase64;

      if (type == 'image') {
        final Uint8List imageBytes = _compositedImageBytes ?? await File(_selectedMedia!.path).readAsBytes();
        fileBase64 = base64Encode(imageBytes);
        thumbBase64 = base64Encode(await _generateImageThumbnail(imageBytes));
      } else if (type == 'video') {
        final bytes = await File(_selectedMedia!.path).readAsBytes();
        fileBase64 = base64Encode(bytes);
        thumbBase64 = base64Encode(_generatePlaceholderThumbnail(320, 180, label: 'VIDEO'));
      } else if (type == 'audio') {
        final bytes = await File(_selectedAudio!.path!).readAsBytes();
        fileBase64 = base64Encode(bytes);
        thumbBase64 = base64Encode(_generatePlaceholderThumbnail(320, 320, label: 'AUDIO'));
      } else {
        _showSnackBar('このバックエンドではテキスト単体投稿は未対応です', Colors.red);
        return;
      }

      String? link;
      if (_selectedMedia != null) {
        link = _selectedMedia!.path;
      } else if (_selectedAudio != null) {
        link = _selectedAudio!.path;
      }

      final result = await PostService.createPost(
        type: type,
        title: _titleController.text.trim(),
        fileBase64: fileBase64,
        thumbnailBase64: thumbBase64,
        link: link,
      );
      
      if (mounted) {
        if (result == null) {
          _showSnackBar('投稿に失敗しました（無効な応答）', Colors.red);
          return;
        }
        _showSnackBar('投稿が完了しました！', Colors.green);
        _titleController.clear();
        setState(() {
          _selectedMedia = null;
          _videoPlayerController?.dispose();
          _videoPlayerController = null;
          _isVideoPlaying = false;
          _audioPlayer?.stop();
          _audioPlayer?.dispose();
          _audioPlayer = null;
          _selectedAudio = null;
          _isAudioPlaying = false;
          for (var overlay in _textOverlays) {
            overlay.dispose();
          }
          _textOverlays.clear();
        });
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

  // 画像のJPEGサムネイル生成
  Future<Uint8List> _generateImageThumbnail(Uint8List sourceBytes) async {
    final img.Image? decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return Uint8List(0);
    // 320x320 へ収まるよう縮小
    final resized = img.copyResize(decoded, width: 320, height: 320, fit: img.Interpolation.average);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }

  // 動画/音声の簡易サムネイル（プレースホルダ）
  Uint8List _generatePlaceholderThumbnail(int width, int height, {required String label}) {
    final canvas = img.Image(width: width, height: height);
    img.fill(canvas, img.ColorRgb8(30, 30, 30));
    img.drawRect(canvas, x1: 0, y1: height - 6, x2: width, y2: height, color: img.ColorRgb8(255, 107, 53));
    img.drawStringCentered(canvas, img.arial_24, label, color: img.ColorRgb8(255, 255, 255));
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 85));
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル入力セクション
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'タイトル',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: '投稿のタイトルを入力',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
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
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${_titleController.text.length}/100',
                        style: TextStyle(
                          color: _titleController.text.length > 100 
                              ? Colors.red 
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 背景メディアプレビューエリア
            Expanded(
              child: _selectedMedia == null && _selectedAudio == null
                  ? _buildMediaSelectionPrompt()
                  : _selectedMedia != null
                      ? _buildMediaPreviewWithOverlays()
                      : _buildAudioPreview(),
            ),
            
            // 選択済み音声ファイル表示（背景メディアがある場合は下に表示）
            if (_selectedAudio != null)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                child: _buildSelectedAudioPreview(),
              ),
            
            // メディア選択ボタン
            if (_selectedMedia == null && _selectedAudio == null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildOptionButton(
                        icon: Icons.image_outlined,
                        label: '写真',
                        onTap: () => _pickMedia(ImageSource.gallery, isVideo: false),
                      ),
                      const SizedBox(width: 12),
                      _buildOptionButton(
                        icon: Icons.videocam_outlined,
                        label: '動画',
                        onTap: () => _pickMedia(ImageSource.gallery, isVideo: true),
                      ),
                      const SizedBox(width: 12),
                      _buildOptionButton(
                        icon: Icons.audiotrack_outlined,
                        label: '音声',
                        onTap: _pickAudioFile,
                      ),
                    ],
                  ),
                ),
              )
            else if (_selectedMedia != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildOptionButton(
                        icon: Icons.edit_outlined,
                        label: '背景を変更',
                        onTap: () => _showMediaSelectionDialog(),
                      ),
                      // 画像の場合のみテキスト追加ボタンを表示
                      if (!_isSelectedMediaVideo()) ...[
                        const SizedBox(width: 12),
                        _buildOptionButton(
                          icon: Icons.text_fields,
                          label: 'テキストを追加',
                          onTap: () => _addTextOverlay(Offset(
                            MediaQuery.of(context).size.width / 2 - 75,
                            MediaQuery.of(context).size.height / 3,
                          )),
                        ),
                      ],
                      const SizedBox(width: 12),
                      _buildOptionButton(
                        icon: Icons.audiotrack_outlined,
                        label: '音声に変更',
                        onTap: _pickAudioFile,
                      ),
                    ],
                  ),
                ),
              )
            else if (_selectedAudio != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildOptionButton(
                        icon: Icons.image_outlined,
                        label: '写真を追加',
                        onTap: () => _pickMedia(ImageSource.gallery, isVideo: false),
                      ),
                      const SizedBox(width: 12),
                      _buildOptionButton(
                        icon: Icons.videocam_outlined,
                        label: '動画を追加',
                        onTap: () => _pickMedia(ImageSource.gallery, isVideo: true),
                      ),
                      const SizedBox(width: 12),
                      _buildOptionButton(
                        icon: Icons.edit_outlined,
                        label: '音声に変更',
                        onTap: _pickAudioFile,
                      ),
                    ],
                  ),
                ),
              ),
          ],
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

  // メディア選択プロンプト表示
  Widget _buildMediaSelectionPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            '写真、動画、または音声を選択してください',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '写真・動画は背景として、音声は添付として使用されます',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 音声のみ選択時のプレビュー表示
  Widget _buildAudioPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audiotrack,
            size: 80,
            color: SpotLightColors.primaryOrange,
          ),
          const SizedBox(height: 16),
          Text(
            '音声ファイルが選択されています',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '写真または動画も追加できます',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // 選択されたメディアが動画かどうかを判定
  bool _isSelectedMediaVideo() {
    if (_selectedMedia == null) return false;
    
    final path = _selectedMedia!.path.toLowerCase();
    final isVideo = path.endsWith('.mp4') || 
                    path.endsWith('.mov') ||
                    path.endsWith('.avi') ||
                    path.endsWith('.mkv') ||
                    path.endsWith('.webm') ||
                    _selectedMedia!.mimeType?.startsWith('video/') == true;
    
    return isVideo;
  }

  // メディアプレビューとテキストオーバーレイ表示
  Widget _buildMediaPreviewWithOverlays() {
    final isVideo = _isSelectedMediaVideo();

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          // 画像の場合のみタップでテキストオーバーレイを追加
          onTapUp: isVideo ? null : (details) {
            // テキストオーバーレイをタップしていない場合は追加
            final tappedOverlay = _textOverlays.where((overlay) {
              final overlayRect = Rect.fromLTWH(
                overlay.position.dx,
                overlay.position.dy,
                300,
                100,
              );
              return overlayRect.contains(details.localPosition);
            }).firstOrNull;

            if (tappedOverlay == null) {
              // 背景をタップした位置にテキストオーバーレイを追加
              _addTextOverlay(details.localPosition);
            }
          },
          child: RepaintBoundary(
            key: _compositeKey,
            child: Stack(
              children: [
                // 背景メディア
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isVideo
                      ? _buildVideoPreview()
                      : Image.file(
                          File(_selectedMedia!.path),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                        ),
                ),
                // テキストオーバーレイ（画像の場合のみ表示）
                if (!isVideo)
                  ..._textOverlays.map((overlay) => _buildTextOverlayWidget(overlay)),
                // ヒント（タップでテキスト追加 - 画像の場合のみ）
                if (!isVideo && _textOverlays.isEmpty)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '画面をタップしてテキストを追加',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 合成画像をPNGでエクスポート
  Future<Uint8List?> _exportCompositeImage() async {
    try {
      final boundary = _compositeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // テキストオーバーレイウィジェット
  Widget _buildTextOverlayWidget(TextOverlay overlay) {
    return Positioned(
      left: (() {
        final maxLeft = (MediaQuery.of(context).size.width - overlay.width);
        final safeMaxLeft = maxLeft.isFinite && maxLeft > 0 ? maxLeft : 0.0;
        return overlay.position.dx.clamp(0.0, safeMaxLeft) as double;
      })(),
      top: (() {
        final maxTop = (MediaQuery.of(context).size.height - 200);
        final safeMaxTop = maxTop.isFinite && maxTop > 0 ? maxTop : 0.0;
        return overlay.position.dy.clamp(0.0, safeMaxTop) as double;
      })(),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedOverlayId = overlay.id;
            overlay.isFocused = true;
          });
          overlay.focusNode.requestFocus();
        },
        onPanUpdate: (details) {
          setState(() {
            final maxLeft = (MediaQuery.of(context).size.width - overlay.width);
            final safeMaxLeft = maxLeft.isFinite && maxLeft > 0 ? maxLeft : 0.0;
            final nextLeft = (overlay.position.dx + details.delta.dx)
                .clamp(0.0, safeMaxLeft) as double;

            final maxTop = (MediaQuery.of(context).size.height - 200);
            final safeMaxTop = maxTop.isFinite && maxTop > 0 ? maxTop : 0.0;
            final nextTop = (overlay.position.dy + details.delta.dy)
                .clamp(0.0, safeMaxTop) as double;

            overlay.position = Offset(nextLeft, nextTop);
          });
        },
        child: Container(
          width: overlay.width,
          constraints: const BoxConstraints(
            minWidth: 120,
            maxWidth: 360,
          ),
          decoration: BoxDecoration(
            color: overlay.isFocused ? Colors.white.withOpacity(0.95) : Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
            border: overlay.isFocused
                ? Border.all(color: SpotLightColors.primaryOrange, width: 2)
                : null,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: overlay.controller,
                  focusNode: overlay.focusNode,
                  style: TextStyle(
                    color: overlay.isFocused ? Colors.black : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'テキストを入力',
                    hintStyle: TextStyle(
                      color: overlay.isFocused ? Colors.grey[600] : Colors.grey[400],
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  onChanged: (text) {
                    overlay.text = text;
                  },
                ),
              ),
              // 削除ボタン
              if (overlay.isFocused)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        overlay.dispose();
                        _textOverlays.remove(overlay);
                        if (_selectedOverlayId == overlay.id) {
                          _selectedOverlayId = null;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              // リサイズハンドル（右下）
              if (overlay.isFocused)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        final newWidth = (overlay.width + details.delta.dx).clamp(120.0, 360.0) as double;
                        overlay.width = newWidth;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white70, width: 1),
                      ),
                      child: const Icon(
                        Icons.open_in_full,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // テキストオーバーレイを追加
  void _addTextOverlay(Offset position) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final controller = TextEditingController();
    final focusNode = FocusNode();
    
    focusNode.addListener(() {
      setState(() {
        final overlay = _textOverlays.firstWhere((o) => o.id == id);
        overlay.isFocused = focusNode.hasFocus;
        if (focusNode.hasFocus) {
          _selectedOverlayId = id;
        } else if (_selectedOverlayId == id) {
          _selectedOverlayId = null;
        }
      });
    });

    final overlay = TextOverlay(
      text: '',
      position: position,
      controller: controller,
      focusNode: focusNode,
      id: id,
    );

    setState(() {
      _textOverlays.add(overlay);
      _selectedOverlayId = id;
      overlay.isFocused = true;
    });

    // フォーカスをリクエスト
    Future.delayed(const Duration(milliseconds: 100), () {
      focusNode.requestFocus();
    });
  }

  // メディア選択ダイアログ
  void _showMediaSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          '背景を変更',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined, color: Color(0xFFFF6B35)),
              title: const Text(
                '写真を選択',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: Color(0xFFFF6B35)),
              title: const Text(
                '動画を選択',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, isVideo: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  // メディア選択メソッド
  Future<void> _pickMedia(ImageSource source, {required bool isVideo}) async {
    // 既に音声が選択されている場合は警告
    if (_selectedAudio != null) {
      final shouldReplace = await _showContentConflictDialog(
        '音声ファイルが既に選択されています',
        '写真/動画を選択するため、現在の音声ファイルは削除されます。続行しますか？',
      );
      if (shouldReplace != true) {
        return;
      }
      // 音声をクリア
      _audioPlayer?.stop();
      _audioPlayer?.dispose();
      setState(() {
        _selectedAudio = null;
        _audioPlayer = null;
        _isAudioPlaying = false;
      });
    }

    try {
      final XFile? pickedFile = isVideo
          ? await _imagePicker.pickVideo(source: source)
          : await _imagePicker.pickImage(source: source);

      if (pickedFile != null) {
        // 既存の動画プレイヤーをクリア
        _videoPlayerController?.dispose();
        _videoPlayerController = null;
        _isVideoPlaying = false;

        setState(() {
          _selectedMedia = pickedFile;
          // 動画を選択した場合は既存のテキストオーバーレイをクリア
          if (isVideo) {
            for (var overlay in _textOverlays) {
              overlay.dispose();
            }
            _textOverlays.clear();
            _selectedOverlayId = null;
          }
        });

        // 動画の場合はプレイヤーを初期化
        if (isVideo) {
          _videoPlayerController = VideoPlayerController.file(File(pickedFile.path));
          await _videoPlayerController!.initialize();
          // 動画プレイヤーの状態変更を監視
          _videoPlayerController!.addListener(() {
            if (mounted) {
              setState(() {
                _isVideoPlaying = _videoPlayerController!.value.isPlaying;
              });
            }
          });
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('メディアの選択に失敗しました: $e', Colors.red);
      }
    }
  }

  // 音声ファイル選択メソッド
  Future<void> _pickAudioFile() async {
    // プラットフォームチェック - Android端末のみ対応
    if (!Platform.isAndroid) {
      _showAudioFeatureDialog();
      return;
    }

    // 既にメディアが選択されている場合は警告
    if (_selectedMedia != null) {
      final shouldReplace = await _showContentConflictDialog(
        '写真/動画が既に選択されています',
        '音声ファイルを選択するため、現在の写真/動画は削除されます。続行しますか？',
      );
      if (shouldReplace != true) {
        return;
      }
      // メディアをクリア
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
      _isVideoPlaying = false;
      for (var overlay in _textOverlays) {
        overlay.dispose();
      }
      setState(() {
        _selectedMedia = null;
        _textOverlays.clear();
        _selectedOverlayId = null;
      });
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'],
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
        });
        
        // 音声プレイヤーを初期化
        _audioPlayer?.dispose();
        _audioPlayer = AudioPlayer();
        try {
          await _audioPlayer!.setFilePath(_selectedAudio!.path!);
        } catch (e) {
          if (mounted) {
            _showSnackBar('音声ファイルの読み込みに失敗しました: $e', Colors.red);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('音声ファイルの選択に失敗しました: $e', Colors.red);
      }
    }
  }

  // 選択済み音声ファイルのプレビュー表示
  Widget _buildSelectedAudioPreview() {
    if (_selectedAudio == null) return const SizedBox.shrink();

    return Container(
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
              // 削除ボタン
              GestureDetector(
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
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
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
        _showSnackBar('音声の再生に失敗しました: $e', Colors.red);
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

  // 動画プレビュー表示
  Widget _buildVideoPreview() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[900],
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoPlayerController!.value.size.width,
              height: _videoPlayerController!.value.size.height,
              child: VideoPlayer(_videoPlayerController!),
            ),
          ),
        ),
        // 再生/一時停止ボタン
        GestureDetector(
          onTap: _toggleVideoPlayback,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isVideoPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ],
    );
  }

  // 動画の再生/一時停止を切り替え
  void _toggleVideoPlayback() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return;
    }

    if (_videoPlayerController!.value.isPlaying) {
      _videoPlayerController!.pause();
    } else {
      _videoPlayerController!.play();
    }
    // 状態はリスナーで自動更新される
  }

  // コンテンツコンフリクトダイアログ
  Future<bool?> _showContentConflictDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              '続行',
              style: TextStyle(
                color: SpotLightColors.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
