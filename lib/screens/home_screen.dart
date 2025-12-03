import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/icon_update_service.dart';
import '../config/app_config.dart';
import '../utils/spotlight_colors.dart';
import '../widgets/robust_network_image.dart';
import '../providers/navigation_provider.dart';
import '../services/comment_service.dart';
import '../services/playlist_service.dart';
import '../models/comment.dart';
import '../auth/auth_provider.dart';
import '../services/report_service.dart';
import 'user_profile_screen.dart';

/// 通報ダイアログ（独立したStatefulWidgetとして分離）
class _ReportDialog extends StatefulWidget {
  final Post post;

  const _ReportDialog({required this.post});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

/// コメント通報ダイアログ（独立したStatefulWidgetとして分離）
class _CommentReportDialog extends StatefulWidget {
  final Comment comment;
  final Post post;

  const _CommentReportDialog({
    required this.comment,
    required this.post,
  });

  @override
  State<_CommentReportDialog> createState() => _CommentReportDialogState();
}

class _CommentReportDialogState extends State<_CommentReportDialog> {
  final _reasonController = TextEditingController();
  String _selectedReason = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('🚨 _CommentReportDialogState.initState が呼ばれました');
    }
    // 自分のコメントかどうかをチェック
    _checkIfOwnComment();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// エラーダイアログを表示（ダイアログ内から呼び出し用）
  void _showErrorDialogInDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline,
                color: Color(0xFFFF6B35),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 自分のコメントかどうかをチェック
  void _checkIfOwnComment() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.currentUser?.id;
      final commentUserId = widget.comment.userId?.toString().trim() ?? '';
      final currentUserIdStr = currentUserId?.toString().trim() ?? '';

      if (kDebugMode) {
        debugPrint('🚨 コメント通報ダイアログ内チェック:');
        debugPrint('  currentUserId: "$currentUserIdStr"');
        debugPrint('  commentUserId: "$commentUserId"');
        debugPrint('  一致: ${currentUserIdStr == commentUserId}');
      }

      if (currentUserIdStr.isNotEmpty &&
          commentUserId.isNotEmpty &&
          currentUserIdStr == commentUserId) {
        Navigator.of(context).pop();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _showErrorDialogInDialog(context, '自分のコメントは通報できません');
          }
        });
      }
    });
  }

  /// 通報理由の選択肢を構築
  Widget _buildReasonOption(
    String reason,
    String selectedReason,
    Function(String) onTap,
  ) {
    final isSelected = selectedReason == reason;
    return GestureDetector(
      onTap: () => onTap(reason),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF6B35).withOpacity(0.2)
              : Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[300],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('🚨 _CommentReportDialogState.build が呼ばれました');
    }
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'コメントを通報',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '通報理由を選択してください',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildReasonOption(
              '不適切なコンテンツ',
              _selectedReason,
              (reason) {
                if (mounted) {
                  setState(() {
                    _selectedReason = reason;
                  });
                }
              },
            ),
            _buildReasonOption(
              '差別的または攻撃的なコメント',
              _selectedReason,
              (reason) {
                if (mounted) {
                  setState(() {
                    _selectedReason = reason;
                  });
                }
              },
            ),
            _buildReasonOption(
              'スパムまたは詐欺',
              _selectedReason,
              (reason) {
                if (mounted) {
                  setState(() {
                    _selectedReason = reason;
                  });
                }
              },
            ),
            _buildReasonOption(
              'その他',
              _selectedReason,
              (reason) {
                if (mounted) {
                  setState(() {
                    _selectedReason = reason;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              '詳細（任意）',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '詳細な理由を入力してください',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text(
            'キャンセル',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        TextButton(
          onPressed: _isSubmitting || _selectedReason.isEmpty
              ? null
              : () async {
                  if (!mounted) return;

                  // 自分のコメントかどうかを再度チェック
                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  final currentUserId = authProvider.currentUser?.id;
                  final commentUserId =
                      widget.comment.userId?.toString().trim() ?? '';
                  final currentUserIdStr =
                      currentUserId?.toString().trim() ?? '';

                  if (currentUserIdStr.isNotEmpty &&
                      commentUserId.isNotEmpty &&
                      currentUserIdStr == commentUserId) {
                    if (mounted) {
                      Navigator.of(context).pop();
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          _showErrorDialogInDialog(context, '自分のコメントは通報できません');
                        }
                      });
                    }
                    return;
                  }

                  final detailText = _reasonController.text.trim();

                  setState(() {
                    _isSubmitting = true;
                  });

                  if (!mounted) return;

                  final reportCheckAuthProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  final reportCurrentUserId =
                      reportCheckAuthProvider.currentUser?.id;

                  final result = await ReportService.sendReport(
                    type: 'comment',
                    reason: _selectedReason,
                    detail: detailText.isNotEmpty ? detailText : null,
                    contentID: widget.post.id.toString(),
                    commentID: widget.comment.commentID,
                    currentUserId: reportCurrentUserId,
                    commentUserId: widget.comment.userId,
                  );

                  if (!mounted) return;

                  setState(() {
                    _isSubmitting = false;
                  });

                  if (!mounted) return;

                  if (result.success) {
                    Navigator.of(context).pop(true);
                  } else {
                    if (mounted) {
                      final errorMessage =
                          result.errorMessage ?? '通報の送信に失敗しました';
                      if (errorMessage.contains('自分の') ||
                          errorMessage.contains('own') ||
                          errorMessage.contains('self')) {
                        Navigator.of(context).pop();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            _showErrorDialogInDialog(
                                context, '自分のコメントは通報できません');
                          }
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF6B35),
                  ),
                )
              : const Text(
                  '送信',
                  style: TextStyle(color: Color(0xFFFF6B35)),
                ),
        ),
      ],
    );
  }
}

class _ReportDialogState extends State<_ReportDialog> {
  final _reasonController = TextEditingController();
  String _selectedReason = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 自分の投稿かどうかをチェック
    _checkIfOwnPost();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// エラーダイアログを表示（ダイアログ内から呼び出し用）
  void _showErrorDialogInDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // エラーアイコン
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline,
                color: Color(0xFFFF6B35),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            // メッセージ
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 自分の投稿かどうかをチェック
  void _checkIfOwnPost() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.currentUser?.id;
      final postUserId = widget.post.userId.toString().trim();
      final currentUserIdStr = currentUserId?.toString().trim() ?? '';

      if (kDebugMode) {
        debugPrint('🚨 通報ダイアログ内チェック:');
        debugPrint('  currentUserId: "$currentUserIdStr"');
        debugPrint('  postUserId: "$postUserId"');
        debugPrint('  一致: ${currentUserIdStr == postUserId}');
      }

      if (currentUserIdStr.isNotEmpty &&
          postUserId.isNotEmpty &&
          currentUserIdStr == postUserId) {
        // 自分の投稿の場合はダイアログを閉じてエラーダイアログを表示
        Navigator.of(context).pop();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _showErrorDialogInDialog(context, '自分の投稿は通報できません');
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        '投稿を通報',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '通報理由を選択してください',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            // 通報理由の選択肢
            _buildReasonOption(
              '不適切なコンテンツ',
              _selectedReason,
              (reason) {
                if (mounted) {
                  setState(() {
                    _selectedReason = reason;
                  });
                }
              },
            ),
            _buildReasonOption(
              'スパムまたは詐欺',
              _selectedReason,
              (reason) {
                if (mounted) {
                  setState(() {
                    _selectedReason = reason;
                  });
                }
              },
            ),
            _buildReasonOption(
              '著作権侵害',
              _selectedReason,
              (reason) {
                if (mounted) {
                  setState(() {
                    _selectedReason = reason;
                  });
                }
              },
            ),
            _buildReasonOption(
              'その他',
              _selectedReason,
              (reason) {
                if (mounted) {
                  setState(() {
                    _selectedReason = reason;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              '詳細（任意）',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '詳細な理由を入力してください',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text(
            'キャンセル',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        TextButton(
          onPressed: _isSubmitting || _selectedReason.isEmpty
              ? null
              : () async {
                  if (!mounted) return;

                  // 自分の投稿かどうかを再度チェック（送信前に最終確認）
                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  final currentUserId = authProvider.currentUser?.id;
                  final postUserId = widget.post.userId.toString().trim();
                  final currentUserIdStr =
                      currentUserId?.toString().trim() ?? '';

                  if (kDebugMode) {
                    debugPrint('🚨 通報送信前チェック:');
                    debugPrint('  currentUserId: "$currentUserIdStr"');
                    debugPrint('  postUserId: "$postUserId"');
                    debugPrint('  一致: ${currentUserIdStr == postUserId}');
                  }

                  // 自分の投稿かどうかを厳密にチェック（送信前に最終確認）
                  if (currentUserIdStr.isNotEmpty &&
                      postUserId.isNotEmpty &&
                      currentUserIdStr == postUserId) {
                    // 自分の投稿の場合は送信をブロックしてエラーダイアログを表示
                    if (kDebugMode) {
                      debugPrint('🚨 自分の投稿への通報をブロックしました');
                    }
                    if (mounted) {
                      Navigator.of(context).pop();
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          _showErrorDialogInDialog(context, '自分の投稿は通報できません');
                        }
                      });
                    }
                    return; // ここで必ずreturnして送信をブロック
                  }

                  // 念のため、もう一度チェック（二重チェック）
                  if (currentUserIdStr == postUserId) {
                    if (kDebugMode) {
                      debugPrint('🚨 二重チェック: 自分の投稿への通報をブロックしました');
                    }
                    if (mounted) {
                      Navigator.of(context).pop();
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          _showErrorDialogInDialog(context, '自分の投稿は通報できません');
                        }
                      });
                    }
                    return;
                  }

                  // reasonController.textを先に取得（破棄される前に）
                  final detailText = _reasonController.text.trim();

                  setState(() {
                    _isSubmitting = true;
                  });

                  if (!mounted) return;

                  // バックエンドに送信する前に、もう一度チェック
                  final finalCheckAuthProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  final finalCheckCurrentUserId =
                      (finalCheckAuthProvider.currentUser?.id ?? '')
                          .toString()
                          .trim();
                  final finalCheckPostUserId =
                      widget.post.userId.toString().trim();

                  if (finalCheckCurrentUserId.isNotEmpty &&
                      finalCheckPostUserId.isNotEmpty &&
                      finalCheckCurrentUserId == finalCheckPostUserId) {
                    // 自分の投稿の場合は送信をブロック
                    if (kDebugMode) {
                      debugPrint('🚨 最終チェック: 自分の投稿への通報をブロックしました');
                    }
                    setState(() {
                      _isSubmitting = false;
                    });
                    if (mounted) {
                      Navigator.of(context).pop();
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          _showErrorDialogInDialog(context, '自分の投稿は通報できません');
                        }
                      });
                    }
                    return;
                  }

                  // 現在のユーザーIDを取得してReportServiceに渡す
                  final reportCheckAuthProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  final reportCurrentUserId =
                      reportCheckAuthProvider.currentUser?.id;

                  final result = await ReportService.sendReport(
                    type: 'content',
                    reason: _selectedReason,
                    detail: detailText.isNotEmpty ? detailText : null,
                    contentID: widget.post.id.toString(),
                    currentUserId: reportCurrentUserId,
                    postUserId: widget.post.userId,
                  );

                  if (!mounted) return;

                  setState(() {
                    _isSubmitting = false;
                  });

                  if (!mounted) return;

