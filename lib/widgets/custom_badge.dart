import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeVariant {
  id,
  personal,
  contact,
  financial,
  sensitive,
  health,
  biometric,
  location,
  neutral
}

class CustomBadge extends StatelessWidget {
  final String text;
  final BadgeVariant variant;
  final bool small;

  const CustomBadge({
    super.key,
    required this.text,
    this.variant = BadgeVariant.neutral,
    this.small = false,
  });

  bool get _isNeutral => variant == BadgeVariant.neutral;

  Color _getBackgroundColor() {
    switch (variant) {
      case BadgeVariant.id:
        return AppColors.primary100;
      case BadgeVariant.personal:
        return AppColors.info100;
      case BadgeVariant.contact:
        return AppColors.success100;
      case BadgeVariant.financial:
        return AppColors.warning100;
      case BadgeVariant.sensitive:
        return AppColors.danger100;
      case BadgeVariant.health:
        return const Color(0xFFFCE7F3); // pink-100
      case BadgeVariant.biometric:
        return AppColors.primary100;
      case BadgeVariant.location:
        return const Color(0xFFCCFBF1); // teal-100
      case BadgeVariant.neutral:
        return AppColors.gray100;
    }
  }

  Color _getTextColor() {
    switch (variant) {
      case BadgeVariant.id:
        return AppColors.primary700;
      case BadgeVariant.personal:
        return AppColors.info700;
      case BadgeVariant.contact:
        return AppColors.success700;
      case BadgeVariant.financial:
        return AppColors.warning700;
      case BadgeVariant.sensitive:
        return AppColors.danger700;
      case BadgeVariant.health:
        return const Color(0xFF9F1239); // pink-800
      case BadgeVariant.biometric:
        return AppColors.primary700;
      case BadgeVariant.location:
        return const Color(0xFF115E59); // teal-800
      case BadgeVariant.neutral:
        return AppColors.gray700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _isNeutral ? cs.surfaceContainerHighest : _getBackgroundColor(),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w500,
          color: _isNeutral ? cs.onSurface : _getTextColor(),
          height: 1.2,
        ),
      ),
    );
  }
}
