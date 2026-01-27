import 'package:flutter/material.dart';
import '../utils/spotlight_colors.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int unreadNotificationCount;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadNotificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      height: 80,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildNavItem(
                    context: context,
                    icon: Icons.flashlight_on_outlined,
                    activeIcon: Icons.flashlight_on,
                    index: 0,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context: context,
                    icon: Icons.search_outlined,
                    activeIcon: Icons.search,
                    index: 1,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context: context,
                    icon: Icons.add_outlined,
                    activeIcon: Icons.add_circle_sharp,
                    index: 2,
                    isCenter: true,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context: context,
                    icon: Icons.notifications_outlined,
                    activeIcon: Icons.notifications,
                    index: 3,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context: context,
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    index: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required int index,
    bool isCenter = false,
  }) {
    final isSelected = currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final iconWidget = Icon(
      isSelected ? activeIcon : icon,
      color: isSelected
          ? SpotLightColors.getSpotlightColor(index)
          : inactiveColor,
      size: isCenter ? 36 : 26,
    );

    final shouldShowDot = index == 3 && unreadNotificationCount > 0;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isCenter
            ? Center(
                child: iconWidget,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      iconWidget,
                      if (shouldShowDot)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getLabelText(index),
                    style: TextStyle(
                      color: isSelected
                          ? SpotLightColors.getSpotlightColor(index)
                          : inactiveColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }

  String _getLabelText(int index) {
    switch (index) {
      case 0:
        return 'ホーム';
      case 1:
        return '検索';
      case 2:
        return '投稿';
      case 3:
        return '通知';
      case 4:
        return 'プロフィール';
      default:
        return '';
    }
  }
}