                  if (result.success) {
                    // 送信成功後も念のためチェック（バックエンドが自分の投稿を通報させた場合）
                    final postCheckAuthProvider =
                        Provider.of<AuthProvider>(context, listen: false);
                    final postCheckCurrentUserId =
                        (postCheckAuthProvider.currentUser?.id ?? '')
                            .toString()
                            .trim();
                    final postCheckPostUserId =
                        widget.post.userId.toString().trim();

                    if (postCheckCurrentUserId.isNotEmpty &&
                        postCheckPostUserId.isNotEmpty &&
                        postCheckCurrentUserId == postCheckPostUserId) {
                      // 自分の投稿だった場合は成功ダイアログを表示せず、エラーダイアログを表示
                      if (kDebugMode) {
                        debugPrint('🚨 送信後チェック: 自分の投稿だったため、成功を無効化しました');
                      }
                      if (mounted) {
                        Navigator.of(context).pop();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            _showErrorDialogInDialog(context, '自分の投稿は通報できません');
                          }
                        });
                      }
                      return;
                    }

                    Navigator.of(context).pop(true);
                  } else {
                    if (mounted) {
                      // エラーメッセージを表示
                      final errorMessage =
                          result.errorMessage ?? '通報の送信に失敗しました';

                      // バックエンドが自分の投稿を通報させないようにした場合のエラーメッセージを確認
                      if (errorMessage.contains('自分の') ||
                          errorMessage.contains('own') ||
                          errorMessage.contains('self')) {
                        // 自分の投稿に関するエラーの場合は、エラーダイアログを表示
                        Navigator.of(context).pop();
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            _showErrorDialogInDialog(context, '自分の投稿は通報できません');
                          }
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF6B35),
                  ),
                )
              : const Text(
                  '送信',
                  style: TextStyle(color: Color(0xFFFF6B35)),
                ),
        ),
      ],
    );
  }

  /// 通報理由の選択肢を構築
  Widget _buildReasonOption(
    String reason,
    String selectedReason,
    Function(String) onTap,
  ) {
    final isSelected = selectedReason == reason;
    return GestureDetector(
      onTap: () => onTap(reason),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF6B35).withOpacity(0.2)
              : Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[300],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 音声背景用のカスタムペインター
class _AudioBackgroundPainter extends CustomPainter {
  final bool isPlaying;

  _AudioBackgroundPainter({required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // 波紋エフェクト
    if (isPlaying) {
      final center = Offset(size.width / 2, size.height / 2);
      for (int i = 0; i < 3; i++) {
        paint.color =
            SpotLightColors.getSpotlightColor(2).withOpacity(0.1 - (i * 0.03));
        canvas.drawCircle(
          center,
          size.width * 0.3 + (i * 30),
          paint,
        );
      }
    }

    // グラデーション円
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 1.5,
        colors: [
          SpotLightColors.getSpotlightColor(2).withOpacity(0.2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 遅延読み込み関連
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _isCheckingNewContent = false; // 最新コンテンツチェック中フラグ
  bool _noMoreContent = false; // これ以上コンテンツがないフラグ
  static const int _initialLoadCount = 3; // 初回読み込み件数
  static const int _preloadAheadCount = 3; // 現在のページから先読み込みする件数

  // ジェスチャー関連
  double _swipeOffset = 0.0;
  bool _isSpotlighting = false;
  AnimationController? _ambientAnimationController;
  Animation<double>? _ambientOpacityAnimation;

  // 動画プレイヤー関連
  final Map<int, VideoPlayerController?> _videoControllers = {};
  int? _currentPlayingVideo;
  final Set<int> _initializedVideos = {};

  // シークバー関連（動画用）
  bool _isSeeking = false;
  double? _seekPosition; // シーク中の位置（0.0-1.0）
  Timer? _seekBarUpdateTimer; // シークバー更新用タイマー
  Timer? _seekDebounceTimer; // シーク中のデバウンスタイマー

  // シークバー関連（音声用）
  bool _isSeekingAudio = false;
  double? _seekPositionAudio; // シーク中の位置（0.0-1.0）
  Timer? _seekBarUpdateTimerAudio; // シークバー更新用タイマー
  Timer? _seekDebounceTimerAudio; // シーク中のデバウンスタイマー

  // 音声プレイヤー関連
  final Map<int, AudioPlayer?> _audioPlayers = {};
  int? _currentPlayingAudio;
  final Set<int> _initializedAudios = {};

  // アイコンキャッシュ管理（username -> 更新タイムスタンプ）
  final Map<String, int> _iconCacheKeys = {};

  // アイコン更新イベントのリスナー
  StreamSubscription<IconUpdateEvent>? _iconUpdateSubscription;

  // リアルタイム更新用
  Timer? _updateTimer;
  bool _isUpdating = false;
  static const Duration _updateInterval =
      Duration(seconds: 30); // 30秒ごとに更新（頻度を下げる）
  final Set<String> _fetchedContentIds = {}; // 取得済みのコンテンツID

  // ウィジェットの破棄状態を管理
  bool _isDisposed = false;
  String? _lastTargetPostId; // 最後に処理したターゲット投稿ID
  int? _lastNavigationIndex; // 最後のナビゲーションインデックス（動画停止判定用）

  // 視聴履歴記録管理
  String? _lastRecordedPostId; // 最後に記録した投稿ID（重複防止用）

  // 初回起動時のリトライ管理
  int _initialRetryCount = 0;
  static const int _maxInitialRetries = 5; // 最大リトライ回数（初回ログイン後も確実に読み込むため増加）

  // 通報済みコンテンツID管理（同一ユーザーから同一コンテンツへの通報は1回まで）
  final Set<String> _reportedContentIds = <String>{};
  // 通報済みコメントID管理（同一ユーザーから同一コメントへの通報は1回まで）
  // JavaScript変換時の問題を回避するため、finalで直接初期化
  final Set<String> _reportedCommentIds = <String>{};

  @override
  void initState() {
    super.initState();
    // ステータスバーを非表示にする
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // アニメーションコントローラー初期化
    _ambientAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // アニメーション設定
    _ambientOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _ambientAnimationController!,
      curve: Curves.easeInOut,
    ));

    // ライフサイクル監視を追加
    WidgetsBinding.instance.addObserver(this);

    // アイコン更新イベントをリッスン
    _iconUpdateSubscription =
        IconUpdateService().onIconUpdate.listen(_onIconUpdated);

    // バックエンドから投稿を取得
    _fetchPosts();

    // リアルタイム更新を開始
    _startAutoUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // NavigationProviderのtargetPostIdをチェック
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    final targetPostId = navigationProvider.targetPostId;

    if (kDebugMode) {
      debugPrint(
          '🔄 didChangeDependencies: targetPostId=$targetPostId, _lastTargetPostId=$_lastTargetPostId, _isLoading=$_isLoading, _posts.length=${_posts.length}');
    }

    // ターゲット投稿IDが変更された場合、かつ投稿リストが読み込まれている場合
    if (targetPostId != null &&
        targetPostId != _lastTargetPostId &&
        !_isLoading) {
      if (kDebugMode) {
        debugPrint('✅ ターゲット投稿IDが変更されました: $targetPostId');
      }

      _lastTargetPostId = targetPostId;

      // 投稿リストが空の場合は、投稿を取得してからジャンプ
      if (_posts.isEmpty) {
        if (kDebugMode) {
          debugPrint('📝 投稿リストが空なので、先に投稿を取得します');
        }
        _fetchPosts().then((_) {
          if (!_isDisposed && mounted) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (!_isDisposed && mounted) {
                _checkAndJumpToTargetPost();
              }
            });
          }
        });
      } else {
        // 少し遅延させてからジャンプ（画面遷移が完了してから）
        if (kDebugMode) {
          debugPrint('⏳ 投稿リストがあるので、遅延後にジャンプします');
        }
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!_isDisposed && mounted) {
            _checkAndJumpToTargetPost();
          }
        });
      }
    }
  }

  /// バックエンドから投稿を取得（初回読み込み）
  Future<void> _fetchPosts() async {
    try {
      if (kDebugMode) {
        debugPrint('📝 投稿取得を開始（初回: $_initialLoadCount件、startId=1）...');
        if (_initialRetryCount > 0) {
          debugPrint('🔄 リトライ試行: $_initialRetryCount回目');
        }
      }

      // 初回読み込みは必ずID=1から開始
      final posts =
          await PostService.fetchPosts(limit: _initialLoadCount, startId: 1);

      if (!_isDisposed && mounted) {
        // 投稿が空の場合でも、初回起動時は自動リトライを続ける
        if (posts.isEmpty && _initialRetryCount < _maxInitialRetries) {
          _initialRetryCount++;
          final retryDelay =
              Duration(seconds: _initialRetryCount); // 1秒、2秒、3秒と段階的に増やす

          if (kDebugMode) {
            debugPrint(
                '📝 投稿が空です。${retryDelay.inSeconds}秒後に自動リトライします（$_initialRetryCount/$_maxInitialRetries）');
          }

          // リトライ前にローディング状態を維持
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });

          // 遅延後に自動リトライ
          Future.delayed(retryDelay, () {
            if (!_isDisposed && mounted) {
              _fetchPosts();
            }
          });
          return; // リトライするのでここで終了
        }

        // 投稿が取得できた、またはリトライ回数が上限に達した場合
        setState(() {
          _posts = posts;
          _isLoading = false;
          // 投稿が空で、リトライ回数が上限に達した場合のみ「投稿がありません」と表示
          _errorMessage = posts.isEmpty ? '投稿がありません' : null;
          _initialRetryCount = 0; // 成功したらリトライカウントをリセット

          // 読み込んだ件数が要求した件数より少ない場合は、これ以上投稿がない
          _hasMorePosts = posts.length >= _initialLoadCount;

          // 取得済みコンテンツIDを記録
          _fetchedContentIds.clear();
          for (final post in posts) {
            _fetchedContentIds.add(post.id);
            if (kDebugMode) {
              debugPrint('📝 取得済みIDを記録: ${post.id}');
            }
          }
        });

        // 投稿が取得できたら初期表示時に現在のページがメディアの場合は自動再生を開始
        if (_posts.isNotEmpty) {
          _handleMediaPageChange(_currentIndex);

          // 初回読み込み後、現在のページから3つ先までを事前読み込み
          _preloadNextPosts(_currentIndex);

          // ターゲット投稿IDが設定されている場合はジャンプ
          final navigationProvider =
              Provider.of<NavigationProvider>(context, listen: false);
          final targetPostId = navigationProvider.targetPostId;
          if (targetPostId != null) {
            if (kDebugMode) {
              debugPrint('🎯 投稿取得完了後、targetPostIdをチェック: $targetPostId');
            }
            // 少し遅延させてからジャンプ（画面構築が完了してから）
            Future.delayed(const Duration(milliseconds: 200), () {
              if (!_isDisposed && mounted) {
                _checkAndJumpToTargetPost();
              }
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 投稿取得エラー: $e');
      }

      // 初回起動時の自動リトライ（最大3回まで）
      if (_initialRetryCount < _maxInitialRetries && !_isDisposed && mounted) {
        _initialRetryCount++;
        final retryDelay =
            Duration(seconds: _initialRetryCount); // 1秒、2秒、3秒と段階的に増やす

        if (kDebugMode) {
          debugPrint(
              '🔄 ${retryDelay.inSeconds}秒後に自動リトライします（$_initialRetryCount/$_maxInitialRetries）');
        }

        // リトライ前にローディング状態を維持
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        // 遅延後に自動リトライ
        Future.delayed(retryDelay, () {
          if (!_isDisposed && mounted) {
            _fetchPosts();
          }
        });
      } else {
        // リトライ回数が上限に達した場合、エラーメッセージを表示
        if (!_isDisposed && mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '投稿の取得に失敗しました';
            _initialRetryCount = 0; // リトライカウントをリセット
          });
        }
      }
    }
  }

  /// ターゲット投稿IDをチェックしてジャンプ
  Future<void> _checkAndJumpToTargetPost() async {
    if (!mounted) return;

    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    final targetPostId = navigationProvider.targetPostId;

    if (targetPostId == null) return;

    // 既に処理中の場合はスキップ（同じIDの処理が完了するまで待つ）
    if (_lastTargetPostId == targetPostId) {
      if (kDebugMode) {
        debugPrint('⏭️ 既に処理中のターゲット投稿ID: $targetPostId');
      }
      return;
    }

    // 処理開始前に_lastTargetPostIdを設定（重複実行を防ぐ）
    _lastTargetPostId = targetPostId;

    if (kDebugMode) {
      debugPrint('🎯 ターゲット投稿ID: $targetPostId');
    }

    // 現在の投稿リストから探す（文字列として比較）
    final index = _posts
        .indexWhere((post) => post.id.toString() == targetPostId.toString());

    if (kDebugMode) {
      debugPrint(
          '🔍 投稿検索: targetPostId=$targetPostId, 現在の投稿数=${_posts.length}');
      for (int i = 0; i < _posts.length; i++) {
        debugPrint(
            '  [$i] ID=${_posts[i].id} (type: ${_posts[i].id.runtimeType})');
      }
    }

    if (index >= 0) {
      // 見つかった場合でも、完全なデータを再取得して更新する
      // 検索結果から作成された不完全な投稿の可能性があるため
      if (kDebugMode) {
        debugPrint('✅ 投稿が見つかりました: インデックス $index, 投稿ID=${_posts[index].id}');
        debugPrint('  - 既存の投稿のcontentPath: ${_posts[index].contentPath}');
        debugPrint('  - 既存の投稿のmediaUrl: ${_posts[index].mediaUrl}');
      }

      // 完全なデータを再取得
      final updatedPost = await PostService.fetchPostDetail(targetPostId);
      final expectedTitle = navigationProvider.targetPostTitle;

      // 検索結果のタイトルと取得した投稿のタイトルを比較
      if (updatedPost != null &&
          updatedPost.id.toString() == targetPostId.toString()) {
        // タイトルが一致しない場合は、タイトルで検索して正しい投稿を見つける
        if (expectedTitle != null &&
            expectedTitle.isNotEmpty &&
            updatedPost.title != expectedTitle) {
          if (kDebugMode) {
            debugPrint('⚠️ タイトルが一致しません:');
            debugPrint('  - 検索結果のタイトル: $expectedTitle');
            debugPrint('  - 取得した投稿のタイトル: ${updatedPost.title}');
            debugPrint('  - タイトルで検索して正しい投稿を見つけます...');
          }

          // タイトルで検索して正しい投稿を見つける
          final titleMatchIndex = _posts.indexWhere((post) =>
              post.title == expectedTitle &&
              post.id.toString() != targetPostId.toString());

          if (titleMatchIndex >= 0) {
            if (kDebugMode) {
              debugPrint(
                  '✅ タイトルで一致する投稿を見つけました: インデックス $titleMatchIndex, 投稿ID=${_posts[titleMatchIndex].id}');
            }

            // 正しい投稿にジャンプ
            if (_pageController.hasClients) {
              await _pageController.animateToPage(
                titleMatchIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );

              if (kDebugMode) {
                debugPrint('✅ タイトルで一致する投稿にジャンプ完了: インデックス $titleMatchIndex');
              }
            }

            // ターゲット投稿IDをクリア
            navigationProvider.clearTargetPostId();
            _lastTargetPostId = null;
            return;
          } else {
            if (kDebugMode) {
              debugPrint('⚠️ タイトルで一致する投稿が見つかりませんでした');
            }
          }
        }

        if (kDebugMode) {
          debugPrint('✅ 投稿データを更新:');
          debugPrint('  - 更新後のcontentPath: ${updatedPost.contentPath}');
          debugPrint('  - 更新後のmediaUrl: ${updatedPost.mediaUrl}');
          debugPrint('  - 更新後のtype: ${updatedPost.type}');
          debugPrint('  - 更新後のtitle: ${updatedPost.title}');
          if (expectedTitle != null) {
            debugPrint('  - 検索結果のタイトル: $expectedTitle');
            debugPrint('  - タイトル一致: ${updatedPost.title == expectedTitle}');
          }
        }

        // 投稿リスト内の投稿を更新
        // 既存のメディアコントローラーをクリア（新しいメディアを初期化するため）
        final postIndex = index;
        if (_videoControllers.containsKey(postIndex)) {
          final oldController = _videoControllers[postIndex];
          if (oldController != null) {
            await oldController.dispose();
            _videoControllers.remove(postIndex);
            _initializedVideos.remove(postIndex);
            if (kDebugMode) {
              debugPrint('🗑️ 既存の動画コントローラーをクリア: インデックス $postIndex');
            }
          }
        }
        if (_audioPlayers.containsKey(postIndex)) {
          final oldPlayer = _audioPlayers[postIndex];
          if (oldPlayer != null) {
            await oldPlayer.dispose();
            _audioPlayers.remove(postIndex);
            _initializedAudios.remove(postIndex);
            if (kDebugMode) {
              debugPrint('🗑️ 既存の音声プレイヤーをクリア: インデックス $postIndex');
            }
          }
        }

        setState(() {
          _posts[index] = updatedPost;
        });

        // 投稿データを更新した後、再度インデックスを確認
        // setStateの後なので、確実に更新されているはず
        final verifiedIndex = _posts.indexWhere(
            (post) => post.id.toString() == targetPostId.toString());
        if (verifiedIndex >= 0 && verifiedIndex != index) {
          if (kDebugMode) {
            debugPrint('⚠️ インデックスが変更されました: $index -> $verifiedIndex');
          }
          // インデックスが変更された場合は、新しいインデックスを使用
          final actualIndex = verifiedIndex;

          // PageControllerでジャンプ
          if (_pageController.hasClients) {
            await _pageController.animateToPage(
              actualIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );

            if (kDebugMode) {
              debugPrint(
                  '✅ ジャンプ完了: インデックス $actualIndex, 現在の投稿ID=${_posts[actualIndex].id}');
              debugPrint('  - タイトル: ${_posts[actualIndex].title}');
              debugPrint('  - 投稿者: ${_posts[actualIndex].username}');
              debugPrint('  - タイプ: ${_posts[actualIndex].type}');
            }
          }
        } else {
          // インデックスが変更されていない場合
          if (kDebugMode) {
            debugPrint('🔄 投稿データを更新しました: インデックス $index');
            debugPrint('  - タイトル: ${_posts[index].title}');
            debugPrint('  - 投稿者: ${_posts[index].username}');
            debugPrint('  - タイプ: ${_posts[index].type}');
            debugPrint('  - animateToPageのonPageChangedでメディアが初期化されます');
          }

          // PageControllerでジャンプ
          if (_pageController.hasClients) {
            await _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );

            if (kDebugMode) {
              debugPrint(
                  '✅ ジャンプ完了: インデックス $index, 現在の投稿ID=${_posts[index].id}');
            }
          }
        }
      } else {
        // 投稿データの取得に失敗した場合でも、既存の投稿にジャンプ
        if (kDebugMode) {
          debugPrint('⚠️ 投稿データの取得に失敗しましたが、既存の投稿にジャンプします');
        }

        // PageControllerでジャンプ
        if (_pageController.hasClients) {
          await _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );

          if (kDebugMode) {
            debugPrint('✅ ジャンプ完了: インデックス $index, 現在の投稿ID=${_posts[index].id}');
          }
        }
      }

      // ターゲット投稿IDをクリア
      navigationProvider.clearTargetPostId();
      _lastTargetPostId = null;
    } else {
      // 見つからなかった場合は、その投稿を取得して追加
      if (kDebugMode) {
        debugPrint('🔍 投稿が見つかりません。取得を試みます...');
      }

      final expectedTitle = navigationProvider.targetPostTitle;
      final success =
          await _fetchAndJumpToPost(targetPostId, expectedTitle: expectedTitle);

      // 処理完了後、ターゲット投稿IDをクリア
      if (mounted) {
        if (!success) {
          // 投稿取得に失敗した場合、タイトルで検索を試みる
          if (expectedTitle != null && expectedTitle.isNotEmpty) {
            if (kDebugMode) {
              debugPrint('🔍 タイトルで検索を試みます: $expectedTitle');
            }

            final titleMatchIndex =
                _posts.indexWhere((post) => post.title == expectedTitle);
            if (titleMatchIndex >= 0) {
              if (kDebugMode) {
                debugPrint(
                    '✅ タイトルで一致する投稿を見つけました: インデックス $titleMatchIndex, 投稿ID=${_posts[titleMatchIndex].id}');
              }

              if (_pageController.hasClients) {
                await _pageController.animateToPage(
                  titleMatchIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            } else {
              if (kDebugMode) {
                debugPrint('❌ タイトルで一致する投稿が見つかりませんでした');
              }
            }
          }
        }

        navigationProvider.clearTargetPostId();
        _lastTargetPostId = null;
      }
    }
  }

  /// 特定の投稿を取得してジャンプ
  Future<bool> _fetchAndJumpToPost(String postId,
      {String? expectedTitle}) async {
    try {
      // 投稿IDから数値に変換
      final contentId = int.tryParse(postId);
      if (contentId == null) {
        if (kDebugMode) {
          debugPrint('❌ 無効な投稿ID: $postId');
        }
        return false;
      }

      // その投稿を直接取得（PostService.fetchPostDetailを使用）
      final post = await PostService.fetchPostDetail(postId);

      if (kDebugMode) {
        if (post != null) {
          debugPrint('🔍 投稿取得結果: 成功');
          debugPrint('  - 取得した投稿ID: ${post.id} (type: ${post.id.runtimeType})');
          debugPrint('  - 期待する投稿ID: $postId (type: ${postId.runtimeType})');
          debugPrint('  - title: ${post.title}');
          debugPrint('  - type: ${post.type}');
          debugPrint('  - contentPath: ${post.contentPath}');
          debugPrint('  - mediaUrl: ${post.mediaUrl}');
          debugPrint('  - thumbnailUrl: ${post.thumbnailUrl}');
          debugPrint('  - username: ${post.username}');
        } else {
          debugPrint('🔍 投稿取得結果: 失敗（投稿が見つかりません）');
        }
      }

      if (post != null && post.id.toString() == postId.toString()) {
        final targetPost = post;

        if (!_isDisposed && mounted) {
          // 投稿リストに追加（既に存在する場合はスキップ）
          final existingIndex = _posts
              .indexWhere((post) => post.id.toString() == postId.toString());

          if (existingIndex < 0) {
            // 新しい投稿なので、適切な位置に挿入
            // IDが現在の投稿より小さい場合は先頭に、大きい場合は末尾に追加
            final currentFirstId =
                _posts.isNotEmpty ? int.tryParse(_posts.first.id) : null;
            final targetId = int.tryParse(postId) ?? 0;

            setState(() {
              if (currentFirstId != null && targetId < currentFirstId) {
                _posts.insert(0, targetPost);
              } else {
                _posts.add(targetPost);
              }

              // 取得済みコンテンツIDを記録
              _fetchedContentIds.add(postId);
            });

            // 投稿を追加した後、そのインデックスにジャンプ
            // setStateの完了を待ってからジャンプ
            await Future.delayed(const Duration(milliseconds: 50));

            final newIndex = _posts
                .indexWhere((post) => post.id.toString() == postId.toString());
            if (newIndex >= 0 && _pageController.hasClients) {
              if (kDebugMode) {
                debugPrint(
                    '✅ 投稿を追加しました: インデックス $newIndex, 投稿ID=${_posts[newIndex].id}');
              }

              // animateToPageはonPageChangedを自動的に呼び出す
              await _pageController.animateToPage(
                newIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );

              // animateToPageの完了を待ってから、念のためインデックスを確認
              if (mounted) {
                // 再度インデックスを確認（setStateの後なので確実に更新されているはず）
                final finalIndex = _posts.indexWhere(
                    (post) => post.id.toString() == postId.toString());
                if (finalIndex >= 0) {
                  if (_currentIndex != finalIndex) {
                    setState(() {
                      _currentIndex = finalIndex;
                    });
                    _handleMediaPageChange(finalIndex);
                  }

                  if (kDebugMode) {
                    debugPrint(
                        '✅ ジャンプ完了: インデックス $finalIndex, 現在の投稿ID=${_posts[finalIndex].id}');
                  }

                  // ターゲット投稿IDをクリア
                  final navigationProvider =
                      Provider.of<NavigationProvider>(context, listen: false);
                  navigationProvider.clearTargetPostId();
                  _lastTargetPostId = null;

                  return true; // 成功
                } else {
                  if (kDebugMode) {
                    debugPrint('❌ 投稿を追加したが見つかりません: postId=$postId');
                  }
                  return false; // 失敗
                }
              }
            } else {
              if (kDebugMode) {
                debugPrint('❌ 投稿を追加したが見つかりません: postId=$postId');
              }
              return false; // 失敗
            }
          } else {
            // 既に存在する場合はそのインデックスにジャンプ
            if (_pageController.hasClients) {
              if (kDebugMode) {
                debugPrint(
                    '✅ 既存の投稿にジャンプ: インデックス $existingIndex, 投稿ID=${_posts[existingIndex].id}');
              }

              // animateToPageはonPageChangedを自動的に呼び出す
              await _pageController.animateToPage(
                existingIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );

              // animateToPageの完了を待ってから、念のためインデックスを確認
              if (mounted) {
                if (_currentIndex != existingIndex) {
                  setState(() {
                    _currentIndex = existingIndex;
                  });
                  _handleMediaPageChange(existingIndex);
                }

                if (kDebugMode) {
                  debugPrint(
                      '✅ ジャンプ完了: インデックス $existingIndex, 現在の投稿ID=${_posts[existingIndex].id}');
                }

                // ターゲット投稿IDをクリア
                final navigationProvider =
                    Provider.of<NavigationProvider>(context, listen: false);
                navigationProvider.clearTargetPostId();
                _lastTargetPostId = null;

                return true; // 成功
              }
            }
            return true; // 成功（既存の投稿にジャンプ）
          }
        }
        return false; // 失敗（投稿が見つからない）
      } else {
        if (kDebugMode) {
          debugPrint('❌ 投稿の取得に失敗しました: $postId');
        }
        return false; // 失敗
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 投稿取得エラー: $e');
      }
      return false; // 失敗
    }
  }

  /// 再読み込みボタンから呼び出される処理
  Future<void> _reloadMoreContent() async {
    if (_isLoadingMore) return;

    _isLoadingMore = true;

    try {
      if (kDebugMode) {
        debugPrint('🔄 再読み込み開始: 最後の投稿IDから次のコンテンツを取得');
      }

      // 最後の投稿のIDから次のIDを計算
      final lastPost = _posts.last;
      final lastId = int.tryParse(lastPost.id) ?? 0;
      final nextStartId = lastId + 1;

      // 次のコンテンツを取得（3件）
      final morePosts = await PostService.fetchPosts(
        limit: _preloadAheadCount,
        startId: nextStartId,
      );

      if (!_isDisposed && mounted) {
        if (morePosts.isEmpty) {
          // 追加のコンテンツがない場合
          if (kDebugMode) {
            debugPrint('⚠️ 追加のコンテンツがありません');
          }
          _showAllContentViewedDialog();
        } else {
          // 重複を防ぐために、既に取得済みの投稿を除外
          final newPosts = morePosts
              .where((post) => !_fetchedContentIds.contains(post.id))
              .toList();

          if (newPosts.isEmpty) {
            // 全て重複していた場合
            if (kDebugMode) {
              debugPrint('⚠️ 全て重複していたため、次のIDから再試行');
            }
            // 次のIDから再試行
            final nextNextStartId = nextStartId + _preloadAheadCount;
            final retryPosts = await PostService.fetchPosts(
              limit: _preloadAheadCount,
              startId: nextNextStartId,
            );

            if (retryPosts.isEmpty) {
              _showAllContentViewedDialog();
            } else {
              final retryNewPosts = retryPosts
                  .where((post) => !_fetchedContentIds.contains(post.id))
                  .toList();

              if (retryNewPosts.isEmpty) {
                _showAllContentViewedDialog();
              } else {
                setState(() {
                  _posts.addAll(retryNewPosts);
                  _noMoreContent = false;
                  _hasMorePosts = retryNewPosts.length >= _preloadAheadCount;

                  // 取得済みコンテンツIDを記録
                  for (final post in retryNewPosts) {
                    _fetchedContentIds.add(post.id);
                  }
                });

                if (kDebugMode) {
                  debugPrint('✅ 再読み込み完了: ${retryNewPosts.length}件追加');
                }
              }
            }
          } else {
            // 新しいコンテンツがある場合
            setState(() {
              _posts.addAll(newPosts);
              _noMoreContent = false;
              _hasMorePosts = newPosts.length >= _preloadAheadCount;

              // 取得済みコンテンツIDを記録
              for (final post in newPosts) {
                _fetchedContentIds.add(post.id);
              }
            });

            if (kDebugMode) {
              debugPrint('✅ 再読み込み完了: ${newPosts.length}件追加');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 再読み込みエラー: $e');
      }
      if (!_isDisposed && mounted) {
        _showAllContentViewedDialog();
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  /// すべてのコンテンツを視聴済みのダイアログを表示
  void _showAllContentViewedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'すべてのコンテンツを視聴済み',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'これ以上表示できるコンテンツはありません。',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFFFF6B35)),
            ),
          ),
        ],
      ),
    );
  }

  /// 最新のコンテンツをチェックして先頭に追加
  Future<void> _checkForNewContent() async {
    // 既にチェック中の場合はスキップ
    if (_isCheckingNewContent || _noMoreContent) {
      return;
    }

    _isCheckingNewContent = true;

    try {
      if (kDebugMode) {
        debugPrint('🔄 最新コンテンツをチェック中...');
      }

      // 最新のコンテンツを取得（ID=1から3件）
      final newPosts = await PostService.fetchPosts(
        limit: _initialLoadCount,
        startId: 1,
      );

      if (!_isDisposed && mounted) {
        if (newPosts.isEmpty) {
          // 最新のコンテンツがない場合
          if (kDebugMode) {
            debugPrint('⚠️ 最新のコンテンツがありません');
          }
          setState(() {
            _noMoreContent = true;
            _hasMorePosts = false;
          });
        } else {
          // 最新のコンテンツがある場合、既存の投稿と比較
          final existingIds = _posts.map((p) => p.id.toString()).toSet();
          final newContentIds = newPosts.map((p) => p.id.toString()).toSet();

          // 新しいコンテンツがあるかチェック
          final hasNewContent =
              newContentIds.any((id) => !existingIds.contains(id));

          if (hasNewContent) {
            // 新しいコンテンツがある場合は先頭に追加
            final newPostsToAdd = newPosts
                .where((p) => !existingIds.contains(p.id.toString()))
                .toList();

            if (kDebugMode) {
              debugPrint('✅ 新しいコンテンツが見つかりました: ${newPostsToAdd.length}件');
            }

            setState(() {
              // 新しいコンテンツを先頭に追加
              _posts.insertAll(0, newPostsToAdd);
              _noMoreContent = false;
              _hasMorePosts = true;

              // 取得済みコンテンツIDを更新
              for (final post in newPostsToAdd) {
                _fetchedContentIds.add(post.id);
              }
            });

            // 新しいコンテンツの最初のページに自動的にスクロール
            if (newPostsToAdd.isNotEmpty && _pageController.hasClients) {
              await _pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          } else {
            // 新しいコンテンツがない場合
            if (kDebugMode) {
              debugPrint('⚠️ 新しいコンテンツはありません');
            }
            setState(() {
              _noMoreContent = true;
              _hasMorePosts = false;
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 最新コンテンツチェックエラー: $e');
      }
      // エラーが発生した場合は、次回再試行できるようにフラグをリセット
      if (!_isDisposed && mounted) {
        setState(() {
          _isCheckingNewContent = false;
        });
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isCheckingNewContent = false;
        });
      }
    }
  }

  /// 現在のページから3つ先までを事前読み込み
  Future<void> _preloadNextPosts(int currentIndex) async {
    if (_isLoadingMore || !_hasMorePosts || _posts.isEmpty) return;

    // 現在のページから3つ先まで既に読み込まれているかチェック
    final targetIndex = currentIndex + _preloadAheadCount;
    if (targetIndex < _posts.length) {
      // 既に読み込まれている場合はスキップ
      if (kDebugMode) {
        debugPrint(
            '⏭️ 既に読み込み済み: 現在のインデックス=$currentIndex, 目標インデックス=$targetIndex, 現在の投稿数=${_posts.length}');
      }
      return;
    }

    // 必要な投稿数を計算
    final neededCount = targetIndex - _posts.length + 1;
    if (neededCount <= 0) return;

    _isLoadingMore = true;

    try {
      // 最後の投稿のIDから次のIDを計算
      final lastPost = _posts.last;
      final lastId = int.tryParse(lastPost.id) ?? 0;
      final nextStartId = lastId + 1;

      if (kDebugMode) {
        debugPrint(
            '📝 事前読み込み開始: 現在のインデックス=$currentIndex, 最後の投稿ID=$lastId, startId=$nextStartId, 必要件数=$neededCount');
        debugPrint('📝 取得済みID: ${_fetchedContentIds.toList()}');
      }

      // 必要な件数分を読み込む（常に3件読み込む）
      final loadCount = _preloadAheadCount;

      // 次のIDから追加読み込み
      final morePosts = await PostService.fetchPosts(
        limit: loadCount,
        startId: nextStartId,
      );

      if (!_isDisposed && mounted && morePosts.isNotEmpty) {
        // 重複を防ぐために、既に取得済みの投稿を除外
        final newPosts = morePosts
            .where((post) => !_fetchedContentIds.contains(post.id))
            .toList();

        if (kDebugMode) {
          debugPrint(
              '📝 取得した投稿: ${morePosts.length}件、重複除外後: ${newPosts.length}件');
          for (final post in newPosts) {
            debugPrint('  - ID: ${post.id}, タイトル: ${post.title}');
          }
        }

        if (newPosts.isNotEmpty) {
          setState(() {
            _posts.addAll(newPosts);

            // 取得済みコンテンツIDを記録
            for (final post in newPosts) {
              _fetchedContentIds.add(post.id);
            }

            // 読み込んだ件数が要求した件数より少ない場合は、これ以上投稿がない
            _hasMorePosts = newPosts.length >= loadCount;
          });

          if (kDebugMode) {
            debugPrint(
                '📝 事前読み込み完了: ${newPosts.length}件（合計: ${_posts.length}件）');
          }
        } else {
          // 全て重複していた場合は、次のIDから再試行
          if (kDebugMode) {
            debugPrint('📝 全て重複していたため、次のIDから再試行');
          }
          setState(() {
            _hasMorePosts = true; // 再試行のためtrueに設定
          });
        }
      } else {
        setState(() {
          _hasMorePosts = false;
        });

        if (kDebugMode) {
          debugPrint('📝 これ以上投稿がありません');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📝 事前読み込みエラー: $e');
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  /// 手動で投稿を更新（プルリフレッシュ）
  Future<void> _refreshPosts() async {
    if (_isUpdating) return;

    _isUpdating = true;

    // 手動再試行の場合はリトライカウントをリセット
    _initialRetryCount = 0;

    try {
      // 初回読み込みと同じ件数を取得
      final posts = await PostService.fetchPosts(limit: _initialLoadCount);

      if (!_isDisposed && mounted && posts.isNotEmpty) {
        setState(() {
          _posts = posts;
          _errorMessage = null;
          _hasMorePosts = posts.length >= _initialLoadCount;
          _initialRetryCount = 0; // リトライカウントをリセット

          // 取得済みコンテンツIDを更新
          _fetchedContentIds.clear();
          for (final post in posts) {
            _fetchedContentIds.add(post.id);
          }
        });

        // 現在のページがメディアの場合は自動再生を開始
        if (_posts.isNotEmpty && _currentIndex < _posts.length) {
          _handleMediaPageChange(_currentIndex);
        }
      }
    } catch (e) {
      // エラーは無視（ログも出力しない）
    } finally {
      _isUpdating = false;
    }
  }

  /// アイコンURLにキャッシュキーを追加（1時間に1回の読み込み制限）
  /// 同じURLを使用することで、CachedNetworkImageのキャッシュが効く
  String _getCachedIconUrl(String? userIconUrl, String userIconPath) {
    String iconUrl;
    if (userIconUrl != null && userIconUrl.isNotEmpty) {
      iconUrl = userIconUrl;
    } else if (userIconPath.isNotEmpty) {
      // userIconPathの形式を確認
      // 完全なURL（http://またはhttps://で始まる）の場合はそのまま使用
      if (userIconPath.startsWith('http://') ||
          userIconPath.startsWith('https://')) {
        iconUrl = userIconPath;
      }
      // 相対パス（/icon/で始まる）の場合はbackendUrlを追加
      else if (userIconPath.startsWith('/icon/')) {
        iconUrl = '${AppConfig.backendUrl}$userIconPath';
      }
      // 相対パス（/で始まるが/icon/でない）の場合もbackendUrlを追加
      else if (userIconPath.startsWith('/')) {
        iconUrl = '${AppConfig.backendUrl}$userIconPath';
      }
      // ファイル名のみの場合は/icon/を追加
      else {
        iconUrl = '${AppConfig.backendUrl}/icon/$userIconPath';
      }
    } else {
      iconUrl = '${AppConfig.backendUrl}/icon/default_icon.jpg';
    }

    // 1時間ごとのキャッシュキーを追加（YYYYMMDDHH形式）
    final now = DateTime.now();
    final cacheKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}';

    // URLにキャッシュキーを追加
    final separator = iconUrl.contains('?') ? '&' : '?';
    return '$iconUrl$separator cache=$cacheKey';
  }

  /// アイコン更新イベントを受信したときの処理
  void _onIconUpdated(IconUpdateEvent event) async {
    if (!mounted) return;

    if (kDebugMode) {
      debugPrint(
          '🔔 アイコン更新を検知: ${event.username} -> ${event.iconPath ?? "default"}');
    }

    // 古いアイコンURLをキャッシュから削除
    final oldUrls = <String>[];
    for (int i = 0; i < _posts.length; i++) {
      if (_posts[i].username == event.username &&
          _posts[i].userIconUrl != null) {
        final oldUrl = _posts[i].userIconUrl!;
        if (!oldUrls.contains(oldUrl)) {
          oldUrls.add(oldUrl);
        }
      }
    }

    // すべての古いアイコンURLのキャッシュをクリア
    for (final oldUrl in oldUrls) {
      try {
        // キャッシュキー付きURLも含めてクリア
        await CachedNetworkImage.evictFromCache(oldUrl);

        // キャッシュキーを除いたベースURLもクリア
        final baseUrl = oldUrl.split('?').first.split('&').first;
        await CachedNetworkImage.evictFromCache(baseUrl);

        // iconPathに関連するすべてのキャッシュキー付きURLもクリア
        // キャッシュキーはiconPathなので、iconPathを含むすべてのURLをクリア
        // ここでは古いURLのパターンをクリアするため、baseUrlとoldUrlをクリア
        final urlPatterns = [
          baseUrl,
          oldUrl,
          '$baseUrl?cache=${event.iconPath ?? ""}',
          '$baseUrl&cache=${event.iconPath ?? ""}',
        ];
        for (final pattern in urlPatterns) {
          try {
            await CachedNetworkImage.evictFromCache(pattern);
            final cacheManager = DefaultCacheManager();
            await cacheManager.removeFile(pattern);
          } catch (e) {
            // エラーは無視
          }
        }

        if (kDebugMode) {
          debugPrint('🗑️ 古いアイコンをキャッシュから削除: $oldUrl');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ キャッシュ削除エラー: $e');
        }
      }
    }

    // 新しいアイコンURLを構築
    // iconPathの形式を確認して処理
    String newIconPath;
    String? baseIconUrl;

    if (event.iconPath == null || event.iconPath!.isEmpty) {
      newIconPath = 'default_icon.jpg';
      baseIconUrl = '${AppConfig.backendUrl}/icon/$newIconPath';
    } else if (event.iconPath!.startsWith('http://') ||
        event.iconPath!.startsWith('https://')) {
      // 完全なURLの場合はそのまま使用（CloudFront URLなど）
      baseIconUrl = event.iconPath!;
      newIconPath = event.iconPath!;
    } else if (event.iconPath!.startsWith('/icon/')) {
      // /icon/で始まる場合は、そのまま使用
      baseIconUrl = '${AppConfig.backendUrl}${event.iconPath}';
      newIconPath = event.iconPath!;
    } else if (event.iconPath!.startsWith('/')) {
      // /で始まるが/icon/でない場合は、そのまま使用（バックエンドのパス形式）
      baseIconUrl = '${AppConfig.backendUrl}${event.iconPath}';
      newIconPath = event.iconPath!;
    } else {
      // ファイル名のみの場合は/icon/を追加
      newIconPath = event.iconPath!;
      baseIconUrl = '${AppConfig.backendUrl}/icon/$newIconPath';
    }

    // キャッシュキーを現在時刻に更新（強制的に再読み込み）
    final now = DateTime.now();
    final cacheKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final separator = baseIconUrl.contains('?') ? '&' : '?';
    final newIconUrl = '$baseIconUrl${separator}cache=$cacheKey';

    // 新しいアイコンURLのキャッシュもクリア（確実に再読み込み）
    try {
      // キャッシュキー付きURLをクリア
      await CachedNetworkImage.evictFromCache(newIconUrl);

      // キャッシュキーを除いたベースURLもクリア
      final baseUrl = baseIconUrl.split('?').first.split('&').first;
      await CachedNetworkImage.evictFromCache(baseUrl);

      // DefaultCacheManagerでもクリア
      try {
        final cacheManager = DefaultCacheManager();
        await cacheManager.removeFile(newIconUrl);
        await cacheManager.removeFile(baseUrl);
      } catch (e) {
        // エラーは無視
      }

      // DefaultCacheManagerでもクリア
      try {
        final cacheManager = DefaultCacheManager();
        await cacheManager.removeFile(newIconUrl);
        await cacheManager.removeFile(baseUrl);
      } catch (e) {
        // エラーは無視
      }

      // iconPathに関連するすべてのキャッシュキー付きURLもクリア
      // キャッシュキーはiconPathなので、iconPathを含むすべてのURLをクリア
      final urlPatterns = [
        baseUrl,
        newIconUrl,
        '$baseUrl?cache=$newIconPath',
        '$baseUrl&cache=$newIconPath',
      ];
      for (final pattern in urlPatterns) {
        try {
          await CachedNetworkImage.evictFromCache(pattern);
          final cacheManager = DefaultCacheManager();
          await cacheManager.removeFile(pattern);
        } catch (e) {
          // エラーは無視
        }
      }

      if (kDebugMode) {
        debugPrint('🗑️ 新しいアイコンURLのキャッシュもクリア: $newIconUrl');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 新しいアイコンキャッシュクリアエラー: $e');
      }
    }

    // アイコンキャッシュキーを更新（タイムスタンプを変更してウィジェットを再構築）
    if (mounted) {
      setState(() {
        // キャッシュキーを現在時刻のミリ秒に更新（確実に再構築）
        _iconCacheKeys[event.username] = DateTime.now().millisecondsSinceEpoch;

        // 投稿リスト内のアイコンURLを更新
        for (int i = 0; i < _posts.length; i++) {
          if (_posts[i].username == event.username) {
            if (kDebugMode) {
              debugPrint('🔄 アイコンURL更新: ${_posts[i].username} -> $newIconUrl');
            }

            _posts[i] = Post(
              id: _posts[i].id,
              userId: _posts[i].userId,
              username: _posts[i].username,
              userIconPath: newIconPath,
              userIconUrl: newIconUrl,
              title: _posts[i].title,
              content: _posts[i].content,
              contentPath: _posts[i].contentPath,
              type: _posts[i].type,
              mediaUrl: _posts[i].mediaUrl,
              thumbnailUrl: _posts[i].thumbnailUrl,
              likes: _posts[i].likes,
              playNum: _posts[i].playNum,
              link: _posts[i].link,
              comments: _posts[i].comments,
              shares: _posts[i].shares,
              isSpotlighted: _posts[i].isSpotlighted,
              isText: _posts[i].isText,
              nextContentId: _posts[i].nextContentId,
              createdAt: _posts[i].createdAt,
            );
          }
        }
      });

      // 少し待ってから再度再構築（サーバー側の処理完了を待つ）
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        setState(() {
          // 再度キャッシュキーを更新（確実に再読み込み）
          _iconCacheKeys[event.username] =
              DateTime.now().millisecondsSinceEpoch;
        });

        if (kDebugMode) {
          debugPrint('🔄 ホーム画面のアイコンを再構築しました（確認）');
        }
      }
    }
  }

  /// リアルタイム更新を開始
  void _startAutoUpdate() {
    _updateTimer = Timer.periodic(_updateInterval, (timer) {
      if (!_isDisposed && mounted) {
        _updatePostsInBackground();
      }
    });
  }

  /// バックグラウンドで投稿を更新（新規投稿のチェックのみ）
  Future<void> _updatePostsInBackground() async {
    if (_isUpdating || _isLoading) return;

    _isUpdating = true;

    try {
      // 最初の1件だけ取得して新規投稿をチェック
      final posts = await PostService.fetchPosts(limit: 1);

      if (!_isDisposed && mounted && posts.isNotEmpty) {
        final newPost = posts.first;

        // 既に取得済みのコンテンツIDかチェック
        if (!_fetchedContentIds.contains(newPost.id)) {
          // 新規投稿を先頭に追加
          setState(() {
            _posts.insert(0, newPost);
            _fetchedContentIds.add(newPost.id);
          });
        }
      }
    } catch (e) {
      // エラーは無視（ログも出力しない）
    } finally {
      _isUpdating = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    // リアルタイム更新を停止
    _updateTimer?.cancel();
    _seekBarUpdateTimer?.cancel();
    _seekDebounceTimer?.cancel();
    _seekBarUpdateTimerAudio?.cancel();
    _seekDebounceTimerAudio?.cancel();

    // アイコン更新イベントのリスナーを解除
    _iconUpdateSubscription?.cancel();

    // ライフサイクル監視を解除
    WidgetsBinding.instance.removeObserver(this);

    _pageController.dispose();
    _ambientAnimationController?.dispose();

    // 動画プレイヤーのリソース解放
    for (final controller in _videoControllers.values) {
      controller?.dispose();
    }
    _videoControllers.clear();
    _initializedVideos.clear();

    // 音声プレイヤーのリソース解放
    for (final player in _audioPlayers.values) {
      player?.dispose();
    }
    _audioPlayers.clear();
    _initializedAudios.clear();

    // ステータスバーを表示に戻す
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // アプリがバックグラウンドに行った時は音声/動画を一時停止
        if (_currentPlayingVideo != null) {
          final controller = _videoControllers[_currentPlayingVideo];
          if (controller != null && controller.value.isInitialized) {
            controller.pause();
          }
        }
        if (_currentPlayingAudio != null) {
          final player = _audioPlayers[_currentPlayingAudio];
          if (player != null) {
            player.pause();
          }
        }
        // リアルタイム更新を停止
        _updateTimer?.cancel();
        break;
      case AppLifecycleState.resumed:
        // アプリがフォアグラウンドに戻った時は再生
        if (_posts.isNotEmpty &&
            _currentIndex < _posts.length &&
            _posts[_currentIndex].postType == PostType.video &&
            _currentPlayingVideo != null) {
          final controller = _videoControllers[_currentPlayingVideo];
          if (controller != null && controller.value.isInitialized) {
            controller.play();
          }
        }
        if (_posts.isNotEmpty &&
            _currentIndex < _posts.length &&
            _posts[_currentIndex].postType == PostType.audio &&
            _currentPlayingAudio != null) {
          final player = _audioPlayers[_currentPlayingAudio];
          if (player != null) {
            player.play();
          }
        }
        // リアルタイム更新を再開
        _startAutoUpdate();
        // 即座に更新を実行
        _updatePostsInBackground();
        break;
      case AppLifecycleState.hidden:
        // 何もしない
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // NavigationProviderのtargetPostIdを監視
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, child) {
        // ナビゲーションインデックスを初期化（初回のみ）
        if (_lastNavigationIndex == null) {
          _lastNavigationIndex = navigationProvider.currentIndex;
        }

        // ナビゲーションインデックスが変更された場合、動画/音声の再生を制御
        final currentNavIndex = navigationProvider.currentIndex;
        if (_lastNavigationIndex != currentNavIndex && mounted) {
          final previousIndex = _lastNavigationIndex;
          _lastNavigationIndex = currentNavIndex;

          // 次のフレームで実行（build中にsetStateを呼ばないように）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _lastNavigationIndex == navigationProvider.currentIndex) {
              if (currentNavIndex == 0) {
                // HomeScreenが表示された場合、現在のコンテンツを再生
                _resumeCurrentMedia();
              } else if (previousIndex == 0) {
                // HomeScreenから他の画面に遷移した場合、動画/音声を停止
                _pauseAllMedia();
              }
            }
          });
        }

        // targetPostIdが変更された場合、ジャンプ処理を実行
        final targetPostId = navigationProvider.targetPostId;
        if (targetPostId != null &&
            targetPostId != _lastTargetPostId &&
            !_isLoading &&
            mounted) {
          if (kDebugMode) {
            debugPrint('🔄 build内でターゲット投稿IDを検出: $targetPostId');
          }

          // 次のフレームで実行（build中にsetStateを呼ばないように）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && targetPostId == navigationProvider.targetPostId) {
              // _checkAndJumpToTargetPost内で_lastTargetPostIdを設定するため、ここでは設定しない
              _checkAndJumpToTargetPost();
            }
          });
        }

        return _buildScaffold(context, navigationProvider);
      },
    );
  }

  Widget _buildScaffold(
      BuildContext context, NavigationProvider navigationProvider) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
              ),
            )
          : _errorMessage != null
              ? RefreshIndicator(
                  onRefresh: _refreshPosts,
                  color: const Color(0xFFFF6B35),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white70,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                // 手動再試行の場合はリトライカウントをリセット
                                _initialRetryCount = 0;
                                _fetchPosts();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                              ),
                              child: const Text('再試行'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : _posts.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _refreshPosts,
                      color: const Color(0xFFFF6B35),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.post_add,
                                  size: 64,
                                  color: Colors.white38,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '投稿がありません',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '引き下げて更新',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : GestureDetector(
                      // 「表示できるコンテンツはありません」画面では右スワイプを無効化
                      onPanUpdate:
                          (_currentIndex >= _posts.length && _noMoreContent)
                              ? null
                              : _handlePanUpdate,
                      onPanEnd:
                          (_currentIndex >= _posts.length && _noMoreContent)
                              ? null
                              : _handlePanEnd,
                      child: Stack(
                        children: [
                          // メイン投稿表示（不透明な背景で完全に覆う）
                          Positioned.fill(
                            child: Transform.translate(
                              offset:
                                  Offset(_swipeOffset * 0.3, 0), // スワイプに応じてズレ
                              child: Transform.rotate(
                                angle: _swipeOffset * 0.001, // スワイプに応じて左下を中心に回転
                                alignment: Alignment.bottomLeft, // 左下を中心に回転
                                child: Container(
                                  color: Colors.black, // 不透明な背景を追加
                                  child: PageView.builder(
                                    controller: _pageController,
                                    scrollDirection: Axis.vertical, // 縦スクロール
                                    // 大量コンテンツ対応：ビューポート範囲を制限
                                    allowImplicitScrolling: false,
                                    onPageChanged: (index) {
                                      if (kDebugMode) {
                                        debugPrint(
                                            '📄 onPageChanged: インデックス $index, 投稿数=${_posts.length}');
                                        if (index < _posts.length) {
                                          debugPrint(
                                              '  - 投稿ID: ${_posts[index].id}');
                                          debugPrint(
                                              '  - タイトル: ${_posts[index].title}');
                                          debugPrint(
                                              '  - 投稿者: ${_posts[index].username}');
                                          debugPrint(
                                              '  - タイプ: ${_posts[index].type}');
                                        }
                                      }

                                      setState(() {
                                        _currentIndex = index;
                                        _resetSpotlightState();
                                        _handleMediaPageChange(index);
                                      });

                                      // 最後のページに到達した場合は最新コンテンツをチェック
                                      if (index >= _posts.length - 1 &&
                                          !_noMoreContent) {
                                        _checkForNewContent();
                                      }

                                      // 現在のページから3つ先までを事前読み込み
                                      _preloadNextPosts(index);
                                    },
                                    itemCount: _hasMorePosts && !_noMoreContent
                                        ? _posts.length + 1
                                        : _posts.length +
                                            (_noMoreContent ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      // 最後の項目
                                      if (index >= _posts.length) {
                                        if (_noMoreContent) {
                                          // これ以上コンテンツがない場合はメッセージを表示
                                          return Container(
                                            color: Colors.black,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.inbox_outlined,
                                                    color: Colors.white38,
                                                    size: 64,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    '表示できるコンテンツはありません',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 32),
                                                  ElevatedButton.icon(
                                                    onPressed: () =>
                                                        _reloadMoreContent(),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFFFF6B35),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 24,
                                                        vertical: 12,
                                                      ),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                    ),
                                                    icon: const Icon(
                                                      Icons.refresh,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    label: const Text(
                                                      '再読み込み',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        } else {
                                          // ローディングインジケーター
                                          return Container(
                                            color: Colors.black,
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xFFFF6B35),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                      return _buildPostContent(_posts[index]);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // スポットライトアンビエントライティング（投稿の上に表示）
                          if (_isSpotlighting &&
                              _ambientOpacityAnimation != null)
                            AnimatedBuilder(
                              animation: _ambientOpacityAnimation!,
                              builder: (context, child) {
                                return Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: Alignment.center,
                                        radius: 1.5,
                                        colors: [
                                          SpotLightColors.getSpotlightColor(0)
                                              .withOpacity(0.3 *
                                                  _ambientOpacityAnimation!
                                                      .value),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                          // 下部の投稿者情報とコントロール
                          if (_posts.isNotEmpty &&
                              _currentIndex < _posts.length)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child:
                                  _buildBottomControls(_posts[_currentIndex]),
                            ),

                          // 右下のコントロールボタン
                          if (_posts.isNotEmpty &&
                              _currentIndex < _posts.length)
                            Positioned(
                              bottom: 120,
                              right: 20,
                              child: _buildRightBottomControls(
                                  _posts[_currentIndex]),
                            ),

                          // 右上の通報ボタン（自分の投稿以外）
                          if (_posts.isNotEmpty &&
                              _currentIndex < _posts.length)
                            _buildReportButton(_posts[_currentIndex]),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildPostContent(Post post) {
    switch (post.postType) {
      case PostType.video:
        return _buildVideoContent(post);
      case PostType.image:
        return _buildImageContent(post);
      case PostType.text:
        return _buildTextContent(post);
      case PostType.audio:
        return _buildAudioContent(post);
    }
  }

  Widget _buildVideoContent(Post post) {
    final postIndex = _posts.indexOf(post);
    final controller = _videoControllers[postIndex];

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          // 動画プレイヤー
          if (controller != null && controller.value.isInitialized)
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio.isFinite &&
                          controller.value.aspectRatio > 0
                      ? controller.value.aspectRatio
                      : 16 / 9, // デフォルトのアスペクト比
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else
            // 動画初期化中またはサムネイル表示
            Stack(
              children: [
                // 背景色
                Container(
                  color: Colors.grey[900],
                ),
                // サムネイル画像
                if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      post.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        if (kDebugMode) {
                          debugPrint('❌ サムネイル読み込みエラー: ${post.thumbnailUrl}');
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                // 再生ボタン
                const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
                // 動画初期化中のローディング表示
                if (postIndex == _currentIndex &&
                    post.postType == PostType.video &&
                    !_initializedVideos.contains(postIndex))
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                  ),
              ],
            ),

          // タップで一時停止/再生、シークバー表示
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (controller != null && controller.value.isInitialized) {
                  // シーク中でない場合は一時停止/再生
                  if (!_isSeeking) {
                    if (controller.value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  }
                } else if (postIndex == _currentIndex &&
                    post.postType == PostType.video) {
                  // 初期化されていない場合は初期化を開始
                  _initializeVideoController(postIndex);
                }
              },
              onHorizontalDragStart: (details) {
                if (controller != null &&
                    controller.value.isInitialized &&
                    postIndex == _currentIndex) {
                  _startSeeking(controller);
                }
              },
              onHorizontalDragUpdate: (details) {
                if (controller != null && controller.value.isInitialized) {
                  if (!_isSeeking) {
                    _startSeeking(controller);
                  }
                  _updateSeeking(details, controller);
                }
              },
              onHorizontalDragEnd: (details) {
                if (_isSeeking &&
                    controller != null &&
                    controller.value.isInitialized) {
                  _endSeeking(controller);
                }
              },
            ),
          ),

          // シークバー（動画が初期化されている場合は常に表示）
          if (postIndex == _currentIndex &&
              controller != null &&
              controller.value.isInitialized)
            _buildSeekBar(controller),
        ],
      ),
    );
  }

  /// シーク開始
  void _startSeeking(VideoPlayerController controller) {
    if (!controller.value.isInitialized) return;

    // シークバー更新タイマーを一時停止
    _seekBarUpdateTimer?.cancel();

    // 動画を一時停止（シーク中は再生を停止）
    final wasPlaying = controller.value.isPlaying;
    if (wasPlaying) {
      controller.pause();
    }

    setState(() {
      _isSeeking = true;
      _seekPosition = controller.value.position.inMilliseconds.toDouble() /
          controller.value.duration.inMilliseconds.toDouble();
    });

    if (kDebugMode) {
      debugPrint(
          '🎯 シーク開始: ${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}');
    }
  }

  /// シーク中
  void _updateSeeking(
      DragUpdateDetails details, VideoPlayerController controller) {
    if (!controller.value.isInitialized || _seekPosition == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final dragDelta = details.delta.dx;
    final dragRatio = dragDelta / screenWidth;

    setState(() {
      _seekPosition = _seekPosition! + dragRatio;
      _seekPosition = _seekPosition!.clamp(0.0, 1.0);
    });

    // デバウンス処理：100msごとに動画の再生位置を更新
    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (_seekPosition != null && controller.value.isInitialized) {
        final targetPosition = Duration(
          milliseconds:
              (_seekPosition! * controller.value.duration.inMilliseconds)
                  .round(),
        );
        controller.seekTo(targetPosition);

        if (kDebugMode) {
          debugPrint(
              '🎯 シーク位置更新: ${_formatDuration(targetPosition)} / ${_formatDuration(controller.value.duration)} (progress: ${_seekPosition!.toStringAsFixed(3)})');
        }
      }
    });
  }

  /// シーク終了
  void _endSeeking(VideoPlayerController controller) {
    if (!controller.value.isInitialized || _seekPosition == null) return;

    // デバウンスタイマーをキャンセルして、即座に最終位置に移動
    _seekDebounceTimer?.cancel();

    final targetPosition = Duration(
      milliseconds:
          (_seekPosition! * controller.value.duration.inMilliseconds).round(),
    );

    // 動画の再生位置を変更
    controller.seekTo(targetPosition).then((_) {
      // シーク前が再生中だった場合は再開
      // ただし、シーク中は一時停止しているので、常に再生を再開
      if (!_isDisposed && mounted) {
        controller.play();
      }
    });

    if (kDebugMode) {
      debugPrint(
          '🎯 シーク終了: ${_formatDuration(targetPosition)} / ${_formatDuration(controller.value.duration)}');
    }

    setState(() {
      _isSeeking = false;
      _seekPosition = null;
    });

    // シークバー更新タイマーを再開
    _startSeekBarUpdateTimer();
  }

  /// 音声シーク開始
  void _startSeekingAudio(AudioPlayer player) {
    if (player.duration == null) return;

    // シークバー更新タイマーを一時停止
    _seekBarUpdateTimerAudio?.cancel();

    // 音声を一時停止（シーク中は再生を停止）
    final wasPlaying = player.playing;
    if (wasPlaying) {
      player.pause();
    }

    setState(() {
      _isSeekingAudio = true;
      final currentPosition = player.position;
      final duration = player.duration ?? Duration.zero;
      if (duration.inMilliseconds > 0) {
        _seekPositionAudio = currentPosition.inMilliseconds.toDouble() /
            duration.inMilliseconds.toDouble();
      } else {
        _seekPositionAudio = 0.0;
      }
    });

    if (kDebugMode) {
      debugPrint(
          '🎵 音声シーク開始: ${_formatDuration(player.position)} / ${_formatDuration(player.duration ?? Duration.zero)}');
    }
  }

  /// 音声シーク中
  void _updateSeekingAudio(DragUpdateDetails details, AudioPlayer player) {
    if (player.duration == null || _seekPositionAudio == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final dragDelta = details.delta.dx;
    final dragRatio = dragDelta / screenWidth;

    setState(() {
      _seekPositionAudio = _seekPositionAudio! + dragRatio;
      _seekPositionAudio = _seekPositionAudio!.clamp(0.0, 1.0);
    });

    // デバウンス処理：100msごとに音声の再生位置を更新
    _seekDebounceTimerAudio?.cancel();
    _seekDebounceTimerAudio = Timer(const Duration(milliseconds: 100), () {
      if (_seekPositionAudio != null && player.duration != null) {
        final targetPosition = Duration(
          milliseconds:
              (_seekPositionAudio! * player.duration!.inMilliseconds).round(),
        );
        player.seek(targetPosition);

        if (kDebugMode) {
          debugPrint(
              '🎵 音声シーク位置更新: ${_formatDuration(targetPosition)} / ${_formatDuration(player.duration!)} (progress: ${_seekPositionAudio!.toStringAsFixed(3)})');
        }
      }
    });
  }

  /// 音声シーク終了
  void _endSeekingAudio(AudioPlayer player) {
    if (player.duration == null || _seekPositionAudio == null) return;

    // デバウンスタイマーをキャンセルして、即座に最終位置に移動
    _seekDebounceTimerAudio?.cancel();

    final targetPosition = Duration(
      milliseconds:
          (_seekPositionAudio! * player.duration!.inMilliseconds).round(),
    );

    // 音声の再生位置を変更
    player.seek(targetPosition).then((_) {
      // シーク前が再生中だった場合は再開
      if (!_isDisposed && mounted) {
        player.play();
      }
    });

    setState(() {
      _isSeekingAudio = false;
      _seekPositionAudio = null;
    });

    // シークバー更新タイマーを再開
    _startSeekBarUpdateTimerAudio();
  }

  /// 音声シークバー更新タイマーを開始
  void _startSeekBarUpdateTimerAudio() {
    _seekBarUpdateTimerAudio?.cancel();
    _seekBarUpdateTimerAudio =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDisposed &&
          mounted &&
          _currentPlayingAudio != null &&
          !_isSeekingAudio) {
        final player = _audioPlayers[_currentPlayingAudio];
        if (player != null) {
          setState(() {
            // シークバーの更新をトリガー
          });
        } else {
          // プレイヤーが初期化されていない場合はタイマーを停止
          timer.cancel();
        }
      } else if (_currentPlayingAudio == null) {
        // 再生中の音声がない場合はタイマーを停止
        timer.cancel();
      }
    });
  }

  /// 音声用シークバーを構築（ナビゲーションバーの真上に表示）
  Widget _buildAudioSeekBar(AudioPlayer player) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, positionSnapshot) {
        final position = _isSeekingAudio && _seekPositionAudio != null
            ? Duration(
                milliseconds: (_seekPositionAudio! *
                        (player.duration?.inMilliseconds ?? 0))
                    .round())
            : (positionSnapshot.data ?? Duration.zero);
        final duration = player.duration ?? Duration.zero;
        double progress = 0.0;
        if (duration.inMilliseconds > 0 && position.inMilliseconds >= 0) {
          final calculatedProgress =
              position.inMilliseconds / duration.inMilliseconds;
          // NaN、Infinity、不正な値をチェックしてクランプ
          if (calculatedProgress.isFinite) {
            progress = calculatedProgress.clamp(0.0, 1.0);
          }
        }

        // ナビゲーションバーの高さを考慮（約80px）
        return Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 時間表示（画面右のシークバーの上）
                Padding(
                  padding: const EdgeInsets.only(right: 0, bottom: 8),
                  child: Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // シークバー（画面の一番左から右まで）
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    if (player.duration == null) return;
                    _startSeekingAudio(player);
                  },
                  onHorizontalDragUpdate: (details) {
                    if (player.duration == null) return;
                    if (!_isSeekingAudio) {
                      _startSeekingAudio(player);
                    }
                    _updateSeekingAudio(details, player);
                  },
                  onHorizontalDragEnd: (details) {
                    if (player.duration == null) return;
                    _endSeekingAudio(player);
                  },
                  onTapDown: (details) {
                    if (player.duration == null) return;

                    // シークバーのコンテナ内の座標を取得
                    final containerWidth = MediaQuery.of(context).size.width;
                    final tapX =
                        details.localPosition.dx.clamp(0.0, containerWidth);
                    final tapRatio = tapX / containerWidth;
                    final targetPosition = Duration(
                      milliseconds:
                          (tapRatio.clamp(0.0, 1.0) * duration.inMilliseconds)
                              .round(),
                    );

                    player.seek(targetPosition);

                    if (kDebugMode) {
                      debugPrint(
                          '🎵 音声シークバータップ: $tapX / $containerWidth = $tapRatio → ${_formatDuration(targetPosition)}');
                    }
                  },
                  child: Builder(
                    builder: (context) {
                      final safeProgress =
                          progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
                      final containerWidth = MediaQuery.of(context).size.width;
                      final progressWidth = containerWidth * safeProgress;
                      return Container(
                        width: double.infinity,
                        height: 20, // タップ領域を広げる
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Stack(
                          children: [
                            // 背景バー
                            Container(
                              width: double.infinity,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // 再生済み部分（左から右へ）
                            Positioned(
                              left: 0,
                              top: 8,
                              child: SizedBox(
                                width: progressWidth,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B35),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            // シークハンドル
                            Positioned(
                              left: progressWidth - 6,
                              top: 4,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// シークバーを構築（ナビゲーションバーの真上に表示）
  Widget _buildSeekBar(VideoPlayerController controller) {
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final position = _isSeeking && _seekPosition != null
        ? Duration(
            milliseconds:
                (_seekPosition! * controller.value.duration.inMilliseconds)
                    .round())
        : controller.value.position;
    final duration = controller.value.duration;
    double progress = 0.0;
    if (duration.inMilliseconds > 0 && position.inMilliseconds >= 0) {
      final calculatedProgress =
          position.inMilliseconds / duration.inMilliseconds;
      // NaN、Infinity、不正な値をチェックしてクランプ
      if (calculatedProgress.isFinite) {
        progress = calculatedProgress.clamp(0.0, 1.0);
      }
    }

    // ナビゲーションバーの高さを考慮（約80px）
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 時間表示（画面右のシークバーの上）
            Padding(
              padding: const EdgeInsets.only(right: 0, bottom: 8),
              child: Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // シークバー（画面の一番左から右まで）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                if (!controller.value.isInitialized) return;
                _startSeeking(controller);
              },
              onHorizontalDragUpdate: (details) {
                if (!controller.value.isInitialized) return;
                if (!_isSeeking) {
                  _startSeeking(controller);
                }
                _updateSeeking(details, controller);
              },
              onHorizontalDragEnd: (details) {
                if (!controller.value.isInitialized) return;
                _endSeeking(controller);
              },
              onTapDown: (details) {
                if (!controller.value.isInitialized) return;

                // シークバーのコンテナ内の座標を取得
                final containerWidth = MediaQuery.of(context).size.width;
                final tapX =
                    details.localPosition.dx.clamp(0.0, containerWidth);
                final tapRatio = tapX / containerWidth;
                final targetPosition = Duration(
                  milliseconds: (tapRatio.clamp(0.0, 1.0) *
                          controller.value.duration.inMilliseconds)
                      .round(),
                );

                controller.seekTo(targetPosition);

                if (kDebugMode) {
                  debugPrint(
                      '🎯 シークバータップ: $tapX / $containerWidth = $tapRatio → ${_formatDuration(targetPosition)}');
                }
              },
              child: Builder(
                builder: (context) {
                  final safeProgress =
                      progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
                  final containerWidth = MediaQuery.of(context).size.width;
                  final progressWidth = containerWidth * safeProgress;
                  return Container(
                    width: double.infinity,
                    height: 20, // タップ領域を広げる
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Stack(
                      children: [
                        // 背景バー
                        Container(
                          width: double.infinity,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // 再生済み部分（左から右へ）
                        Positioned(
                          left: 0,
                          top: 8,
                          child: SizedBox(
                            width: progressWidth,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        // シークハンドル
                        Positioned(
                          left: progressWidth - 6,
                          top: 4,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(Post post) {
    // 画像URLを取得（mediaUrl優先、なければthumbnailUrl）
    final imageUrl = post.mediaUrl ?? post.thumbnailUrl;

    if (kDebugMode) {
      debugPrint('🖼️ 画像コンテンツ表示:');
      debugPrint('   mediaUrl: ${post.mediaUrl}');
      debugPrint('   thumbnailUrl: ${post.thumbnailUrl}');
      debugPrint('   contentPath: ${post.contentPath}');
      debugPrint('   使用URL: $imageUrl');
    }

    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_not_supported,
                color: Colors.white38,
                size: 80,
              ),
              const SizedBox(height: 16),
              const Text(
                '画像URLが設定されていません',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'contentPath: ${post.contentPath}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // 画面サイズを取得してキャッシュサイズを計算
    final screenSize = MediaQuery.of(context).size;
    final cacheWidth =
        (screenSize.width * MediaQuery.of(context).devicePixelRatio).round();
    final cacheHeight =
        (screenSize.height * MediaQuery.of(context).devicePixelRatio).round();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: RobustNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        maxWidth: cacheWidth,
        maxHeight: cacheHeight,
      ),
    );
  }

  Widget _buildTextContent(Post post) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black,
            SpotLightColors.getSpotlightColor(0).withOpacity(0.15),
            SpotLightColors.getSpotlightColor(1).withOpacity(0.15),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                post.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              if (post.content != null)
                Text(
                  post.content!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioContent(Post post) {
    final postIndex = _posts.indexOf(post);
    final player = _audioPlayers[postIndex];
    final isPlaying = _currentPlayingAudio == postIndex && player != null;

    return Stack(
      children: [
        // モダンな背景デザイン
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                SpotLightColors.getSpotlightColor(2).withOpacity(0.4),
                SpotLightColors.getSpotlightColor(1).withOpacity(0.3),
                Colors.black,
                Colors.black,
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: CustomPaint(
            painter: _AudioBackgroundPainter(isPlaying: isPlaying),
            child: GestureDetector(
              onTap: () {
                if (!_isSeekingAudio) {
                  _toggleAudioPlayback(postIndex);
                }
              },
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 音声視覚化エフェクト（モダンなデザイン）
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            SpotLightColors.getSpotlightColor(2)
                                .withOpacity(0.6),
                            SpotLightColors.getSpotlightColor(2)
                                .withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SpotLightColors.getSpotlightColor(2)
                                .withOpacity(0.5),
                            blurRadius: isPlaying ? 40 : 20,
                            spreadRadius: isPlaying ? 10 : 5,
                          ),
                        ],
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.3),
                          border: Border.all(
                            color: SpotLightColors.getSpotlightColor(2)
                                .withOpacity(0.8),
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: isPlaying ? 90 : 70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      '音声投稿',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    // 音声初期化中のローディング表示
                    if (postIndex == _currentIndex &&
                        post.postType == PostType.audio &&
                        !_initializedAudios.contains(postIndex))
                      const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // シークバー（音声が初期化されている場合は常に表示）
        if (postIndex == _currentIndex &&
            player != null &&
            _initializedAudios.contains(postIndex))
          _buildAudioSeekBar(player),
      ],
    );
  }

  Widget _buildBottomControls(Post post) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 投稿者情報（タップ可能）
          GestureDetector(
            onTap: () {
              // 他ユーザーのプロフィール画面に遷移
              if (kDebugMode) {
                debugPrint('👤 ユーザープロフィール画面に遷移:');
                debugPrint('  userId: ${post.userId}');
                debugPrint('  username: ${post.username}');
                debugPrint('  userIconUrl: ${post.userIconUrl}');
                debugPrint('  userIconPath: ${post.userIconPath}');
              }

              // userIdが空でも、usernameがあれば遷移を許可
              // UserProfileScreenでusernameから情報を取得する
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(
                    userId: post.userId.isEmpty ? '' : post.userId,
                    username: post.username,
                    userIconUrl: post.userIconUrl,
                    userIconPath: post.userIconPath,
                  ),
                ),
              );
            },
            child: Row(
              children: [
                // RepaintBoundaryでアイコン部分を分離し、setStateの影響を受けないようにする
                RepaintBoundary(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: SpotLightColors.getSpotlightColor(0),
                    child: ClipOval(
                      key: ValueKey(
                          '${post.username}_${post.userIconPath}_${_iconCacheKeys[post.username] ?? DateTime.now().millisecondsSinceEpoch}'),
                      child: CachedNetworkImage(
                        imageUrl: _getCachedIconUrl(
                            post.userIconUrl, post.userIconPath),
                        fit: BoxFit.cover,
                        memCacheWidth: 80,
                        memCacheHeight: 80,
                        httpHeaders: const {
                          'Accept': 'image/webp,image/avif,image/*,*/*;q=0.8',
                          'User-Agent': 'Flutter-Spotlight/1.0',
                        },
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (context, url) => Container(
                          color: SpotLightColors.getSpotlightColor(0),
                        ),
                        errorWidget: (context, url, error) {
                          if (kDebugMode) {
                            debugPrint('⚠️ ホーム画面アイコン読み込みエラー: ${post.username}');
                            debugPrint('  - userIconUrl: ${post.userIconUrl}');
                            debugPrint(
                                '  - userIconPath: ${post.userIconPath}');
                            debugPrint('  - error: $error');
                          }
                          return Container();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_getTimeAgo(post.createdAt.toLocal())}前',
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
          ),
          const SizedBox(height: 12),
          // タイトル
          Text(
            post.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRightBottomControls(Post post) {
    return Column(
      children: [
        // スポットライトボタン
        _buildControlButton(
          icon: post.isSpotlighted
              ? Icons.flashlight_on
              : Icons.flashlight_on_outlined,
          color: post.isSpotlighted
              ? SpotLightColors.getSpotlightColor(0)
              : Colors.white,
          label: '${post.likes}',
          onTap: () => _handleSpotlightButton(post),
        ),
        const SizedBox(height: 20),
        // コメントボタン
        _buildControlButton(
          icon: Icons.chat_bubble_outline,
          color: Colors.white,
          label: '${post.comments}',
          onTap: () => _handleCommentButton(post),
        ),
        const SizedBox(height: 20),
        // プレイリスト追加ボタン
        _buildControlButton(
          icon: Icons.playlist_add,
          color: Colors.white,
          onTap: () => _handlePlaylistButton(post),
        ),
        const SizedBox(height: 20),
        // 共有ボタン
        _buildControlButton(
          icon: Icons.share,
          color: Colors.white,
          onTap: () => _handleShareButton(post),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            if (label != null && label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}日';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}時間';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分';
    } else {
      return 'たった今';
    }
  }

  // ジェスチャー処理
  void _handlePanUpdate(DragUpdateDetails details) {
    // 右スワイプのみを検出
    if (details.delta.dx > 0) {
      setState(() {
        _swipeOffset = math.min(_swipeOffset + details.delta.dx, 300.0);
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    // スワイプが十分な場合は即座にスポットライト実行
    if (_swipeOffset > 80) {
      _executeSpotlight();
    } else {
      // スワイプが不十分な場合は元に戻す
      setState(() {
        _swipeOffset = 0.0;
      });
    }
  }

  // スポットライト実行（共通処理）
  Future<void> _executeSpotlight() async {
    final currentPost = _posts[_currentIndex];
    final isCurrentlySpotlighted = currentPost.isSpotlighted;

    // バックエンドAPIを呼び出し
    final success = isCurrentlySpotlighted
        ? await PostService.spotlightOff(currentPost.id)
        : await PostService.spotlightOn(currentPost.id);

    if (!success) {
      if (kDebugMode) {
        debugPrint('❌ スポットライト処理に失敗しました');
      }
      return;
    }

    // 投稿のスポットライト状態を更新
    _posts[_currentIndex] = Post(
      id: currentPost.id,
      userId: currentPost.userId,
      username: currentPost.username,
      userIconPath: currentPost.userIconPath,
      userIconUrl: currentPost.userIconUrl,
      title: currentPost.title,
      content: currentPost.content,
      contentPath: currentPost.contentPath,
      type: currentPost.type,
      mediaUrl: currentPost.mediaUrl,
      thumbnailUrl: currentPost.thumbnailUrl,
      likes: isCurrentlySpotlighted
          ? currentPost.likes - 1
          : currentPost.likes + 1,
      playNum: currentPost.playNum,
      link: currentPost.link,
      comments: currentPost.comments,
      shares: currentPost.shares,
      isSpotlighted: !isCurrentlySpotlighted,
      isText: currentPost.isText,
      nextContentId: currentPost.nextContentId,
      createdAt: currentPost.createdAt,
    );

    if (!isCurrentlySpotlighted) {
      // スポットライトをつける場合：アニメーション付き
      setState(() {
        _isSpotlighting = true;
        _swipeOffset = 0.0;
      });

      // アンビエントライティングアニメーション開始
      _ambientAnimationController?.forward();

      // 2秒後にアニメーション付きで消す
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isDisposed && mounted) {
          _ambientAnimationController?.reverse().then((_) {
            if (!_isDisposed && mounted) {
              setState(() {
                _isSpotlighting = false;
              });
              _ambientAnimationController?.reset();
            }
          });
        }
      });
    } else {
      // スポットライトを消す場合：アニメーションなし、色もなし
      setState(() {
        _swipeOffset = 0.0;
      });
    }
  }

  void _resetSpotlightState() {
    if (!_isDisposed && mounted) {
      setState(() {
        _swipeOffset = 0.0;
        _isSpotlighting = false;
      });
    }
    _ambientAnimationController?.reset();
  }

  // ボタン機能実装
  void _handleSpotlightButton(Post post) {
    _executeSpotlight();
  }

  int _countAllComments(List<Comment> commentList) {
    var total = 0;
    for (final comment in commentList) {
      total++; // 親コメントをカウント
      if (comment.replies.isNotEmpty) {
        // 返信コメントも再帰的にカウント
        total += _countAllComments(comment.replies);
      }
    }
    if (kDebugMode) {
      debugPrint('💬 コメント数カウント: 親コメント=${commentList.length}件, 合計=$total件');
    }
    return total;
  }

  void _handleCommentButton(Post post) {
    final commentController = TextEditingController();
    bool isLoading = true;
    bool hasRequestedComments = false;
    bool isSheetOpen = true;
    List<Comment> comments = [];
    int? replyingToCommentId; // 返信対象のコメントID

    Future<List<Comment>> refreshComments(StateSetter setModalState) async {
      if (!isSheetOpen) {
        return comments;
      }
      try {
        setModalState(() {
          if (isSheetOpen) {
            isLoading = true;
          }
        });
      } catch (e) {
        // モーダルが閉じられた場合はスキップ
        return comments;
      }
      final fetchedComments = await CommentService.getComments(post.id);
      if (!mounted || !isSheetOpen) {
        return comments;
      }
      try {
        setModalState(() {
          if (isSheetOpen) {
            comments = fetchedComments;
            isLoading = false;
          }
        });
      } catch (e) {
        // モーダルが閉じられた場合はスキップ
        return comments;
      }

      if (kDebugMode) {
        debugPrint('💬 コメント一覧を更新: ${fetchedComments.length}件の親コメント');
        final totalCount = _countAllComments(fetchedComments);
        debugPrint('💬 コメント総数（返信含む）: $totalCount件');
      }

      return fetchedComments;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // モーダルが閉じられた場合は何も表示しない
            if (!isSheetOpen) {
              return const SizedBox.shrink();
            }

            if (!hasRequestedComments) {
              hasRequestedComments = true;
              refreshComments(setModalState);
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ヘッダー
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'コメント',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // コメント一覧
                        Expanded(
                          child: isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFFF6B35),
                                  ),
                                )
                              : comments.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'コメントはありません',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: scrollController,
                                      itemCount: comments.length,
                                      itemBuilder: (context, index) {
                                        return _buildCommentItem(
                                          comments[index],
                                          post: _posts[_currentIndex],
                                          replyingToCommentId:
                                              replyingToCommentId,
                                          onReplyPressed: (commentId) {
                                            if (!isSheetOpen) return;
                                            try {
                                              setModalState(() {
                                                if (isSheetOpen) {
                                                  if (replyingToCommentId ==
                                                      commentId) {
                                                    replyingToCommentId = null;
                                                    commentController.clear();
                                                  } else {
                                                    replyingToCommentId =
                                                        commentId;
                                                    commentController.clear();
                                                  }
                                                }
                                              });
                                            } catch (e) {
                                              // モーダルが閉じられた場合はスキップ
                                            }
                                          },
                                        );
                                      },
                                    ),
                        ),

                        // 返信対象のコメント情報表示（LINEスタイル）
                        if (replyingToCommentId != null) ...[
                          Builder(
                            builder: (context) {
                              // 返信対象のコメントを検索
                              Comment? replyingToComment;
                              void findComment(List<Comment> commentList) {
                                for (final comment in commentList) {
                                  if (comment.commentID ==
                                      replyingToCommentId) {
                                    replyingToComment = comment;
                                    return;
                                  }
                                  if (comment.replies.isNotEmpty) {
                                    findComment(comment.replies);
                                  }
                                }
                              }

                              findComment(comments);

                              if (replyingToComment == null) {
                                return const SizedBox.shrink();
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFF6B35)
                                        .withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // 左側の縦線
                                    Container(
                                      width: 3,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B35),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // 返信対象のコメント情報
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.reply,
                                                color: Color(0xFFFF6B35),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                replyingToComment!.username,
                                                style: const TextStyle(
                                                  color: Color(0xFFFF6B35),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            replyingToComment!.commenttext,
                                            style: TextStyle(
                                              color: Colors.grey[300],
                                              fontSize: 12,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // キャンセルボタン
                                    IconButton(
                                      onPressed: () {
                                        if (!isSheetOpen) return;
                                        try {
                                          setModalState(() {
                                            if (isSheetOpen) {
                                              replyingToCommentId = null;
                                              commentController.clear();
                                            }
                                          });
                                        } catch (e) {
                                          // モーダルが閉じられた場合はスキップ
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        // コメント入力
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFFF6B35),
                                child: const Icon(Icons.person,
                                    size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: isSheetOpen
                                    ? TextField(
                                        controller: commentController,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: replyingToCommentId != null
                                              ? '返信を入力...'
                                              : 'コメントを追加...',
                                          hintStyle: TextStyle(
                                              color: Colors.grey[400]),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            borderSide: BorderSide.none,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey[800],
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: () async {
                                  if (!isSheetOpen) return;
                                  final commentText =
                                      commentController.text.trim();
                                  if (commentText.isEmpty) return;

                                  try {
                                    setModalState(() {
                                      if (isSheetOpen) {
                                        isLoading = true;
                                      }
                                    });
                                  } catch (e) {
                                    // モーダルが閉じられた場合はスキップ
                                    return;
                                  }

                                  // コメント送信（返信の場合はparentCommentIdを設定）
                                  final success =
                                      await CommentService.addComment(
                                    post.id,
                                    commentText,
                                    parentCommentId: replyingToCommentId,
                                  );

                                  if (!isSheetOpen || !mounted) return;

                                  if (success) {
                                    // 返信の場合はparentCommentIdを保存（デバッグログ用）
                                    final wasReplying =
                                        replyingToCommentId != null;

                                    commentController.clear();

                                    // 返信状態をクリア
                                    try {
                                      setModalState(() {
                                        if (isSheetOpen) {
                                          replyingToCommentId = null;
                                        }
                                      });
                                    } catch (e) {
                                      // モーダルが閉じられた場合はスキップ
                                    }

                                    // バックエンドの処理完了を待つ（返信の場合、少し長めに待機）
                                    if (wasReplying) {
                                      await Future.delayed(
                                          const Duration(milliseconds: 500));
                                    } else {
                                      await Future.delayed(
                                          const Duration(milliseconds: 200));
                                    }

                                    // コメント一覧を再取得
                                    final updatedComments =
                                        await refreshComments(setModalState);
                                    if (!isSheetOpen || !mounted) return;

                                    final updatedTotal =
                                        _countAllComments(updatedComments);

                                    if (kDebugMode) {
                                      debugPrint(
                                          '💬 ${wasReplying ? "返信" : "コメント"}追加後のコメント数: $updatedTotal件');
                                      debugPrint(
                                          '💬 現在の投稿のコメント数: ${_posts[_currentIndex].comments}件');
                                      debugPrint(
                                          '💬 更新後のコメント一覧: ${updatedComments.length}件の親コメント');
                                      if (wasReplying) {
                                        debugPrint('💬 返信追加後のコメント一覧を更新しました');
                                      }
                                    }

                                    // 投稿のコメント数を更新
                                    if (mounted && !_isDisposed) {
                                      setState(() {
                                        _posts[_currentIndex] = Post(
                                          id: _posts[_currentIndex].id,
                                          userId: _posts[_currentIndex].userId,
                                          username:
                                              _posts[_currentIndex].username,
                                          userIconPath: _posts[_currentIndex]
                                              .userIconPath,
                                          userIconUrl:
                                              _posts[_currentIndex].userIconUrl,
                                          title: _posts[_currentIndex].title,
                                          content:
                                              _posts[_currentIndex].content,
                                          contentPath:
                                              _posts[_currentIndex].contentPath,
                                          type: _posts[_currentIndex].type,
                                          mediaUrl:
                                              _posts[_currentIndex].mediaUrl,
                                          thumbnailUrl: _posts[_currentIndex]
                                              .thumbnailUrl,
                                          likes: _posts[_currentIndex].likes,
                                          playNum:
                                              _posts[_currentIndex].playNum,
                                          link: _posts[_currentIndex].link,
                                          comments: updatedTotal,
                                          shares: _posts[_currentIndex].shares,
                                          isSpotlighted: _posts[_currentIndex]
                                              .isSpotlighted,
                                          isText: _posts[_currentIndex].isText,
                                          nextContentId: _posts[_currentIndex]
                                              .nextContentId,
                                          createdAt:
                                              _posts[_currentIndex].createdAt,
                                        );
                                      });
                                    }
                                  } else {
                                    try {
                                      setModalState(() {
                                        if (isSheetOpen) {
                                          isLoading = false;
                                        }
                                      });
                                    } catch (e) {
                                      // モーダルが閉じられた場合はスキップ
                                    }
                                  }
                                },
                                icon: const Icon(Icons.send,
                                    color: Color(0xFFFF6B35)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    ).then((_) {
      // モーダルが閉じられたことをマーク（dispose()の前に設定）
      isSheetOpen = false;
    }).whenComplete(() {
      // コントローラーを安全に破棄
      try {
        commentController.dispose();
      } catch (e) {
        // 既に破棄されている場合はスキップ
      }
    });
  }

  Widget _buildCommentItem(
    Comment comment, {
    required Post post,
    int? replyingToCommentId,
    required Function(int) onReplyPressed,
    bool isReply = false,
  }) {
    return Container(
      margin: EdgeInsets.only(
        bottom: 16,
        left: isReply ? 32 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFFF6B35),
                backgroundImage: comment.userIconUrl != null
                    ? CachedNetworkImageProvider(
                        _getCachedIconUrl(comment.userIconUrl, ''),
                      )
                    : null,
                child: comment.userIconUrl == null
                    ? const Icon(Icons.person, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatCommentTime(comment.commenttimestamp),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.commenttext,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    // 返信ボタンと通報ボタン（親コメントのみ返信ボタンを表示、通報ボタンはすべてのコメントに表示）
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // 返信ボタンは親コメント（1階層目）のみ表示（2階層までに制限）
                        if (!isReply) ...[
                          GestureDetector(
                            onTap: () {
                              onReplyPressed(comment.commentID);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.reply,
                                  color: Colors.grey[400],
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '返信',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        // 通報ボタンはすべてのコメント（親コメントと返信コメント）に表示
                        GestureDetector(
                          onTap: () {
                            if (mounted) {
                              _showCommentReportDialog(comment, post);
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flag_outlined,
                                color: Colors.grey[400],
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '通報',
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
                  ],
                ),
              ),
            ],
          ),
          // 返信コメント
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 0),
              child: Column(
                children: comment.replies
                    .map((reply) => _buildCommentItem(
                          reply,
                          post: post,
                          replyingToCommentId: replyingToCommentId,
                          onReplyPressed: onReplyPressed,
                          isReply: true,
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCommentTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}日前';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}時間前';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}分前';
      } else {
        return 'たった今';
      }
    } catch (e) {
      return timestamp;
    }
  }

  /// コメント通報ダイアログを表示
  void _showCommentReportDialog(Comment comment, Post post) {
    if (!mounted) return;

    // 自分のコメントかどうかをチェック
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final commentUserId = comment.userId?.toString().trim() ?? '';
    final currentUserIdStr = currentUserId?.toString().trim() ?? '';

    if (kDebugMode) {
      debugPrint('🚨 コメント通報ダイアログ表示前チェック:');
      debugPrint('  currentUserId: "$currentUserIdStr"');
      debugPrint('  commentUserId: "$commentUserId"');
      debugPrint('  一致: ${currentUserIdStr == commentUserId}');
    }

    if (currentUserIdStr.isNotEmpty &&
        commentUserId.isNotEmpty &&
        currentUserIdStr == commentUserId) {
      // 自分のコメントの場合はエラーダイアログを表示
      if (kDebugMode) {
        debugPrint('🚨 自分のコメントへの通報をブロックしました');
      }
      _showErrorDialog('自分のコメントは通報できません');
      return;
    }

    // 既に通報済みかどうかをチェック
    final commentId = comment.commentID.toString();
    if (_reportedCommentIds.contains(commentId)) {
      if (kDebugMode) {
        debugPrint('🚨 このコメントは既に通報済みです: $commentId');
      }
      _showErrorDialog('このコメントは既に通報済みです');
      return;
    }

    if (!mounted) return;

    if (kDebugMode) {
      debugPrint('🚨 コメント通報ダイアログを表示します');
      debugPrint('  commentID: ${comment.commentID}');
      debugPrint('  postID: ${post.id}');
    }

    // commentIdを変数に保存（コールバック内で使用するため）
    final savedCommentId = commentId;

    showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        if (kDebugMode) {
          debugPrint('🚨 _CommentReportDialog ビルダーが呼ばれました');
        }
        return _CommentReportDialog(
          comment: comment,
          post: post,
        );
      },
    ).then((success) {
      if (success == true && mounted) {
        // 通報成功時に通報済みリストに追加
        _reportedCommentIds.add(savedCommentId);
        if (kDebugMode) {
          debugPrint('✅ コメント通報済みリストに追加: $savedCommentId');
          debugPrint('   現在の通報済みコメント数: ${_reportedCommentIds.length}');
        }
        _showReportSuccessDialog();
      }
    });
  }

  /// プレイリスト追加ボタンの処理
  void _handlePlaylistButton(Post post) async {
    try {
      // プレイリスト一覧を取得
      final playlists = await PlaylistService.getPlaylists();

      if (!mounted) return;

      if (playlists.isEmpty) {
        // プレイリストがない場合は新規作成を促す
        _showCreatePlaylistDialog(post);
        return;
      }

      // プレイリスト選択ダイアログを表示
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'プレイリストに追加',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // プレイリスト一覧
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length + 1, // +1は新規作成ボタン
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // 新規作成ボタン
                        return ListTile(
                          leading: const Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFFFF6B35),
                          ),
                          title: const Text(
                            '新しいプレイリストを作成',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showCreatePlaylistDialog(post);
                          },
                        );
                      }

                      final playlist = playlists[index - 1];
                      return ListTile(
                        leading: playlist.thumbnailpath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  '${AppConfig.backendUrl}${playlist.thumbnailpath}',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.playlist_play,
                                      color: Color(0xFFFF6B35),
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.playlist_play,
                                color: Color(0xFFFF6B35),
                              ),
                        title: Text(
                          playlist.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () async {
                          Navigator.pop(context);

                          if (kDebugMode) {
                            debugPrint('📋 [ホーム画面] プレイリストにコンテンツを追加');
                            debugPrint(
                                '   - playlistID: ${playlist.playlistid}');
                            debugPrint('   - contentID: ${post.id}');
                            debugPrint(
                                '   - contentID type: ${post.id.runtimeType}');
                          }

                          final success =
                              await PlaylistService.addContentToPlaylist(
                            playlist.playlistid,
                            post.id,
                          );

                          if (kDebugMode) {
                            debugPrint('📋 [ホーム画面] 追加結果: $success');
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success ? 'プレイリストに追加しました' : '追加に失敗しました',
                                ),
                                backgroundColor:
                                    success ? Colors.green : Colors.red,
                              ),
                            );

                            // 追加成功時、少し待ってからプレイリスト詳細画面が開いている場合は更新を促す
                            if (success) {
                              if (kDebugMode) {
                                debugPrint(
                                    '📋 [ホーム画面] コンテンツ追加成功。プレイリスト詳細画面の更新を促します。');
                              }
                              // グローバルキーやRouteObserverを使わず、単純に少し待ってから通知
                              // 実際には、プレイリスト詳細画面が開いている場合のみ更新が必要
                              // ここでは、ユーザーが手動で更新ボタンを押すか、画面に戻った時に更新される
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📋 プレイリスト取得エラー: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プレイリストの取得に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// プレイリスト作成ダイアログ
  void _showCreatePlaylistDialog(Post post) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            '新しいプレイリストを作成',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'プレイリスト名を入力',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[800],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                // ScaffoldMessengerのインスタンスを事前に取得（Navigator.popの前に）
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                Navigator.pop(context);

                final playlistId = await PlaylistService.createPlaylist(title);

                if (kDebugMode) {
                  debugPrint('📋 [ホーム画面] プレイリスト作成結果: playlistId=$playlistId');
                }

                if (playlistId != null && playlistId >= 0 && mounted) {
                  // playlistIdが0の場合は、作成は成功しているがplaylistidが取得できなかった場合
                  // この場合、プレイリスト一覧を再取得して最新のプレイリストを取得する
                  if (playlistId == 0) {
                    if (kDebugMode) {
                      debugPrint(
                          '📋 [ホーム画面] playlistidが取得できなかったため、プレイリスト一覧を再取得します');
                    }
                    // プレイリスト一覧を再取得して、最新のプレイリスト（作成したもの）を取得
                    final playlists = await PlaylistService.getPlaylists();
                    if (playlists.isNotEmpty) {
                      // タイトルで一致する最新のプレイリストを探す
                      final createdPlaylist = playlists.firstWhere(
                        (p) => p.title == title,
                        orElse: () => playlists.first, // 見つからない場合は最初のプレイリストを使用
                      );
                      final actualPlaylistId = createdPlaylist.playlistid;

                      if (kDebugMode) {
                        debugPrint(
                            '📋 [ホーム画面] 再取得したplaylistid: $actualPlaylistId');
                      }

                      if (actualPlaylistId > 0) {
                        // 作成したプレイリストにコンテンツを追加
                        final success =
                            await PlaylistService.addContentToPlaylist(
                          actualPlaylistId,
                          post.id,
                        );

                        if (mounted) {
                          try {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  success ? 'プレイリストを作成して追加しました' : '追加に失敗しました',
                                ),
                                backgroundColor:
                                    success ? Colors.green : Colors.red,
                              ),
                            );
                          } catch (e) {
                            if (kDebugMode) {
                              debugPrint('⚠️ SnackBar表示エラー: $e');
                            }
                          }
                        }
                      } else {
                        // プレイリストは作成されたが、コンテンツ追加はスキップ
                        if (mounted) {
                          try {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('プレイリストを作成しました'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (kDebugMode) {
                              debugPrint('⚠️ SnackBar表示エラー: $e');
                            }
                          }
                        }
                      }
                    } else {
                      // プレイリスト一覧が取得できなかった場合でも、作成は成功している
                      if (mounted) {
                        try {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('プレイリストを作成しました'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (kDebugMode) {
                            debugPrint('⚠️ SnackBar表示エラー: $e');
                          }
                        }
                      }
                    }
                  } else {
                    // playlistIdが正しく取得できた場合
                    if (kDebugMode) {
                      debugPrint('📋 [ホーム画面] 作成したプレイリストにコンテンツを追加');
                      debugPrint('   - playlistID: $playlistId');
                      debugPrint('   - contentID: ${post.id}');
                    }
                    // 作成したプレイリストにコンテンツを追加
                    final success = await PlaylistService.addContentToPlaylist(
                      playlistId,
                      post.id,
                    );

                    if (mounted) {
                      try {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success ? 'プレイリストを作成して追加しました' : '追加に失敗しました',
                            ),
                            backgroundColor:
                                success ? Colors.green : Colors.red,
                          ),
                        );
                      } catch (e) {
                        if (kDebugMode) {
                          debugPrint('⚠️ SnackBar表示エラー: $e');
                        }
                      }
                    }
                  }
                } else if (mounted) {
                  // playlistIdがnullの場合は、作成に失敗した
                  try {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('プレイリストの作成に失敗しました'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } catch (e) {
                    if (kDebugMode) {
                      debugPrint('⚠️ SnackBar表示エラー: $e');
                    }
                  }
                }
              },
              child: const Text(
                '作成',
                style: TextStyle(color: Color(0xFFFF6B35)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleShareButton(Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '共有',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // 共有オプション
              _buildShareOption(
                icon: Icons.copy,
                title: 'リンクをコピー',
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('リンクをコピーしました');
                  setState(() {
                    _posts[_currentIndex] = Post(
                      id: _posts[_currentIndex].id,
                      userId: _posts[_currentIndex].userId,
                      username: _posts[_currentIndex].username,
                      userIconPath: _posts[_currentIndex].userIconPath,
                      userIconUrl: _posts[_currentIndex].userIconUrl,
                      title: _posts[_currentIndex].title,
                      content: _posts[_currentIndex].content,
                      contentPath: _posts[_currentIndex].contentPath,
                      type: _posts[_currentIndex].type,
                      mediaUrl: _posts[_currentIndex].mediaUrl,
                      thumbnailUrl: _posts[_currentIndex].thumbnailUrl,
                      likes: _posts[_currentIndex].likes,
                      playNum: _posts[_currentIndex].playNum,
                      link: _posts[_currentIndex].link,
                      comments: _posts[_currentIndex].comments,
                      shares: _posts[_currentIndex].shares + 1,
                      isSpotlighted: _posts[_currentIndex].isSpotlighted,
                      isText: _posts[_currentIndex].isText,
                      nextContentId: _posts[_currentIndex].nextContentId,
                      createdAt: _posts[_currentIndex].createdAt,
                    );
                  });
                },
              ),
              _buildShareOption(
                icon: Icons.message,
                title: 'メッセージで送信',
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('メッセージアプリを開きます');
                },
              ),
              _buildShareOption(
                icon: Icons.email,
                title: 'メールで送信',
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('メールアプリを開きます');
                },
              ),
              _buildShareOption(
                icon: Icons.bookmark_border,
                title: 'ブックマークに保存',
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('ブックマークに保存しました');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: onTap,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// 通報ボタンを構築（画面右上に配置）
  Widget _buildReportButton(Post post) {
    // Selectorを使用して、currentUser.idのみを監視（依存関係の問題を回避）
    return Selector<AuthProvider, String?>(
      selector: (context, authProvider) => authProvider.currentUser?.id,
      shouldRebuild: (prev, next) {
        // 値が実際に変わった時のみ再構築
        if (prev == next) return false;
        // 値がnullから非null、または非nullからnullに変わった場合も再構築
        return true;
      },
      builder: (context, currentUserId, child) {
        final postUserId = post.userId.toString().trim();
        final currentUserIdStr = currentUserId?.toString().trim() ?? '';

        // 自分の投稿の場合は非表示
        if (currentUserIdStr.isNotEmpty &&
            postUserId.isNotEmpty &&
            currentUserIdStr == postUserId) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 40,
          right: 20,
          child: GestureDetector(
            onTap: () => _showReportDialog(post),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flag_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 通報ダイアログを表示
  void _showReportDialog(Post post) {
    if (!mounted) return;

    // 自分の投稿かどうかをチェック
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final postUserId = post.userId.toString().trim();
    final currentUserIdStr = currentUserId?.toString().trim() ?? '';

    if (kDebugMode) {
      debugPrint('🚨 通報ダイアログ表示前チェック:');
      debugPrint('  currentUserId: "$currentUserIdStr"');
      debugPrint('  postUserId: "$postUserId"');
      debugPrint('  一致: ${currentUserIdStr == postUserId}');
    }

    if (currentUserIdStr.isNotEmpty &&
        postUserId.isNotEmpty &&
        currentUserIdStr == postUserId) {
      // 自分の投稿の場合はエラーダイアログを表示
      if (kDebugMode) {
        debugPrint('🚨 自分の投稿への通報をブロックしました');
      }
      _showErrorDialog('自分の投稿は通報できません');
      return;
    }

    // 既に通報済みかどうかをチェック
    final contentId = post.id.toString();
    if (_reportedContentIds.contains(contentId)) {
      _showErrorDialog('この投稿は既に通報済みです');
      return;
    }

    showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ReportDialog(post: post),
    ).then((success) {
      if (success == true && mounted) {
        // 通報成功時に通報済みリストに追加
        _reportedContentIds.add(contentId);
        _showReportSuccessDialog();
      }
    });
  }

  /// エラーダイアログを表示（HomeScreenState用）
  void _showErrorDialog(String message) {
    if (!mounted) return;
    _showErrorDialogInContext(context, message);
  }

  /// エラーダイアログを表示（任意のcontext用）
  static void _showErrorDialogInContext(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // エラーアイコン
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline,
                color: Color(0xFFFF6B35),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            // メッセージ
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 通報成功ダイアログを表示
  void _showReportSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 成功アイコン
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            // メッセージ
            const Text(
              '通報を送信しました',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'ご報告ありがとうございます。\n内容を確認し、適切に対応いたします。',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 動画プレイヤー関連メソッド
  Future<void> _initializeVideoController(int postIndex) async {
    final post = _posts[postIndex];

    // 動画投稿でない場合、またはmediaUrlが空の場合は何もしない
    if (post.postType != PostType.video ||
        post.mediaUrl == null ||
        post.mediaUrl!.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            '⚠️ 動画初期化スキップ: postType=${post.postType}, mediaUrl=${post.mediaUrl}');
      }
      return;
    }

    // すでに初期化済みの場合はスキップ
    if (_initializedVideos.contains(postIndex)) {
      return;
    }

    try {
      final videoUrl = post.mediaUrl!;

      if (kDebugMode) {
        debugPrint('📹 動画初期化開始: $videoUrl');
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();

      if (!_isDisposed && mounted) {
        setState(() {
          _videoControllers[postIndex] = controller;
          _initializedVideos.add(postIndex);
        });

        // 再生位置の更新をリッスン（シークバーの更新用）
        controller.addListener(_onVideoPositionChanged);

        if (kDebugMode) {
          debugPrint('✅ 動画初期化成功: ${controller.value.duration}');
        }
      }
    } catch (e) {
      // 動画の初期化に失敗した場合、サンプル動画で再試行
      if (kDebugMode) {
        debugPrint('❌ 動画の初期化に失敗: $e');
        debugPrint('🔄 サンプル動画で再試行...');
      }

      try {
        final sampleUrl =
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
        final controller =
            VideoPlayerController.networkUrl(Uri.parse(sampleUrl));
        await controller.initialize();

        if (!_isDisposed && mounted) {
          setState(() {
            _videoControllers[postIndex] = controller;
            _initializedVideos.add(postIndex);
          });

          // 再生位置の更新をリッスン（シークバーの更新用）
          controller.addListener(_onVideoPositionChanged);

          if (kDebugMode) {
            debugPrint('✅ サンプル動画で初期化成功');
          }
        }
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('❌ サンプル動画も失敗: $e2');
        }
      }
    }
  }

  void _handleMediaPageChange(int newIndex) {
    if (newIndex < 0 || newIndex >= _posts.length) {
      if (kDebugMode) {
        debugPrint('⚠️ 無効なインデックス: $newIndex, 投稿数=${_posts.length}');
      }
      return;
    }

    final newPost = _posts[newIndex];

    if (kDebugMode) {
      debugPrint(
          '🔄 メディアページ変更: インデックス $newIndex, 投稿ID=${newPost.id}, type=${newPost.type}');
    }

    // 前の動画を完全に停止
    if (_currentPlayingVideo != null) {
      final prevIndex = _currentPlayingVideo!;
      final prevController = _videoControllers[prevIndex];
      if (prevController != null && prevController.value.isInitialized) {
        // リスナーを削除
        prevController.removeListener(_onVideoPositionChanged);
        // 動画を停止
        prevController.pause();
        // 再生位置を先頭にリセット
        prevController.seekTo(Duration.zero);
        if (kDebugMode) {
          debugPrint('🛑 前の動画を停止: インデックス $prevIndex');
        }
      }
      _currentPlayingVideo = null;
    }

    // シークバー更新タイマーを停止
    _seekBarUpdateTimer?.cancel();

    // シーク状態をリセット
    setState(() {
      _isSeeking = false;
      _seekPosition = null;
    });

    // 前の音声を完全に停止
    if (_currentPlayingAudio != null) {
      final prevAudioIndex = _currentPlayingAudio!;
      final prevPlayer = _audioPlayers[prevAudioIndex];
      if (prevPlayer != null) {
        // 音声を停止
        prevPlayer.pause();
        // 再生位置を先頭にリセット
        prevPlayer.seek(Duration.zero);
        if (kDebugMode) {
          debugPrint('🛑 前の音声を停止: インデックス $prevAudioIndex');
        }
      }
      _currentPlayingAudio = null;
    }

    // 音声シークバー更新タイマーを停止
    _seekBarUpdateTimerAudio?.cancel();

    // 音声シーク状態をリセット
    setState(() {
      _isSeekingAudio = false;
      _seekPositionAudio = null;
    });

    // 新しいページが動画投稿の場合
    if (newPost.postType == PostType.video) {
      // mediaUrlが空の場合は再生をスキップ
      if (newPost.mediaUrl == null || newPost.mediaUrl!.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ 動画URLが空です。再生をスキップします。');
        }
        return;
      }

      _currentPlayingVideo = newIndex;

      // シークバー更新タイマーを開始
      _startSeekBarUpdateTimer();

      // 動画コントローラーが初期化されていない場合は初期化
      if (!_initializedVideos.contains(newIndex)) {
        _initializeVideoController(newIndex).then((_) {
          if (!_isDisposed && mounted && _currentIndex == newIndex) {
            // 初期化完了後に自動再生（ページが変わっていない場合のみ）
            final controller = _videoControllers[newIndex];
            if (controller != null && controller.value.isInitialized) {
              // 再生位置を先頭にリセット
              controller.seekTo(Duration.zero);
              controller.play();
              controller.setLooping(true);

              // 動画読み込み完了時に視聴履歴を記録
              _recordPlayHistory(newPost);
            }
          }
        });
      } else {
        // 既に初期化済みの場合は即座に再生
        final controller = _videoControllers[newIndex];
        if (controller != null && controller.value.isInitialized) {
          // 再生位置を先頭にリセット
          controller.seekTo(Duration.zero);
          controller.play();
          controller.setLooping(true);

          // 既に初期化済みの場合も視聴履歴を記録（動画が読み込まれている）
          _recordPlayHistory(newPost);
        }
      }
    } else if (newPost.postType == PostType.audio) {
      // 新しいページが音声投稿の場合
      // mediaUrlが空の場合は再生をスキップ
      if (newPost.mediaUrl == null || newPost.mediaUrl!.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ 音声URLが空です。再生をスキップします。');
        }
        return;
      }

      _currentPlayingAudio = newIndex;

      // 音声プレイヤーが初期化されていない場合は初期化
      if (!_initializedAudios.contains(newIndex)) {
        _initializeAudioPlayer(newIndex).then((_) {
          if (!_isDisposed && mounted && _currentIndex == newIndex) {
            // 初期化完了後に自動再生（ページが変わっていない場合のみ）
            final player = _audioPlayers[newIndex];
            if (player != null) {
              // 再生位置を先頭にリセット
              player.seek(Duration.zero);
              player.setLoopMode(LoopMode.one);
              player.play();
              // シークバー更新タイマーを開始
              _startSeekBarUpdateTimerAudio();

              // 音声読み込み完了時に視聴履歴を記録
              _recordPlayHistory(newPost);
            }
          }
        });
      } else {
        // 既に初期化済みの場合は即座に再生
        final player = _audioPlayers[newIndex];
        if (player != null) {
          // 再生位置を先頭にリセット
          player.seek(Duration.zero);
          player.setLoopMode(LoopMode.one);
          player.play();
          // シークバー更新タイマーを開始
          _startSeekBarUpdateTimerAudio();

          // 既に初期化済みの場合も視聴履歴を記録（音声が読み込まれている）
          _recordPlayHistory(newPost);
        }
      }
    } else if (newPost.postType == PostType.image) {
      // 画像の場合は表示時に視聴履歴を記録（画像は即座に表示される）
      _recordPlayHistory(newPost);

      // 次の画像を事前読み込み
      _preloadImagesAround(newIndex);
    }
    // 動画と音声の場合は、読み込み完了時に視聴履歴を記録（上記の初期化処理内で実行）
  }

  /// 画像のプリロード（現在のページの前後2件ずつ）
  void _preloadImagesAround(int currentIndex) {
    if (_posts.isEmpty || !mounted) return;

    // 前後2件ずつプリロード（優先度: 次の画像 > 前の画像）
    final preloadIndices = [1, 2, -1, -2]; // 次の画像を優先的にプリロード

    for (final offset in preloadIndices) {
      final targetIndex = currentIndex + offset;
      if (targetIndex >= 0 && targetIndex < _posts.length) {
        final post = _posts[targetIndex];
        if (post.postType == PostType.image) {
          final imageUrl = post.mediaUrl ?? post.thumbnailUrl;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            // バックグラウンドで画像をプリロード（キャッシュから読み込む）
            precacheImage(
              CachedNetworkImageProvider(
                imageUrl,
                headers: const {
                  'Accept': 'image/webp,image/avif,image/*,*/*;q=0.8',
                  'User-Agent': 'Flutter-Spotlight/1.0',
                },
                cacheKey: imageUrl,
              ),
              context,
            ).then((_) {
              // プリロード成功時にRobustNetworkImageの読み込み状態を記録
              // これにより、次回表示時に即座に画像が表示される
              RobustNetworkImage.recordLoadedUrl(imageUrl);
              if (kDebugMode) {
                debugPrint('✅ 画像プリロード成功（読み込み状態を記録）: $imageUrl');
              }
            }).catchError((error) {
              // エラーは無視（プリロードなので失敗しても問題ない）
              if (kDebugMode) {
                debugPrint('⚠️ 画像プリロードエラー: $imageUrl, error: $error');
              }
            });
          }
        }
      }
    }
  }

  /// 視聴履歴を記録
  /// ユーザーが視聴した動画の直近50件を記録、重複がある場合は最新分だけを残す
  Future<void> _recordPlayHistory(Post post) async {
    if (kDebugMode) {
      debugPrint(
          '📝 視聴履歴記録開始: 投稿ID=${post.id}, タイトル=${post.title}, userId=${post.userId}');
    }

    try {
      // 自分の投稿は記録しない
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.currentUser?.id;

      if (kDebugMode) {
        debugPrint('📝 現在のユーザーID: $currentUserId');
      }

      if (currentUserId == null) {
        if (kDebugMode) {
          debugPrint('📝 視聴履歴記録スキップ: ユーザー未ログイン');
        }
        return;
      }

      // 自分の投稿も視聴履歴に記録する（すべての投稿を記録）
      // userIdの比較（デバッグ用）
      final postUserId = post.userId.toString().trim();
      final currentUserIdStr = currentUserId.toString().trim();

      if (kDebugMode) {
        debugPrint(
            '📝 ユーザーID比較: post.userId="$postUserId", currentUserId="$currentUserIdStr"');
        if (postUserId.isNotEmpty && postUserId == currentUserIdStr) {
          debugPrint('📝 自分の投稿も視聴履歴に記録します');
        }
        if (postUserId.isEmpty) {
          debugPrint('⚠️ 投稿のuserIdが空です。バックエンド側で判定されます。');
        }
      }

      // 同じ投稿を連続して表示した場合は記録しない（重複防止）
      // ただし、初回表示時は必ず記録する
      if (_lastRecordedPostId == post.id.toString()) {
        if (kDebugMode) {
          debugPrint(
              '📝 視聴履歴記録スキップ: 同じ投稿を連続表示 (postId: ${post.id}, lastRecorded: $_lastRecordedPostId)');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('📝 視聴履歴記録実行: 投稿ID=${post.id} の詳細を取得して記録します');
        debugPrint('   - 投稿タイプ: ${post.postType}');
        debugPrint('   - タイトル: ${post.title}');
      }

      // 視聴履歴を記録（/api/content/playnum エンドポイントを使用）
      // 非同期で実行し、UIをブロックしない
      if (kDebugMode) {
        debugPrint('📝 視聴履歴記録: recordPlayHistoryを呼び出します (postId: ${post.id})');
        debugPrint('   - API: ${AppConfig.apiBaseUrl}/content/playnum');
        debugPrint('   - contentID: ${post.id}');
      }

      try {
        final success = await PostService.recordPlayHistory(post.id.toString());

        if (success && !_isDisposed) {
          _lastRecordedPostId = post.id.toString();
          if (kDebugMode) {
            debugPrint('✅ 視聴履歴記録完了: 投稿ID=${post.id}, タイトル=${post.title}');
            debugPrint('   - バックエンド側で視聴履歴が記録されました');
            debugPrint('   - 視聴履歴一覧を表示すると最新のデータが表示されます');
            debugPrint('   - 重複がある場合は最新分だけが残ります');
            debugPrint('   - 直近50件まで記録されます');
          }
        } else {
          if (kDebugMode) {
            debugPrint('⚠️ 視聴履歴記録失敗: 記録に失敗しました (postId: ${post.id})');
            debugPrint('   - success: $success');
            debugPrint('   - _isDisposed: $_isDisposed');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 視聴履歴記録エラー: $e');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ 視聴履歴記録例外: $e');
        debugPrint('スタックトレース: $stackTrace');
      }
    }
  }

  // 音声プレイヤー初期化メソッド
  Future<void> _initializeAudioPlayer(int postIndex) async {
    final post = _posts[postIndex];

    // 音声投稿でない場合、またはmediaUrlが空の場合は何もしない
    if (post.postType != PostType.audio ||
        post.mediaUrl == null ||
        post.mediaUrl!.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            '⚠️ 音声初期化スキップ: postType=${post.postType}, mediaUrl=${post.mediaUrl}');
      }
      return;
    }

    // すでに初期化済みの場合はスキップ
    if (_initializedAudios.contains(postIndex)) {
      return;
    }

    try {
      final audioUrl = post.mediaUrl!;

      if (kDebugMode) {
        debugPrint('🎵 音声初期化開始: $audioUrl');
      }

      final player = AudioPlayer();
      await player.setUrl(audioUrl);

      if (!_isDisposed && mounted) {
        setState(() {
          _audioPlayers[postIndex] = player;
          _initializedAudios.add(postIndex);
        });

        if (kDebugMode) {
          debugPrint('✅ 音声初期化成功: ${player.duration}');
        }
      }
    } catch (e) {
      // 音声の初期化に失敗した場合、サンプル音声で再試行
      if (kDebugMode) {
        debugPrint('❌ 音声の初期化に失敗: $e');
        debugPrint('🔄 サンプル音声で再試行...');
      }

      try {
        final sampleUrl =
            'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
        final player = AudioPlayer();
        await player.setUrl(sampleUrl);

        if (!_isDisposed && mounted) {
          setState(() {
            _audioPlayers[postIndex] = player;
            _initializedAudios.add(postIndex);
          });

          if (kDebugMode) {
            debugPrint('✅ サンプル音声で初期化成功');
          }
        }
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('❌ サンプル音声も失敗: $e2');
        }
      }
    }
  }

  // 音声の再生/停止を切り替え
  Future<void> _toggleAudioPlayback(int postIndex) async {
    final player = _audioPlayers[postIndex];

    if (player == null) {
      // プレイヤーが初期化されていない場合は初期化
      await _initializeAudioPlayer(postIndex);
      final newPlayer = _audioPlayers[postIndex];
      if (newPlayer != null) {
        setState(() {
          _currentPlayingAudio = postIndex;
        });
        await newPlayer.play();
      }
      return;
    }

    try {
      if (player.playing) {
        await player.pause();
      } else {
        // 他の音声を停止
        if (_currentPlayingAudio != null && _currentPlayingAudio != postIndex) {
          final otherPlayer = _audioPlayers[_currentPlayingAudio];
          if (otherPlayer != null) {
            await otherPlayer.pause();
          }
        }

        setState(() {
          _currentPlayingAudio = postIndex;
        });
        await player.play();
        // シークバー更新タイマーを開始
        _startSeekBarUpdateTimerAudio();
      }
    } catch (e) {
      print('音声の再生に失敗: $e');
    }
  }

  /// シークバー更新タイマーを開始（1秒ごとに更新）
  void _startSeekBarUpdateTimer() {
    _seekBarUpdateTimer?.cancel();
    _seekBarUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isDisposed &&
          mounted &&
          _currentPlayingVideo != null &&
          !_isSeeking) {
        final controller = _videoControllers[_currentPlayingVideo];
        if (controller != null && controller.value.isInitialized) {
          setState(() {
            // シークバーの更新をトリガー
          });
        } else {
          // コントローラーが初期化されていない場合はタイマーを停止
          timer.cancel();
        }
      } else if (_currentPlayingVideo == null) {
        // 動画が再生されていない場合はタイマーを停止
        timer.cancel();
      }
    });
  }

  /// 動画の再生位置が変更されたときのコールバック
  void _onVideoPositionChanged() {
    // シーク中でない場合のみ更新（シーク中は手動で更新しているため）
    if (!_isSeeking && _currentPlayingVideo != null) {
      final controller = _videoControllers[_currentPlayingVideo];
      if (controller != null && controller.value.isInitialized && mounted) {
        setState(() {
          // シークバーの更新をトリガー
        });
      }
    }
  }

  /// すべてのメディア（動画・音声）を一時停止
  void _pauseAllMedia() {
    if (kDebugMode) {
      debugPrint('⏸️ [画面遷移] すべてのメディアを一時停止');
    }

    // 動画を一時停止
    if (_currentPlayingVideo != null) {
      final controller = _videoControllers[_currentPlayingVideo];
      if (controller != null && controller.value.isInitialized) {
        controller.pause();
        if (kDebugMode) {
          debugPrint('⏸️ [画面遷移] 動画を一時停止: インデックス $_currentPlayingVideo');
        }
      }
    }

    // 音声を一時停止
    if (_currentPlayingAudio != null) {
      final player = _audioPlayers[_currentPlayingAudio];
      if (player != null) {
        player.pause();
        if (kDebugMode) {
          debugPrint('⏸️ [画面遷移] 音声を一時停止: インデックス $_currentPlayingAudio');
        }
      }
    }
  }

  /// 現在のメディア（動画・音声）を再開
  void _resumeCurrentMedia() {
    if (kDebugMode) {
      debugPrint('▶️ [画面遷移] HomeScreenに戻ったため、メディアを再開');
    }

    // 現在のインデックスのコンテンツを確認
    if (_posts.isEmpty || _currentIndex >= _posts.length) {
      return;
    }

    final currentPost = _posts[_currentIndex];

    // 動画の場合
    if (currentPost.postType == PostType.video &&
        _currentPlayingVideo == _currentIndex) {
      final controller = _videoControllers[_currentPlayingVideo];
      if (controller != null && controller.value.isInitialized) {
        controller.play();
        if (kDebugMode) {
          debugPrint('▶️ [画面遷移] 動画を再開: インデックス $_currentPlayingVideo');
        }
      }
    }

    // 音声の場合
    if (currentPost.postType == PostType.audio &&
        _currentPlayingAudio == _currentIndex) {
      final player = _audioPlayers[_currentPlayingAudio];
      if (player != null) {
        player.play();
        if (kDebugMode) {
          debugPrint('▶️ [画面遷移] 音声を再開: インデックス $_currentPlayingAudio');
        }
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
}
