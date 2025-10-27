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
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildNavItem(
                  icon: Icons.flashlight_on_outlined,
                  activeIcon: Icons.flashlight_on,
                  index: 0,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search,
                  index: 1,
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildNavItem(
                  icon: Icons.add_outlined,
                  activeIcon: Icons.add_circle_sharp,
                  index: 2,
                  isCenter: true,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.notifications_outlined,
                  activeIcon: Icons.notifications,
                  index: 3,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  index: 4,
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isCenter 
            ? Center(
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected 
                      ? SpotLightColors.getSpotlightColor(index)
                      : Colors.grey[400],
                  size: 32,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected 
                        ? SpotLightColors.getSpotlightColor(index)
                        : Colors.grey[400],
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getLabelText(index),
                    style: TextStyle(
                      color: isSelected 
                          ? SpotLightColors.getSpotlightColor(index)
                          : Colors.grey[400],
                      fontSize: 9,
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
