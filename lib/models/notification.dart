import 'dart:convert';
import '../services/jwt_service.dart';
import '../config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show  debugPrint;

// ================================
// 通知の種類
// ================================
enum NotificationType {
  spotlight,
  comment,
  reply,
  trending,
  system,
}

// ================================
// 通知モデル
// ================================
class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String? username;
  final String? userAvatar;
  final String? postId;
  final String? postTitle;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.username,
    this.userAvatar,
    this.postId,
    this.postTitle,
    this.thumbnailUrl,
    required this.createdAt,
    this.isRead = false,
  });

  // --------------------------
  // JSON → NotificationItem
  // --------------------------
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['notificationID'].toString(),
      type: _typeFromString(json['type']),
      title: json['title'] ?? '',
      message: json['text'] ?? '',
      username: null,
      userAvatar: json['iconpath'],
      postId: json['contentID']?.toString(),
      postTitle: json['contenttitle'],
      thumbnailUrl: json['thumbnailpath'],
      createdAt: DateTime.parse(json['timestamp']).toLocal(),
      isRead: json['isread'] ?? false,
    );
  }

  // type を文字列 → enum に変換
  static NotificationType _typeFromString(String type) {
    switch (type) {
      case 'spotlight':
        return NotificationType.spotlight;
      case 'newcomment':
        return NotificationType.comment;
      case 'replycomment':
        return NotificationType.reply;
      case 'trending':
        return NotificationType.trending;
      case 'system':
      default:
        return NotificationType.system;
    }
  }
}

// ================================
// 通知 API クライアント
// ================================
class NotificationService {
  final String baseUrl;

  NotificationService({required this.baseUrl});

  // --------------------------
  // 通知一覧を取得
  // --------------------------
  static Future<List<NotificationItem>> fetchNotifications() async {
    final url = '${AppConfig.apiBaseUrl}/users/notification';
    final jwtToken = await JwtService.getJwtToken();
    debugPrint('アクセス先URL：$url');
    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $jwtToken",
      },
      body: jsonEncode({}),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to load notifications: ${response.body}");
    }
  // まず JSON 全体を decode
    final Map<String, dynamic> body = jsonDecode(response.body);

    // ステータスを確認（任意）
    if (body["status"] != "success") {
      throw Exception("API error: ${body["message"]}");
    }

    // data の中の配列だけを取得
    final List<dynamic> jsonList = body["data"];

    // model へ変換
    return jsonList
        .map((json) => NotificationItem.fromJson(json))
        .toList();
  }
}