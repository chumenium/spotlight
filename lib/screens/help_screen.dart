import 'package:flutter/material.dart';
import '../utils/spotlight_colors.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
          'ヘルプ',
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
                  Icons.help_outline,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 12),
                Text(
                  'SpotLightヘルプセンター',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'よくある質問と使い方のガイド',
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

          // 基本機能セクション
          _buildSectionTitle('基本機能'),
          const SizedBox(height: 12),
          _buildHelpCard(
            icon: Icons.flashlight_on,
            title: 'スポットライトとは？',
            description:
                'お気に入りの投稿に光を当てて、ユーザーに賞賛を送れます。スポットライトした投稿は、プロフィール画面から簡単にアクセスできます。',
          ),
          _buildHelpCard(
            icon: Icons.search,
            title: '検索機能の使い方',
            description: 'タイトル、タグから検索できます。検索履歴は自動的に保存され、よく使う検索にすばやくアクセスできます。',
          ),
          _buildHelpCard(
            icon: Icons.add_circle,
            title: '投稿の作成',
            description: '画像、動画、音声を投稿できます。中央の「+」ボタンをタップして、新しい投稿を作成しましょう。',
          ),
          _buildHelpCard(
            icon: Icons.notifications,
            title: '通知について',
            description: '他のユーザーからのスポットライト、コメントの通知を受け取れます。通知設定は端末設定画面から変更できます。',
          ),

          const SizedBox(height: 24),

          // アカウント管理セクション
          _buildSectionTitle('アカウント管理'),
          const SizedBox(height: 12),
          _buildHelpCard(
            icon: Icons.person,
            title: 'アイコンの編集',
            description: 'マイページのアイコンをタップすると好きな画像をアイコンに設定できます。また画像の削除もできます。',
          ),
          _buildHelpCard(
            icon: Icons.logout,
            title: 'ログアウト方法',
            description: 'プロフィール画面の最下部にあるログアウトボタンから、アカウントからログアウトできます。',
          ),

          const SizedBox(height: 24),

          // よくある質問セクション
          _buildSectionTitle('よくある質問'),
          const SizedBox(height: 12),
          _buildFAQCard(
            question: '投稿を削除するには？',
            answer:
                'プロフィール画面の自分の投稿一覧から該当する動画のメニューアイコンをタップし、「投稿を削除」を選択してください。削除した投稿は復元できません。',
          ),
          _buildFAQCard(
            question: 'バッジの獲得方法は？',
            answer: '自分の投稿に対して他のユーザーがスポットライトを当てると新しい上位バッジが獲得できます。',
          ),
          _buildFAQCard(
            question: '再生リストの作成方法は？',
            answer:
                '再生リストに追加したい投稿の画面左下にある再生リストアイコンを押して、新しい再生リストを作成するか、既存のリストに追加できます。',
          ),

          const SizedBox(height: 24),

          // サポート連絡先セクション
          _buildSectionTitle('お問い合わせ'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[800]!,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '問題が解決しない場合',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'サポートチームがお手伝いします。以下の方法でお問い合わせください：',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildContactItem(
                  icon: Icons.email_outlined,
                  label: 'メール',
                  value: 'support@spotlight-app.click',
                ),
                const SizedBox(height: 12),
                _buildContactItem(
                  icon: Icons.language,
                  label: 'ウェブサイト',
                  value: 'https://spotlight.app/support',
                ),
                const SizedBox(height: 12),
                _buildContactItem(
                  icon: Icons.schedule,
                  label: '対応時間',
                  value: '平日 9:00-18:00',
                ),
              ],
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

  Widget _buildHelpCard({
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
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQCard({
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconColor: SpotLightColors.primaryOrange,
        collapsedIconColor: Colors.grey[400],
        children: [
          Text(
            answer,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: SpotLightColors.primaryOrange,
          size: 20,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
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
      ],
    );
  }
}
