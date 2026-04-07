import 'package:flutter/material.dart';

class CustomInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helper;
  final String? error;
  final TextEditingController? controller;
  final bool obscureText;
  final bool readOnly;
  final int? maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Widget? prefix;
  final Widget? suffix;

  const CustomInput({
    super.key,
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.controller,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.onTap,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final borderColor = error != null ? cs.error : cs.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onTap: onTap,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefix,
            suffixIcon: suffix,
            filled: true,
            fillColor: readOnly
                ? cs.surfaceContainerHighest
                : (theme.inputDecorationTheme.fillColor ?? cs.surface),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: error != null ? cs.error : cs.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.error, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        if (helper != null || error != null) ...[
          const SizedBox(height: 4),
          Text(
            error ?? helper!,
            style: TextStyle(
              fontSize: 12,
              color: error != null ? cs.error : cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
