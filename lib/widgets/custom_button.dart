import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ButtonVariant { primary, secondary, success, danger, outline }

enum ButtonSize { sm, md, lg }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.loading = false,
    this.fullWidth = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Definir cores baseado na variante
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (variant) {
      case ButtonVariant.primary:
        backgroundColor = AppColors.primary600;
        foregroundColor = Colors.white;
        break;
      case ButtonVariant.secondary:
        backgroundColor = cs.surfaceContainerHighest;
        foregroundColor = cs.onSurface;
        break;
      case ButtonVariant.success:
        backgroundColor = AppColors.success600;
        foregroundColor = Colors.white;
        break;
      case ButtonVariant.danger:
        backgroundColor = AppColors.danger600;
        foregroundColor = Colors.white;
        break;
      case ButtonVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = cs.primary;
        borderSide = BorderSide(color: cs.primary, width: 1.5);
        break;
    }

    // Definir padding baseado no tamanho
    EdgeInsets padding;
    double fontSize;

    switch (size) {
      case ButtonSize.sm:
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
        fontSize = 12;
        break;
      case ButtonSize.md:
        padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
        fontSize = 14;
        break;
      case ButtonSize.lg:
        padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
        fontSize = 16;
        break;
    }

    final buttonChild = loading
        ? SizedBox(
            height: fontSize + 2,
            width: fontSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 2),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    if (variant == ButtonVariant.outline) {
      return OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: padding,
          foregroundColor: foregroundColor,
          side: borderSide,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: fullWidth ? const Size(double.infinity, 0) : null,
        ),
        child: buttonChild,
      );
    }

    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: padding,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        minimumSize: fullWidth ? const Size(double.infinity, 0) : null,
      ).copyWith(
        elevation: WidgetStateProperty.resolveWith<double>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.hovered)) return 2;
            if (states.contains(WidgetState.pressed)) return 0;
            return 0;
          },
        ),
      ),
      child: buttonChild,
    );
  }
}
