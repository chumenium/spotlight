import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_compress/video_compress.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io' show File, Directory, Platform;
import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
// Web版で使用するHTML API（モバイルビルドでは使用しないためコメントアウト）
// import 'dart:html' as html
//     show VideoElement, CanvasElement, Blob, Url, FileReader;
import '../utils/spotlight_colors.dart';
import '../services/post_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _titleMaxLength = 100;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  bool _isPosting = false;

  // 背景メディア選択用（写真または動画）
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedMedia;

  // 音声ファイル選択用
  PlatformFile? _selectedAudio;
  AudioPlayer? _audioPlayer;
  bool _isAudioPlaying = false;

  // 動画プレイヤー
  VideoPlayerController? _videoPlayerController;
  bool _isVideoPlaying = false;
  VoidCallback? _videoPlayerListener;

  @override
  void initState() {
    super.initState();

    // タイトル文字数カウンターをリアルタイム更新
    _titleController.addListener(() {
      setState(() {});
    });
    _tagController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    _audioPlayer?.dispose();
    // 動画プレイヤーのクリーンアップ
    _cleanupVideoPlayer();
    super.dispose();
  }

  // 動画プレイヤーのクリーンアップ（再利用可能）
  void _cleanupVideoPlayer() {
    if (_videoPlayerController != null) {
      final controller = _videoPlayerController;
      _videoPlayerController = null; // 先にnullにして、他の処理が参照しないようにする
      _isVideoPlaying = false;

      try {
        if (controller != null) {
          // リスナーを削除（先に削除してから他の操作を行う）
          if (_videoPlayerListener != null) {
            try {
              if (controller.value.isInitialized) {
                controller.removeListener(_videoPlayerListener!);
              }
            } catch (e) {
              // エラーは無視
            }
            _videoPlayerListener = null;
          }

          // 再生中の場合、停止
          try {
            if (controller.value.isInitialized) {
              if (controller.value.isPlaying) {
                controller.pause();
              }
              // seekTo(0)でフレームバッファをリセット
              controller.seekTo(Duration.zero);
            }
          } catch (e) {
            // エラーは無視（既にdisposeされている可能性がある）
          }

          // dispose（同期的に実行）
          try {
            controller.dispose();
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ 動画プレイヤーdisposeエラー: $e');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ 動画プレイヤークリーンアップエラー: $e');
        }
      }
    }
  }

  Future<void> _postContent() async {
    // 投稿ボタンを押した時点で即座にキーボードを閉じる
    // （特に動画コンテンツなど投稿に時間がかかる場合に重要）
    FocusScope.of(context).unfocus();

    final titleText = _titleController.text.trim();
    // タグは空文字列の場合はnullを送信（バックエンド側のNoneTypeエラーを防ぐため）
    final tagText = _tagController.text.trim();
    final tagValue = tagText.isEmpty ? null : tagText;

    // タイトルチェック
    if (titleText.isEmpty) {
      _showSnackBar('タイトルを入力してください', Colors.red);
      return;
    }

    // コンテンツチェック（写真/動画/音声のいずれかが必要）
    if (_selectedMedia == null && _selectedAudio == null) {
      _showSnackBar('写真、動画、または音声を選択してください', Colors.red);
      return;
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
        // 画像ファイルの処理
        Uint8List imageBytes;
        int imageFileSize;

        if (kIsWeb) {
          // Web版: XFileから直接読み取る（Web版では圧縮をスキップ）
          imageBytes = await _selectedMedia!.readAsBytes();
          imageFileSize = imageBytes.length;
        } else {
          // モバイル版: 画像を圧縮してファイルサイズを抑える
          final originalImageBytes = await _selectedMedia!.readAsBytes();
          final originalImageSize = originalImageBytes.length;

          if (kDebugMode) {
            debugPrint(
                '🖼️ 元の画像ファイルサイズ: ${(originalImageSize / 1024 / 1024).toStringAsFixed(2)} MB');
          }

          try {
            // 画像を圧縮
            if (kDebugMode) {
              debugPrint('🖼️ 画像を圧縮中...');
            }

            // 一時ファイルとして保存
            final tempDir = Directory.systemTemp;
            final tempFile = File(
                '${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await tempFile.writeAsBytes(originalImageBytes);

            // 画像を圧縮（品質85%、最大幅1920px）
            final compressedFile =
                await FlutterImageCompress.compressAndGetFile(
              tempFile.absolute.path,
              '${tempDir.path}/compressed_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
              quality: 85, // 品質85%（バランス重視）
              minWidth: 1920, // 最大幅1920px
              minHeight: 1920, // 最大高さ1920px
            );

            if (compressedFile == null) {
              throw Exception('画像の圧縮に失敗しました');
            }

            imageBytes = await compressedFile.readAsBytes();
            imageFileSize = imageBytes.length;

            if (kDebugMode) {
              final compressionRatio =
                  (1 - imageFileSize / originalImageSize) * 100;
              debugPrint(
                  '🖼️ 圧縮後の画像ファイルサイズ: ${(imageFileSize / 1024 / 1024).toStringAsFixed(2)} MB');
              debugPrint('🖼️ 圧縮率: ${compressionRatio.toStringAsFixed(1)}%');
            }

            // 一時ファイルを削除
            try {
              await tempFile.delete();
              // XFileをFileに変換して削除
              final compressedFileObj = File(compressedFile.path);
              await compressedFileObj.delete();
              if (kDebugMode) {
                debugPrint('🖼️ 一時ファイルを削除しました');
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('⚠️ 一時ファイル削除エラー: $e');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ 画像圧縮エラー: $e');
              debugPrint('   元の画像ファイルを使用します');
            }
            // 圧縮に失敗した場合は元のファイルを使用
            imageFileSize = originalImageSize;
            imageBytes = originalImageBytes;
          }
        }

        if (kDebugMode) {
          debugPrint(
              '🖼️ 最終画像ファイルサイズ: ${(imageFileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        }

        // 50MB以上の画像をブロック
        const maxImageSize = 50 * 1024 * 1024; // 50MB

        if (imageFileSize > maxImageSize) {
          if (mounted) {
            final fileSizeMB = (imageFileSize / 1024 / 1024).toStringAsFixed(2);
            _showSnackBar(
              '画像ファイルが大きすぎます（${fileSizeMB}MB）。50MB以下の画像を選択してください。',
              Colors.red,
            );
          }
          setState(() {
            _isPosting = false;
          });
          return;
        }

        fileBase64 = base64Encode(imageBytes);
        thumbBase64 = base64Encode(await _generateImageThumbnail(imageBytes));
      } else if (type == 'video') {
        // 動画ファイルの処理
        Uint8List bytes;
        int videoFileSize;
        String? videoPath; // 圧縮後の動画パス（モバイル版用）

        if (kIsWeb) {
          // Web版: XFileから直接読み取る（Web版では圧縮をスキップ）
          bytes = await _selectedMedia!.readAsBytes();
          videoFileSize = bytes.length;
        } else {
          // モバイル版: 動画を圧縮してビットレートを抑える
          final originalVideoFile = File(_selectedMedia!.path);
          final originalVideoSize = await originalVideoFile.length();

          if (kDebugMode) {
            debugPrint(
                '📹 元の動画ファイルサイズ: ${(originalVideoSize / 1024 / 1024).toStringAsFixed(2)} MB');
          }

          try {
            // 動画を圧縮（ビットレートを2Mbpsに設定）
            if (kDebugMode) {
              debugPrint('📹 動画を圧縮中...');
            }

            final compressedVideo = await VideoCompress.compressVideo(
              _selectedMedia!.path,
              quality: VideoQuality.MediumQuality, // 中品質（ビットレート約2Mbps）
              deleteOrigin: false, // 元のファイルは削除しない
              includeAudio: true, // 音声を含める
            );

            if (compressedVideo == null || compressedVideo.path == null) {
              throw Exception('動画の圧縮に失敗しました');
            }

            videoPath = compressedVideo.path!;
            final compressedVideoFile = File(videoPath);
            videoFileSize = await compressedVideoFile.length();

            if (kDebugMode) {
              final compressionRatio =
                  (1 - videoFileSize / originalVideoSize) * 100;
              debugPrint(
                  '📹 圧縮後の動画ファイルサイズ: ${(videoFileSize / 1024 / 1024).toStringAsFixed(2)} MB');
              debugPrint('📹 圧縮率: ${compressionRatio.toStringAsFixed(1)}%');
            }

            // 圧縮後のファイルを読み込む（サムネイル生成前に読み込む）
            bytes = await compressedVideoFile.readAsBytes();
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ 動画圧縮エラー: $e');
              debugPrint('   元の動画ファイルを使用します');
            }
            // 圧縮に失敗した場合は元のファイルを使用
            videoFileSize = originalVideoSize;
            bytes = await originalVideoFile.readAsBytes();
          }
        }

        if (kDebugMode) {
          debugPrint(
              '📹 最終動画ファイルサイズ: ${(videoFileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        }

        // 120MB以上の動画をブロック
        const maxVideoSize = 120 * 1024 * 1024; // 120MB

        if (videoFileSize > maxVideoSize) {
          if (mounted) {
            final fileSizeMB = (videoFileSize / 1024 / 1024).toStringAsFixed(2);
            _showSnackBar(
              '動画ファイルが大きすぎます（${fileSizeMB}MB）。120MB以下の動画を選択してください。',
              Colors.red,
            );
          }
          setState(() {
            _isPosting = false;
          });
          return;
        }

        // ファイルを読み込んでbase64エンコード
        fileBase64 = base64Encode(bytes);

        if (kDebugMode) {
          debugPrint(
              '📹 最終ファイルサイズ: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
          debugPrint(
              '📹 最終base64サイズ: ${(fileBase64.length / 1024 / 1024).toStringAsFixed(2)} MB');
        }

        // 動画から最初のフレームをサムネイルとして抽出
        // サムネイル生成は圧縮後のファイルが存在する間に行う必要がある
        if (kIsWeb) {
          // Web版: HTML5 Video API + Canvas APIを使用
          try {
            if (kDebugMode) {
              debugPrint('🎬 Web版: 動画からサムネイルを生成中...');
            }
            final thumbnailBytes = await _generateVideoThumbnailWeb(bytes);
            if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
              thumbBase64 = base64Encode(thumbnailBytes);
              if (kDebugMode) {
                debugPrint('✅ Web版: 動画から最初のフレームをサムネイルとして抽出成功');
                debugPrint(
                    '   - サムネイルサイズ: ${thumbnailBytes.length} bytes (${(thumbnailBytes.length / 1024).toStringAsFixed(2)} KB)');
                debugPrint(
                    '   - base64サイズ: ${thumbBase64.length} bytes (${(thumbBase64.length / 1024).toStringAsFixed(2)} KB)');
              }
            } else {
              // サムネイル抽出に失敗した場合はプレースホルダーを使用
              if (kDebugMode) {
                debugPrint('⚠️ Web版: 動画サムネイル抽出失敗、プレースホルダーを使用');
              }
              thumbBase64 = base64Encode(
                  _generatePlaceholderThumbnail(320, 180, label: 'VIDEO'));
            }
          } catch (e) {
            // エラーが発生した場合はプレースホルダーを使用
            if (kDebugMode) {
              debugPrint('❌ Web版: 動画サムネイル抽出エラー: $e');
              debugPrint('   プレースホルダーを使用します');
            }
            thumbBase64 = base64Encode(
                _generatePlaceholderThumbnail(320, 180, label: 'VIDEO'));
          }
        } else {
          try {
            // 圧縮後の動画からサムネイルを抽出（圧縮に失敗した場合は元の動画から）
            // 注意: videoPathが存在する場合は、そのファイルがまだ存在する必要がある
            String thumbnailPath;
            if (!kIsWeb && videoPath != null && videoPath.isNotEmpty) {
              // モバイル版で圧縮が成功した場合、圧縮後のファイルからサムネイルを生成
              final compressedFile = File(videoPath);
              if (await compressedFile.exists()) {
                thumbnailPath = videoPath;
                if (kDebugMode) {
                  debugPrint('📹 圧縮後の動画からサムネイルを生成: $thumbnailPath');
                }
              } else {
                // 圧縮後のファイルが存在しない場合は元の動画から
                thumbnailPath = _selectedMedia!.path;
                if (kDebugMode) {
                  debugPrint(
                      '⚠️ 圧縮後のファイルが存在しないため、元の動画からサムネイルを生成: $thumbnailPath');
                }
              }
            } else {
              // 圧縮に失敗した場合やWeb版の場合は元の動画から
              thumbnailPath = _selectedMedia!.path;
              if (kDebugMode) {
                debugPrint('📹 元の動画からサムネイルを生成: $thumbnailPath');
              }
            }

            final thumbnailBytes = await _generateVideoThumbnail(thumbnailPath);
            if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
              thumbBase64 = base64Encode(thumbnailBytes);
              if (kDebugMode) {
                debugPrint('✅ 動画から最初のフレームをサムネイルとして抽出成功');
                debugPrint(
                    '   - サムネイルサイズ: ${thumbnailBytes.length} bytes (${(thumbnailBytes.length / 1024).toStringAsFixed(2)} KB)');
                debugPrint(
                    '   - base64サイズ: ${thumbBase64.length} bytes (${(thumbBase64.length / 1024).toStringAsFixed(2)} KB)');
              }
            } else {
              // サムネイル抽出に失敗した場合はプレースホルダーを使用
              if (kDebugMode) {
                debugPrint('⚠️ 動画サムネイル抽出失敗、プレースホルダーを使用');
                debugPrint('   - 動画パス: $thumbnailPath');
              }
              thumbBase64 = base64Encode(
                  _generatePlaceholderThumbnail(320, 180, label: 'VIDEO'));
            }
          } catch (e) {
            // エラーが発生した場合はプレースホルダーを使用
            if (kDebugMode) {
              debugPrint('❌ 動画サムネイル抽出エラー: $e');
              debugPrint('   プレースホルダーを使用します');
            }
            thumbBase64 = base64Encode(
                _generatePlaceholderThumbnail(320, 180, label: 'VIDEO'));
          }
        }

        // サムネイル生成が完了した後、圧縮後の一時ファイルを削除（モバイル版のみ）
        if (!kIsWeb && videoPath != null && videoPath.isNotEmpty) {
          try {
            final compressedFile = File(videoPath);
            if (await compressedFile.exists()) {
              await compressedFile.delete();
              if (kDebugMode) {
                debugPrint('📹 圧縮後の一時ファイルを削除しました: $videoPath');
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ 圧縮後の一時ファイル削除エラー: $e');
            }
          }
        }
      } else if (type == 'audio') {
        // 音声ファイルの処理（容量制限なし）
        Uint8List bytes;
        int audioFileSize;

        if (kIsWeb) {
          // Web版: PlatformFile.bytesを使用（withData: trueが必要）
          if (_selectedAudio!.bytes == null) {
            if (mounted) {
              _showSnackBar('音声ファイルの読み込みに失敗しました', Colors.red);
            }
            setState(() {
              _isPosting = false;
            });
            return;
          }
          bytes = _selectedAudio!.bytes!;
          audioFileSize = bytes.length;
        } else {
          // モバイル版: Fileクラスを使用
          final audioFile = File(_selectedAudio!.path!);
          audioFileSize = await audioFile.length();
          bytes = await audioFile.readAsBytes();
        }

        if (kDebugMode) {
          debugPrint(
              '🎵 音声ファイルサイズ: ${(audioFileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        }

        fileBase64 = base64Encode(bytes);

        if (kDebugMode) {
          debugPrint(
              '🎵 base64エンコード後サイズ: ${(fileBase64.length / 1024 / 1024).toStringAsFixed(2)} MB');
        }

        thumbBase64 = base64Encode(
            _generatePlaceholderThumbnail(320, 320, label: 'AUDIO'));
      } else {
        _showSnackBar('このバックエンドではテキスト単体投稿は未対応です', Colors.red);
        return;
      }

      String? link;
      if (_selectedMedia != null) {
        // Web版ではpathがnullの可能性があるため、nameを使用
        link = kIsWeb ? _selectedMedia!.name : _selectedMedia!.path;
      } else if (_selectedAudio != null) {
        // Web版ではpathがnullの可能性があるため、nameを使用
        link = kIsWeb ? _selectedAudio!.name : _selectedAudio!.path;
      }

      try {
        // タグはオプショナル（nullでも投稿可能）
        final result = await PostService.createPost(
          type: type,
          title: titleText,
          fileBase64: fileBase64,
          thumbnailBase64: thumbBase64,
          link: link,
          tag: tagValue, // タグが空の場合はnullを送信（バックエンド側のNoneTypeエラーを防ぐため）
        );

        if (mounted) {
          if (result == null) {
            // これは通常発生しないはず（例外がスローされるため）
            _showSnackBar('投稿に失敗しました', Colors.red);
            return;
          }
          _showSnackBar('投稿が完了しました！', Colors.green);
          _titleController.clear();
          _tagController.clear();
          setState(() {
            _selectedMedia = null;
            // 動画プレイヤーをクリーンアップ
            _cleanupVideoPlayer();
            _audioPlayer?.stop();
            _audioPlayer?.dispose();
            _audioPlayer = null;
            _selectedAudio = null;
            _isAudioPlaying = false;
          });
          // モーダルを閉じる
          Navigator.of(context).pop();
        }
      } on Exception catch (e) {
        // PostServiceからスローされた例外をキャッチ
        if (mounted) {
          final errorMessage = e.toString().replaceFirst('Exception: ', '');
          _showSnackBar(errorMessage, Colors.red);
        }
      } catch (e) {
        // その他の予期しないエラー
        if (mounted) {
          if (kDebugMode) {
            debugPrint('❌ 予期しないエラー: $e');
          }
          final errorMessage = _getPostCreationErrorMessage(type);
          _showSnackBar(errorMessage, Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        if (kDebugMode) {
          debugPrint('❌ 投稿処理中のエラー: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('投稿処理中にエラーが発生しました: $e'),
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
    final resized = img.copyResize(
      decoded,
      width: 320,
      height: 320,
      interpolation: img.Interpolation.linear,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }

  // Web版で動画からサムネイルを生成（HTML5 Video API + Canvas API）
  //
  // ※ 元々は dart:html を使った実装でしたが、
  //   モバイルビルド（Android/iOS）では dart:html が利用できないため
  //   ここではスタブ実装にしてあります。
  //   Web専用サムネイル生成機能の元コードは下にコメントとして残しています。
  Future<Uint8List?> _generateVideoThumbnailWeb(Uint8List videoBytes) async {
    // 現状は常に null を返し、呼び出し側でプレースホルダー生成にフォールバックします。
    return null;
  }

  /*
  // 旧実装（Web専用、dart:html 依存）
  Future<Uint8List?> _generateVideoThumbnailWeb(Uint8List videoBytes) async {
    if (!kIsWeb) {
      return null;
    }

    try {
      if (kDebugMode) {
        debugPrint('🎬 Web版: 動画サムネイル抽出開始');
      }

      // Blobを作成
      final blob = html.Blob([videoBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      try {
        // Video要素を作成
        final video = html.VideoElement()
          ..src = url
          ..crossOrigin = 'anonymous';

        // 動画のメタデータが読み込まれるまで待機
        await video.onLoadedMetadata.first.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('動画のメタデータ読み込みタイムアウト');
          },
        );

        // 最初のフレームにシーク
        video.currentTime = 0.0;

        // フレームが読み込まれるまで待機
        await video.onSeeked.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('動画のシークタイムアウト');
          },
        );

        // Canvas要素を作成
        final canvas = html.CanvasElement(
          width: 640,
          height: 360,
        );
        final ctx = canvas.context2D;

        // 動画のアスペクト比を維持して描画
        final videoAspect = video.videoWidth / video.videoHeight;
        final canvasAspect = 640.0 / 360.0;

        double drawWidth, drawHeight, drawX, drawY;
        if (videoAspect > canvasAspect) {
          // 動画が横長の場合
          drawHeight = 360.0;
          drawWidth = 360.0 * videoAspect;
          drawX = (640.0 - drawWidth) / 2.0;
          drawY = 0.0;
        } else {
          // 動画が縦長の場合
          drawWidth = 640.0;
          drawHeight = 640.0 / videoAspect;
          drawX = 0.0;
          drawY = (360.0 - drawHeight) / 2.0;
        }

        // 背景を黒で塗りつぶし
        ctx.fillStyle = '#000000';
        ctx.fillRect(0, 0, 640, 360);

        // 動画を描画
        ctx.drawImageScaled(video, drawX, drawY, drawWidth, drawHeight);

        // CanvasからBlobを取得（JPEG形式、品質85%）
        final thumbnailBlob = await canvas.toBlob('image/jpeg', 0.85);

        // BlobをUint8Listに変換
        final reader = html.FileReader();
        final completer = Completer<Uint8List>();

        reader.onLoad.listen((e) {
          final result = reader.result;
          if (result is ByteBuffer) {
            completer.complete(Uint8List.view(result));
          } else {
            completer.completeError('FileReaderの結果がByteBufferではありません');
          }
        });

        reader.onError.listen((e) {
          completer.completeError('FileReaderエラー');
        });

        reader.readAsArrayBuffer(thumbnailBlob);

        final thumbnailBytes = await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Blob読み込みタイムアウト');
          },
        );

        // URLを解放
        html.Url.revokeObjectUrl(url);

        if (kDebugMode) {
          debugPrint('✅ Web版: 動画サムネイル抽出成功: ${thumbnailBytes.length} bytes');
        }

        return thumbnailBytes;
      } catch (e) {
        // URLを解放
        html.Url.revokeObjectUrl(url);
        rethrow;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Web版: 動画サムネイル抽出エラー: $e');
        debugPrint('   スタックトレース: $stackTrace');
      }
      return null;
    }
  }
  */

  // 動画から最初のフレームをサムネイルとして抽出
  // Web版ではHTML5 Video API + Canvas APIを使用
  Future<Uint8List?> _generateVideoThumbnail(String videoPath) async {
    if (kIsWeb) {
      // Web版では使用しない（Web版は別の関数を使用）
      return null;
    }

    try {
      if (kDebugMode) {
        debugPrint('🎬 動画サムネイル抽出開始: $videoPath');
      }

      // 動画から最初のフレーム（timeMs: 0）を抽出
      // タイムアウトを設定してバッファエラーを防ぐ
      // サムネイル用に適切な解像度と品質を設定
      String? thumbnailPath;
      try {
        thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoPath,
          thumbnailPath: Directory.systemTemp.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 640, // サムネイル用に適切な解像度（640px）
          maxHeight: 360, // 16:9のアスペクト比を維持
          quality: 85, // JPEG品質を85に設定（品質とファイルサイズのバランス）
          timeMs: 0, // 最初のフレーム（0ミリ秒）
        ).timeout(
          const Duration(seconds: 15), // 15秒でタイムアウト
          onTimeout: () {
            if (kDebugMode) {
              debugPrint('⚠️ 動画サムネイル抽出タイムアウト');
            }
            return null;
          },
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ 動画サムネイル抽出中にエラーが発生: $e');
        }
        thumbnailPath = null;
      }

      if (thumbnailPath == null || thumbnailPath.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ 動画サムネイル抽出失敗: パスが空');
        }
        return null;
      }

      // 抽出したサムネイル画像を読み込む
      final thumbnailFile = File(thumbnailPath);
      if (!await thumbnailFile.exists()) {
        if (kDebugMode) {
          debugPrint('⚠️ 動画サムネイル抽出失敗: ファイルが存在しない');
        }
        return null;
      }

      final thumbnailBytes = await thumbnailFile.readAsBytes();

      if (kDebugMode) {
        debugPrint('✅ 動画サムネイル抽出成功: ${thumbnailBytes.length} bytes');
      }

      // 一時ファイルを削除
      try {
        await thumbnailFile.delete();
        if (kDebugMode) {
          debugPrint('🗑️ 一時サムネイルファイルを削除: $thumbnailPath');
        }
      } catch (e) {
        // 削除エラーは無視
        if (kDebugMode) {
          debugPrint('⚠️ 一時ファイル削除エラー（無視）: $e');
        }
      }

      return thumbnailBytes;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ 動画サムネイル抽出例外: $e');
        debugPrint('   スタックトレース: $stackTrace');
      }
      return null;
    }
  }

  // 動画/音声の簡易サムネイル（プレースホルダ）
  Uint8List _generatePlaceholderThumbnail(int width, int height,
      {required String label}) {
    final canvas = img.Image(width: width, height: height);
    img.fill(canvas, color: img.ColorRgb8(30, 30, 30));
    img.drawRect(canvas,
        x1: 0,
        y1: height - 6,
        x2: width,
        y2: height,
        color: img.ColorRgb8(255, 107, 53));
    final font = img.arial24;
    // BitmapFontにmeasure APIがないため、おおよその文字幅/高さでセンタリング
    const approxCharWidth = 14; // arial24 推定
    const approxHeight = 24; // arial24 高さ
    final textWidth = approxCharWidth * label.runes.length;
    final tx = ((width - textWidth) / 2).round();
    final ty = ((height - approxHeight) / 2).round();
    img.drawString(
      canvas,
      label,
      x: tx,
      y: ty,
      font: font,
      color: img.ColorRgb8(255, 255, 255),
    );
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 85));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          '新しい投稿',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor ??
                const Color(0xFF1A1A1A),
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
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                    ),
                  )
                : const Text(
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
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
                final availableHeight = constraints.maxHeight - keyboardHeight;
                
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: availableHeight,
                    ),
                    child: IntrinsicHeight(
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
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(_titleMaxLength),
                              ],
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
                                  '${_titleController.text.length}/$_titleMaxLength',
                                  style: TextStyle(
                                    color:
                                        _titleController.text.length > _titleMaxLength
                                            ? Colors.red
                                            : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'タグ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _tagController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(_titleMaxLength),
                              ],
                              decoration: InputDecoration(
                                hintText: 'タグを入力（例: #music）',
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
                                  '${_tagController.text.length}/$_titleMaxLength',
                                  style: TextStyle(
                                    color:
                                        _tagController.text.length > _titleMaxLength
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

                      // 背景メディアプレビューエリア（固定サイズ）
                      SizedBox(
                        height: keyboardHeight > 0 
                            ? availableHeight * 0.5  // キーボード表示時は高さを調整
                            : constraints.maxHeight * 0.5,  // 通常時は固定サイズ
                        child: _selectedMedia == null && _selectedAudio == null
                            ? _buildMediaSelectionPrompt()
                            : _selectedMedia != null
                                ? _buildMediaPreviewWithOverlays()
                                : _buildAudioPreview(),
                      ),

                      // 選択済み音声ファイル表示（背景メディアがある場合は下に表示）
                      if (_selectedAudio != null)
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 16.0, right: 16.0, bottom: 8.0),
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
                            onTap: () =>
                                  _pickMedia(ImageSource.gallery, isVideo: false),
                                ),
                                const SizedBox(width: 12),
                                _buildOptionButton(
                                  icon: Icons.videocam_outlined,
                                  label: '動画',
                                  onTap: () =>
                                      _pickMedia(ImageSource.gallery, isVideo: true),
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
                        ),
                      if (_selectedMedia != null)
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
                                const SizedBox(width: 12),
                                _buildOptionButton(
                                  icon: Icons.audiotrack_outlined,
                                  label: '音声に変更',
                                  onTap: _pickAudioFile,
                                ),
                              ],
                      ),
                    ),
                  ),
                      if (_selectedAudio != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildOptionButton(
                                  icon: Icons.image_outlined,
                                  label: '写真を追加',
                                  onTap: () =>
                                      _pickMedia(ImageSource.gallery, isVideo: false),
                                ),
                                const SizedBox(width: 12),
                                _buildOptionButton(
                                  icon: Icons.videocam_outlined,
                                  label: '動画を追加',
                                  onTap: () =>
                                      _pickMedia(ImageSource.gallery, isVideo: true),
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
              ),
                ); // SingleChildScrollView の終わり
              },
            ),
          ),
          // 投稿中の画面ブロックとローディング表示
          if (_isPosting)
            AbsorbPointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                        strokeWidth: 4,
                      ),
                      SizedBox(height: 24),
                      Text(
                        '投稿中...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'しばらくお待ちください',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
          const Icon(
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
        // 画像のサイズを固定（キーボード表示時も圧縮されない）
        final imageHeight = constraints.maxHeight;
        final imageWidth = constraints.maxWidth;
        
        return SizedBox(
              width: imageWidth,
              height: imageHeight,
              child: Stack(
                children: [
                  // 背景メディア（固定サイズ）
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: isVideo
                        ? _buildVideoPreview()
                        : kIsWeb
                            ? FutureBuilder<Uint8List>(
                                future: _selectedMedia!.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (snapshot.hasError || !snapshot.hasData) {
                                    return const Center(
                                      child: Icon(Icons.error, color: Colors.red),
                                    );
                                  }
                                  return SizedBox(
                                    width: imageWidth,
                                    height: imageHeight,
                                    child: Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.contain,
                                    ),
                                  );
                                },
                              )
                            : SizedBox(
                                width: imageWidth,
                                height: imageHeight,
                                child: Image.file(
                                  File(_selectedMedia!.path),
                                  fit: BoxFit.contain,
                                ),
                              ),
                  ),
                ],
              ),
        );
      },
    );
  }

  // メディア選択ダイアログ
  void _showMediaSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          '背景を変更',
          style:
              TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.image_outlined, color: Color(0xFFFF6B35)),
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
              leading:
                  const Icon(Icons.videocam_outlined, color: Color(0xFFFF6B35)),
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
        _cleanupVideoPlayer();

        setState(() {
          _selectedMedia = pickedFile;
        });

        // 動画の場合はプレイヤーを初期化
        if (isVideo) {
          // 既存のプレイヤーとリスナーをクリーンアップ
          _cleanupVideoPlayer();

          // 動画ファイルの存在確認（Web版ではスキップ）
          if (!kIsWeb) {
            final videoFile = File(pickedFile.path);
            if (!await videoFile.exists()) {
              if (mounted) {
                _showSnackBar('動画ファイルが見つかりません', Colors.red);
              }
              return;
            }
          }

          // ファイルサイズを確認（0バイトの場合はエラー）
          // Web版ではスキップ（XFileから直接読み取る際にサイズを確認）
          int fileSize;
          if (kIsWeb) {
            // Web版では読み込んでサイズを確認
            final bytes = await pickedFile.readAsBytes();
            fileSize = bytes.length;
          } else {
            fileSize = await File(pickedFile.path).length();
          }
          if (fileSize == 0) {
            if (mounted) {
              _showSnackBar('動画ファイルが空です', Colors.red);
            }
            return;
          }

          if (kDebugMode) {
            debugPrint('📹 動画ファイル確認:');
            debugPrint('   - パス: ${pickedFile.path}');
            debugPrint(
                '   - サイズ: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
          }

          // 少し待ってから新しいプレイヤーを初期化（バッファ解放の時間を確保）
          await Future.delayed(const Duration(milliseconds: 300));

          // リトライ機能付きで動画プレイヤーを初期化
          bool initialized = false;
          int retryCount = 0;
          const maxRetries = 2;

          while (!initialized && retryCount < maxRetries) {
            try {
              if (kDebugMode) {
                debugPrint('📹 動画プレイヤー初期化試行 ${retryCount + 1}/$maxRetries');
              }

              // 以前のプレイヤーが残っている場合はクリーンアップ
              if (_videoPlayerController != null) {
                _cleanupVideoPlayer();
                await Future.delayed(const Duration(milliseconds: 200));
              }

              // Web版では動画プレイヤーをスキップ（video_playerはWebで制限があるため）
              if (kIsWeb) {
                if (kDebugMode) {
                  debugPrint('⚠️ Web版では動画プレイヤーの初期化をスキップ');
                }
                return;
              }

              _videoPlayerController =
                  VideoPlayerController.file(File(pickedFile.path));

              // タイムアウトを設定して初期化
              await _videoPlayerController!.initialize().timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw TimeoutException(
                    '動画プレイヤーの初期化がタイムアウトしました',
                    const Duration(seconds: 10),
                  );
                },
              );

              // 初期化成功
              initialized = true;

              if (kDebugMode) {
                debugPrint('✅ 動画プレイヤー初期化成功');
                debugPrint(
                    '   - 解像度: ${_videoPlayerController!.value.size.width}x${_videoPlayerController!.value.size.height}');
                debugPrint(
                    '   - 長さ: ${_videoPlayerController!.value.duration.inSeconds}秒');
              }

              // 動画プレイヤーの状態変更を監視（リスナーを保存）
              _videoPlayerListener = () {
                if (mounted && _videoPlayerController != null) {
                  try {
                    setState(() {
                      _isVideoPlaying = _videoPlayerController!.value.isPlaying;
                    });
                  } catch (e) {
                    // setStateエラーは無視（既にdisposeされている可能性がある）
                  }
                }
              };
              _videoPlayerController!.addListener(_videoPlayerListener!);

              // 初期状態では停止
              if (_videoPlayerController!.value.isPlaying) {
                _videoPlayerController!.pause();
              }

              setState(() {});
            } catch (e) {
              retryCount++;
              if (kDebugMode) {
                debugPrint('❌ 動画プレイヤー初期化エラー（試行 $retryCount/$maxRetries）: $e');
              }

              // エラー時はプレイヤーをクリーンアップ
              _cleanupVideoPlayer();

              if (retryCount < maxRetries) {
                // リトライ前に待機
                if (kDebugMode) {
                  debugPrint('⏳ リトライ前に待機中...');
                }
                await Future.delayed(Duration(milliseconds: 500 * retryCount));
              } else {
                // すべてのリトライが失敗した場合
                if (kDebugMode) {
                  debugPrint('❌ 動画プレイヤー初期化に失敗しました（全試行失敗）');
                }
                if (mounted) {
                  // エラーメッセージを簡潔に表示
                  final errorMessage = e.toString();
                  String userMessage;
                  if (errorMessage.contains('ExoPlaybackException') ||
                      errorMessage.contains('MediaCodec')) {
                    userMessage = '動画の読み込みに失敗しました。この動画は投稿できますが、プレビューは表示されません。';
                  } else if (errorMessage.contains('TimeoutException')) {
                    userMessage =
                        '動画の読み込みに時間がかかりすぎました。この動画は投稿できますが、プレビューは表示されません。';
                  } else {
                    userMessage = '動画の読み込みに失敗しました。この動画は投稿できますが、プレビューは表示されません。';
                  }
                  _showSnackBar(userMessage, Colors.orange);
                }
              }
            }
          }
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
    // iOS、Android、Webすべてのプラットフォームで音声選択をサポート

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
      _cleanupVideoPlayer();
      setState(() {
        _selectedMedia = null;
      });
    }

    try {
      if (kDebugMode) {
        debugPrint('🎵 音声ファイル選択を開始...');
      }

      // iOSではFileType.customを使用してファイルアプリを起動
      // AndroidとWebではFileType.audioを使用
      // Web版ではwithData: trueが必要（ファイルパスが取得できないため）
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: Platform.isIOS ? FileType.custom : FileType.audio,
        allowedExtensions: Platform.isIOS
            ? ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac', 'opus']
            : null,
        allowMultiple: false,
        dialogTitle: '音声ファイルを選択',
        withData: kIsWeb, // Web版ではtrue、モバイル版ではfalse（メモリ効率のため）
        withReadStream: false,
      );

      if (result == null) {
        if (kDebugMode) {
          debugPrint('⚠️ ファイル選択がキャンセルされました');
        }
        return;
      }

      if (result.files.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ 選択されたファイルがありません');
        }
        _showSnackBar('ファイルが選択されませんでした', Colors.orange);
        return;
      }

      final selectedFile = result.files.single;

      if (kDebugMode) {
        debugPrint('📁 選択されたファイル:');
        debugPrint('   名前: ${selectedFile.name}');
        debugPrint('   パス: ${selectedFile.path}');
        debugPrint('   サイズ: ${selectedFile.size} bytes');
        debugPrint('   拡張子: ${selectedFile.extension}');
      }

      // ファイルパスの確認（Web版ではスキップ）
      if (!kIsWeb) {
        if (selectedFile.path == null || selectedFile.path!.isEmpty) {
          if (kDebugMode) {
            debugPrint('❌ ファイルパスが取得できませんでした');
          }
          _showSnackBar('ファイルパスを取得できませんでした', Colors.red);
          return;
        }

        // ファイルの存在確認（モバイル版のみ）
        final file = File(selectedFile.path!);
        if (!await file.exists()) {
          if (kDebugMode) {
            debugPrint('❌ ファイルが存在しません: ${selectedFile.path}');
          }
          _showSnackBar('選択されたファイルが見つかりません', Colors.red);
          return;
        }
      }

      // ファイル拡張子の確認
      final fileName = selectedFile.name.toLowerCase();
      final fileExtension = fileName.split('.').last;
      final validExtensions = [
        'mp3',
        'm4a',
        'aac',
        'wav',
        'ogg',
        'flac',
        'opus'
      ];

      if (!validExtensions.contains(fileExtension)) {
        if (kDebugMode) {
          debugPrint('❌ 無効な拡張子: $fileExtension');
        }
        _showSnackBar(
          '音声ファイルのみ選択できます（対応形式: MP3, M4A, AAC, WAV, OGG, FLAC, OPUS）',
          Colors.red,
        );
        return;
      }

      // ファイルサイズチェック（50MB制限）
      final fileSize = kIsWeb
          ? (selectedFile.bytes?.length ?? 0)
          : await File(selectedFile.path!).length();
      if (fileSize > 50 * 1024 * 1024) {
        if (kDebugMode) {
          debugPrint(
              '❌ ファイルサイズが大きすぎます: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        }
        _showSnackBar(
          '音声ファイルが大きすぎます（50MB以下にしてください）',
          Colors.red,
        );
        return;
      }

      // ファイルパス（Web版では使用しない）
      final filePath = kIsWeb ? null : selectedFile.path;

      if (kDebugMode) {
        debugPrint(
            '✅ ファイル検証成功: ${filePath ?? selectedFile.name} (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');
      }

      setState(() {
        _selectedAudio = selectedFile;
      });

      // 音声プレイヤーを初期化
      _audioPlayer?.dispose();
      _audioPlayer = AudioPlayer();

      try {
        if (kDebugMode) {
          debugPrint('🎵 音声プレイヤーを初期化中...');
        }
        if (kIsWeb) {
          // Web版: データURLを作成してsetUrlを使用
          if (selectedFile.bytes == null) {
            throw Exception('音声ファイルのデータが取得できませんでした');
          }
          // データURLを作成（base64エンコード）
          final base64Audio = base64Encode(selectedFile.bytes!);
          final mimeType = _getAudioMimeType(fileExtension);
          final dataUrl = 'data:$mimeType;base64,$base64Audio';
          await _audioPlayer!.setUrl(dataUrl);
        } else {
          // モバイル版: setFilePathを使用
          await _audioPlayer!.setFilePath(filePath!);
        }
        if (kDebugMode) {
          debugPrint('✅ 音声プレイヤー初期化成功');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ 音声ファイルの読み込みに失敗: $e');
          debugPrint('   StackTrace: $stackTrace');
        }
        if (mounted) {
          _showSnackBar('音声ファイルの読み込みに失敗しました: $e', Colors.red);
        }
        // エラー時は選択をクリア
        setState(() {
          _selectedAudio = null;
          _audioPlayer?.dispose();
          _audioPlayer = null;
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ 音声ファイル選択エラー: $e');
        debugPrint('   StackTrace: $stackTrace');
      }
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
              const Icon(
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
                              ? position.inMilliseconds /
                                  duration.inMilliseconds
                              : 0.0,
                          onChanged: (value) {
                            if (_audioPlayer != null &&
                                duration.inMilliseconds > 0) {
                              final newPosition = Duration(
                                milliseconds:
                                    (value * duration.inMilliseconds).round(),
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
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Row(
            children: [
              const Icon(Icons.mic, color: Color(0xFFFF6B35)),
              const SizedBox(width: 8),
              Text(
                '音声機能',
                style: TextStyle(color: theme.textTheme.titleLarge?.color),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Android端末でのみ利用可能です！',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '対応フォーマット:',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
        );
      },
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '• $text',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color,
          fontSize: 14,
        ),
      ),
    );
  }

  // 動画プレビュー表示
  Widget _buildVideoPreview() {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
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

    // Visibilityウィジェットで画面から外れたときに自動的に停止
    return Visibility(
      visible: true,
      maintainState: false, // 画面から外れたときに状態を保持しない
      child: Stack(
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
              decoration: const BoxDecoration(
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
      ),
    );
  }

  // 動画の再生/一時停止を切り替え
  void _toggleVideoPlayback() {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      return;
    }

    try {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
      } else {
        _videoPlayerController!.play();
      }
      // 状態はリスナーで自動更新される
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 動画再生切り替えエラー: $e');
      }
      // エラー時はプレイヤーをクリーンアップ
      _cleanupVideoPlayer();
    }
  }

  // コンテンツコンフリクトダイアログ
  Future<bool?> _showContentConflictDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(
            title,
            style: TextStyle(color: theme.textTheme.titleLarge?.color),
          ),
          content: Text(
            message,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
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
              child: const Text(
                '続行',
                style: TextStyle(
                  color: SpotLightColors.primaryOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 投稿作成エラーメッセージ取得
  // 音声ファイルのMIMEタイプを取得
  String _getAudioMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      case 'opus':
        return 'audio/opus';
      default:
        return 'audio/mpeg';
    }
  }

  String _getPostCreationErrorMessage(String type) {
    if (type == 'video') {
      return '動画ファイルが大きすぎるか、サーバーへの送信に失敗しました。より小さな動画（100MB以下）を選択してください。';
    } else if (type == 'audio') {
      return '音声ファイルが大きすぎるか、サーバーへの送信に失敗しました。より小さな音声ファイルを選択してください。';
    } else if (type == 'image') {
      return '画像ファイルが大きすぎるか、サーバーへの送信に失敗しました。';
    } else {
      return '投稿に失敗しました。しばらく時間をおいて再度お試しください。';
    }
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
