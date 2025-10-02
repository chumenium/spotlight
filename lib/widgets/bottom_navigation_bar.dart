import 'package:flutter/material.dart';
import '../utils/spotlight_colors.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
            return Container(
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(
                        icon: Icons.flashlight_on_outlined,
                        activeIcon: Icons.flashlight_on,
                        index: 0,
                      ),
                      _buildNavItem(
                        icon: Icons.search_outlined,
                        activeIcon: Icons.search,
                        index: 1,
                      ),
                      _buildNavItem(
                        icon: Icons.add_outlined,
                        activeIcon: Icons.add,
                        index: 2,
                        isCenter: true,
                      ),
                      _buildNavItem(
                        icon: Icons.notifications_outlined,
                        activeIcon: Icons.notifications,
                        index: 3,
                      ),
                      _buildNavItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        index: 4,
                      ),
                    ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required int index,
    bool isCenter = false,
  }) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: isCenter ? 80 : 70, // 固定幅
        height: 50, // 固定高さ（バーの高さいっぱい）
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: isCenter 
            ? Center(
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected 
                      ? SpotLightColors.getSpotlightColor(index)
                      : Colors.grey[400],
                  size: 28,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected 
                        ? SpotLightColors.getSpotlightColor(index)
                        : Colors.grey[400],
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getLabelText(index),
                    style: TextStyle(
                      color: isSelected 
                          ? SpotLightColors.getSpotlightColor(index)
                          : Colors.grey[400],
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
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
        return 'スポットライト';
      case 3:
        return '通知';
      case 4:
        return 'プロフィール';
      default:
        return '';
    }
  }
}
