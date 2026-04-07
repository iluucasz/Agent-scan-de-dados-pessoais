import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final double? elevation;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.elevation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardTheme = theme.cardTheme;

    final card = Card(
      elevation: elevation ?? cardTheme.elevation,
      color: color ?? cardTheme.color,
      shape: cardTheme.shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
      shadowColor: cardTheme.shadowColor ?? theme.shadowColor,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}
