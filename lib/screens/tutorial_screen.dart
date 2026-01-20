import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
    this.nextScreen,
    this.onFinished,
  });

  final Widget? nextScreen;
  final VoidCallback? onFinished;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  final List<_TutorialPageData> _pages = const [
    _TutorialPageData(
      icon: Icons.home_filled,
      title: 'ホーム',
      description: '縦スワイプで投稿を楽しめます。気に入った投稿はスポットライトで応援。',
    ),
    _TutorialPageData(
      icon: Icons.search,
      title: '検索',
      description: '気になる投稿を検索。タグからも探せます。',
    ),
    _TutorialPageData(
      icon: Icons.add_circle_outline,
      title: '投稿',
      description: '動画・画像・音声を投稿できます。あなたの作品を世界に発信しましょう。',
    ),
    _TutorialPageData(
      icon: Icons.notifications_none,
      title: '通知',
      description: 'いいねやコメントを確認できます。',
    ),
    _TutorialPageData(
      icon: Icons.person_outline,
      title: 'プロフィール',
      description: 'プロフィール編集や設定、アカウント管理ができます。アイコンの変更は自分のアイコンをタップするだけ。',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finishTutorial() {
    if (!mounted) return;
    if (widget.onFinished != null) {
      widget.onFinished!();
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    if (widget.nextScreen != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.nextScreen!),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finishTutorial,
                child: const Text(
                  'スキップ',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          page.icon,
                          size: 96,
                          color: const Color(0xFFFF6B35),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          page.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) {
                  final isActive = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 14 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFFF6B35)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () {
                    if (isLast) {
                      _finishTutorial();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child: Text(
                    isLast ? 'はじめる' : '次へ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TutorialPageData {
  final IconData icon;
  final String title;
  final String description;

  const _TutorialPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
}
