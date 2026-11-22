import 'package:flutter/material.dart';
import 'package:pa_mobile/ui/core/app_colors.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final int maxLines;
  final Widget? suffix;
  final String? label;
  final ValueChanged<String>? onChanged;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.suffix,
    this.label,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMultiLine = !obscure && maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: isMultiLine ? 12 : 2,
          ),
          decoration: BoxDecoration(
            color: context.appSurfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorderSubtle),
          ),
          child: Row(
            crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: isMultiLine ? 2 : 0, right: 12),
                child: Icon(icon, size: 20, color: context.appPrimary),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  maxLines: obscure ? 1 : maxLines,
                  onChanged: onChanged,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: context.appOutline,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (suffix != null) suffix!,
            ],
          ),
        ),
      ],
    );
  }
}