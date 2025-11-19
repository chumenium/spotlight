import 'package:flutter/material.dart';
import '../utils/spotlight_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // pubspec.yamlから取得したバージョン情報
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  @override
  Widget build(BuildContext context) {
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
          'アプリについて',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SpotLightColors.primaryOrange,
                  SpotLightColors.primaryOrange.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.flashlight_on,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'SpotLight',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'バージョン $appVersion (Build $buildNumber)',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // アプリの説明
          _buildSectionTitle('アプリについて'),
          const SizedBox(height: 12),
          _buildInfoCard(
            child: const Text(
              'SpotLightは、隠れた才能を発見し、共有するためのプラットフォームです。\n\n'
              'あなたの作品やアイデアに光を当て、世界中の人々とつながりましょう。'
              'スポットライト機能でお気に入りの投稿をコレクションし、'
              'コミュニティと交流しながら、新しい才能を発見できます。',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 主な機能
          _buildSectionTitle('主な機能'),
          const SizedBox(height: 12),
          _buildFeatureCard(
            icon: Icons.flashlight_on,
            title: 'スポットライト',
            description: 'お気に入りの投稿に光を当てて、特別なコレクションを作成',
          ),
          _buildFeatureCard(
            icon: Icons.search,
            title: '検索機能',
            description: '投稿、ユーザー、タグから簡単に検索',
          ),
          _buildFeatureCard(
            icon: Icons.add_circle,
            title: '投稿作成',
            description: 'テキスト、画像、動画を投稿して才能を共有',
          ),
          _buildFeatureCard(
            icon: Icons.notifications,
            title: '通知機能',
            description: 'リアルタイムでアクションやコメントを通知',
          ),

          const SizedBox(height: 24),

          // 開発情報
          _buildSectionTitle('開発情報'),
          const SizedBox(height: 12),
          _buildInfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  icon: Icons.code,
                  label: '開発フレームワーク',
                  value: 'Flutter',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.cloud,
                  label: 'バックエンド',
                  value: 'Python3 / Flask',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.storage,
                  label: 'データベース',
                  value: 'PostgreSQL',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.cloud_upload,
                  label: 'サーバー',
                  value: 'aws EC2',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.network_cell,
                  label: 'ネットワーク',
                  value: 'aws ElasticIP',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.security,
                  label: '認証',
                  value: 'Firebase Authentication',
                ),
                
              ],
            ),
          ),

          const SizedBox(height: 24),

          // リンク
          _buildSectionTitle('リンク'),
          const SizedBox(height: 12),
          _buildLinkCard(
            icon: Icons.description,
            title: '利用規約',
            onTap: () {
              // TODO: 利用規約画面への遷移を実装
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('利用規約ページは準備中です'),
                  backgroundColor: Color(0xFF1E1E1E),
                ),
              );
            },
          ),
          _buildLinkCard(
            icon: Icons.privacy_tip,
            title: 'プライバシーポリシー',
            onTap: () {
              // TODO: プライバシーポリシー画面への遷移を実装
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('プライバシーポリシーページは準備中です'),
                  backgroundColor: Color(0xFF1E1E1E),
                ),
              );
            },
          ),
          _buildLinkCard(
            icon: Icons.email,
            title: 'お問い合わせ',
            onTap: () {
              // TODO: お問い合わせ画面への遷移を実装
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('お問い合わせページは準備中です'),
                  backgroundColor: Color(0xFF1E1E1E),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // コピーライト
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              '© 2024 SpotLight\nAll rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SpotLightColors.primaryOrange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: SpotLightColors.primaryOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.grey[400],
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinkCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: SpotLightColors.primaryOrange,
          size: 24,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
          size: 20,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

