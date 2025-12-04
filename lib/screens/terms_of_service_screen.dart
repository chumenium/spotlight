import 'package:flutter/material.dart';
import '../utils/spotlight_colors.dart';

/// 利用規約画面
/// App Store / Play Store準拠の利用規約を表示
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          '利用規約',
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
                    Icons.description_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '利用規約',
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
              title: '第1条（適用）',
              content: '''
本利用規約（以下「本規約」）は、SpotLight（以下「本アプリ」）の利用条件を定めるものです。

本アプリをダウンロードまたは利用することにより、ユーザーは本規約に同意したものとみなされます。本規約に同意できない場合は、本アプリを利用することはできません。
''',
            ),

            // 2. 定義
            _buildSection(
              title: '第2条（定義）',
              content: '''
本規約において、以下の用語は以下の意味で使用します：

• 「本アプリ」: SpotLightアプリケーションおよび関連サービス
• 「ユーザー」: 本アプリを利用するすべての個人
• 「コンテンツ」: ユーザーが投稿するテキスト、画像、動画、音声などの情報
• 「運営者」: 本アプリの運営を行う者
• 「サービス」: 本アプリを通じて提供されるすべての機能
''',
            ),

            // 3. アカウント
            _buildSection(
              title: '第3条（アカウント）',
              content: '''
1. ユーザーは、本アプリの利用にあたり、Googleなどのソーシャルアカウントを使用してログインする必要があります。

2. ユーザーは、アカウント情報の正確性を保証する責任を負います。

3. ユーザーは、アカウントの不正使用を防止するため、パスワード等の管理を適切に行う責任を負います。

4. アカウントの不正使用が発見された場合、運営者は当該アカウントを停止または削除することができます。
''',
            ),

            // 4. 利用規約
            _buildSection(
              title: '第4条（利用規約）',
              content: '''
ユーザーは、本アプリの利用にあたり、以下の行為を行ってはなりません：

【禁止行為】
• 法令または公序良俗に違反する行為
• 犯罪行為に関連する行為
• 他のユーザーまたは第三者の権利を侵害する行為
• 他のユーザーまたは第三者に不利益、損害、不快感を与える行為
• 虚偽の情報を提供する行為
• スパム、チェーンメール、迷惑メールを送信する行為
• 本アプリの運営を妨害する行為
• 不正アクセス、ハッキング、クラッキングなどの行為
• 本アプリのリバースエンジニアリング、逆コンパイル、逆アセンブルを行う行為
• 本アプリの著作権、商標権、その他の知的財産権を侵害する行為
• その他、運営者が不適切と判断する行為
''',
            ),

            // 5. コンテンツ
            _buildSection(
              title: '第5条（コンテンツ）',
              content: '''
1. ユーザーが投稿するコンテンツの著作権は、ユーザーに帰属します。

2. ユーザーは、本アプリ上に投稿したコンテンツについて、運営者に対し、本アプリのサービス提供に必要な範囲で使用する権利を許諾します。

3. ユーザーは、投稿するコンテンツが第三者の権利を侵害しないことを保証します。

4. 運営者は、法令違反、本規約違反、または不適切と判断したコンテンツを削除することができます。

5. ユーザーは、投稿したコンテンツについて、運営者に対し、損害賠償責任を負わないことを承認します。
''',
            ),

            // 6. 知的財産権
            _buildSection(
              title: '第6条（知的財産権）',
              content: '''
1. 本アプリに関する知的財産権は、運営者または正当な権利者に帰属します。

2. ユーザーは、本アプリの知的財産権を侵害してはなりません。

3. 本アプリの商標、ロゴ、デザイン等は、運営者の財産であり、無断で使用することはできません。
''',
            ),

            // 7. 免責事項
            _buildSection(
              title: '第7条（免責事項）',
              content: '''
1. 運営者は、本アプリの提供について、以下の事項について一切の責任を負いません：

• 本アプリの完全性、正確性、有用性、特定目的への適合性
• 本アプリの中断、停止、終了、データの消失
• 本アプリの利用により生じた損害
• ユーザー間のトラブル
• 第三者による本アプリの不正利用

2. 本アプリの利用により生じた損害について、運営者は一切の責任を負いません。

3. 本アプリは、現状有姿で提供され、運営者は本アプリの瑕疵の不存在を保証しません。
''',
            ),

            // 8. サービスの変更・終了
            _buildSection(
              title: '第8条（サービスの変更・終了）',
              content: '''
1. 運営者は、予告なく本アプリの内容を変更、追加、削除することができます。

2. 運営者は、予告なく本アプリの提供を終了することができます。

3. 本アプリの提供が終了した場合、運営者はユーザーに対して一切の責任を負いません。
''',
            ),

            // 9. 利用規約の変更
            _buildSection(
              title: '第9条（利用規約の変更）',
              content: '''
1. 運営者は、必要に応じて本規約を変更することができます。

2. 本規約の変更は、本アプリ上での表示その他運営者が適当と判断する方法により通知します。

3. 変更後の本規約は、通知の時点から効力を生じるものとします。

4. 変更後の本規約に同意できない場合、ユーザーは本アプリの利用を停止することができます。
''',
            ),

            // 10. 準拠法・管轄
            _buildSection(
              title: '第10条（準拠法・管轄裁判所）',
              content: '''
1. 本規約は、日本法に準拠して解釈されます。

2. 本アプリに関する紛争については、福岡地方裁判所を第一審の専属的合意管轄裁判所とします。
''',
            ),

            // 11. お問い合わせ
            _buildSection(
              title: '第11条（お問い合わせ）',
              content: '''
本規約に関するご質問やご意見がございましたら、以下の方法でお問い合わせください：

【運営者情報】
運営者: SpotLight運営チーム
メール: support@spotlight-app.click
ウェブサイト: https://api.spotlight-app.click
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

