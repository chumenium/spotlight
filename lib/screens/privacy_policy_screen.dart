import 'package:flutter/material.dart';
import '../utils/spotlight_colors.dart';

/// プライバシーポリシー画面
/// App Store / Play Store準拠のプライバシーポリシーを表示
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'プライバシーポリシー',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    Icons.privacy_tip_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'プライバシーポリシー',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '最終更新日: 2024年1月1日',
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

            // 1. はじめに
            _buildSection(
              title: '1. はじめに',
              content: '''
SpotLight（以下「本アプリ」）は、ユーザーのプライバシーを尊重し、個人情報の保護に努めています。本プライバシーポリシーは、本アプリがどのように個人情報を収集、使用、保護するかについて説明します。

本アプリをご利用いただくことで、本プライバシーポリシーに同意したものとみなされます。
''',
            ),

            // 2. 収集する情報
            _buildSection(
              title: '2. 収集する情報',
              content: '''
本アプリは、以下の情報を収集する場合があります：

【認証情報】
• Firebase Authentication経由で取得する情報（Google、Twitter/Xアカウント情報）
• メールアドレス、表示名、プロフィール画像URL
• Firebase UID（一意のユーザー識別子）

【アプリ利用情報】
• 投稿内容（テキスト、画像、動画、音声）
• 視聴履歴
• 再生リスト
• コメント、いいね、シェアなどのアクション

【デバイス情報】
• デバイス識別子
• OS情報、アプリバージョン
• FCMトークン（プッシュ通知用）

【位置情報】
• 本アプリは位置情報を収集しません
''',
            ),

            // 3. 情報の利用目的
            _buildSection(
              title: '3. 情報の利用目的',
              content: '''
収集した情報は、以下の目的で利用します：

• 本アプリのサービス提供および改善
• ユーザー認証およびアカウント管理
• コンテンツの配信および表示
• プッシュ通知の送信
• 不正利用の防止およびセキュリティ対策
• お問い合わせへの対応
• 利用規約違反の調査
• 統計データの作成（個人を特定できない形式）
''',
            ),

            // 4. 第三者への提供
            _buildSection(
              title: '4. 第三者への提供',
              content: '''
本アプリは、以下の場合を除き、ユーザーの個人情報を第三者に提供することはありません：

• ユーザーの同意がある場合
• 法令に基づく場合
• 人の生命、身体または財産の保護のために必要な場合
• 公的機関からの要請がある場合

【利用する第三者サービス】
• Firebase Authentication（Google LLC）
• Firebase Cloud Messaging（Google LLC）
• Google Sign-In（Google LLC）
• Twitter/X Sign-In（Twitter, Inc.）
• CloudFront（Amazon Web Services, Inc.）
• S3（Amazon Web Services, Inc.）
''',
            ),

            // 5. データの保存とセキュリティ
            _buildSection(
              title: '5. データの保存とセキュリティ',
              content: '''
【データの保存場所】
• サーバー: 日本国内のサーバーに保存されます
• ローカル: デバイス内の安全なストレージに保存されます

【セキュリティ対策】
• HTTPS通信による暗号化
• JWTトークンによる認証
• 定期的なセキュリティ監査
• アクセス制御の実施

【データの保持期間】
• アカウントが削除されるまで、または法律で定められた期間
• ユーザーが削除をリクエストした場合、合理的な期間内に削除します
''',
            ),

            // 6. ユーザーの権利
            _buildSection(
              title: '6. ユーザーの権利',
              content: '''
ユーザーは、以下の権利を有します：

• 個人情報へのアクセス権
• 個人情報の訂正・削除権
• 個人情報の利用停止権
• データポータビリティ権
• 同意の撤回権

これらの権利を行使する場合は、アプリ内の「フィードバック」機能またはサポートメール（support@spotlight-app.click）までご連絡ください。
''',
            ),

            // 7. 子どものプライバシー
            _buildSection(
              title: '7. 子どものプライバシー',
              content: '''
本アプリは、13歳未満の子どもの個人情報を意図的に収集することはありません。

13歳未満の子どもが本アプリを利用していることが判明した場合、該当するアカウントを削除し、収集した情報を削除します。

保護者の方は、お子様のアプリ利用について監督責任を負うものとします。
''',
            ),

            // 8. Cookieおよびトラッキング技術
            _buildSection(
              title: '8. Cookieおよびトラッキング技術',
              content: '''
本アプリは、以下の技術を使用する場合があります：

• ローカルストレージ（アプリ設定の保存）
• セッション管理（認証状態の維持）
• 分析ツール（利用状況の把握）

これらは、サービス提供に必要な範囲で使用し、ユーザーのプライバシーを侵害する目的では使用しません。
''',
            ),

            // 9. プライバシーポリシーの変更
            _buildSection(
              title: '9. プライバシーポリシーの変更',
              content: '''
本プライバシーポリシーは、法令の変更やサービス改善に伴い、予告なく変更される場合があります。

重要な変更がある場合は、アプリ内通知またはメールでお知らせします。変更後も本アプリを継続してご利用いただくことで、変更後のプライバシーポリシーに同意したものとみなされます。
''',
            ),

            // 10. お問い合わせ
            _buildSection(
              title: '10. お問い合わせ',
              content: '''
プライバシーポリシーに関するご質問やご意見がございましたら、以下の方法でお問い合わせください：

【運営者情報】
運営者: SpotLight運営チーム
メール: support@spotlight-app.click
ウェブサイト: https://api.spotlight-app.click

【個人情報保護責任者】
上記連絡先までご連絡ください。
''',
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
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
            child: Text(
              content.trim(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

