import 'dart:ui';

import 'package:flutter/material.dart';

class BlurAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final bool? centerTitle;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? actions;
  final double? toolbarHeight;
  final PreferredSizeWidget? bottom;
  final double? elevation;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool? automaticallyImplyLeading;
  final double? titleSpacing;

  const BlurAppBar({
    super.key,
    this.title,
    this.centerTitle,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.toolbarHeight,
    this.bottom,
    this.elevation,
    this.backgroundColor,
    this.foregroundColor,
    this.automaticallyImplyLeading,
    this.titleSpacing,
  });

  @override
  Size get preferredSize {
    final height = (toolbarHeight ?? kToolbarHeight) +
        (bottom?.preferredSize.height ?? 0);
    return Size.fromHeight(height);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double glassOpacityPercent = 6;
    final glassOpacity = glassOpacityPercent / 100;
    final baseColor = backgroundColor ?? Colors.transparent;
    final blurColor = baseColor == Colors.transparent
        ? Color.fromRGBO(255, 255, 255, glassOpacity)
        : baseColor.withOpacity(glassOpacity);

    return AppBar(
      title: title,
      centerTitle: centerTitle,
      leading: leading,
      leadingWidth: leadingWidth,
      actions: actions,
      titleSpacing: titleSpacing,
      toolbarHeight: toolbarHeight,
      bottom: bottom,
      elevation: elevation ?? 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: foregroundColor ?? theme.appBarTheme.foregroundColor,
      automaticallyImplyLeading: automaticallyImplyLeading ?? true,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: blurColor,
          ),
        ),
      ),
    );
  }
}
