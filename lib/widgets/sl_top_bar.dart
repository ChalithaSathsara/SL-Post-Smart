import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Red header bar matching SLPost Smart mockup.
class SlTopBar extends StatelessWidget implements PreferredSizeWidget {
  const SlTopBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions,
    this.titleStyle,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;
  final TextStyle? titleStyle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      title: Text(title, style: titleStyle),
      actions: actions,
    );
  }
}
