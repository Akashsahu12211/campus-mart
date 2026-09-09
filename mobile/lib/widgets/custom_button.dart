// lib/widgets/custom_button.dart

import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

// ── Form Field ────────────────────────────────────────────
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.validator,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppTheme.muted, letterSpacing: 0.7)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: enabled,
          style: const TextStyle(color: AppTheme.textPrim),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Category Chip ──────────────────────────────────────────
class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border2,
          ),
        ),
        child: Text(label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSec,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          )),
      ),
    );
  }
}

// ── Status Badge ───────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    Color bg, text;
    switch (status) {
      case 'AVAILABLE':
        bg = AppTheme.success.withOpacity(0.12);
        text = AppTheme.success;
        break;
      case 'SOLD':
        bg = AppTheme.danger.withOpacity(0.12);
        text = AppTheme.danger;
        break;
      case 'RESERVED':
        bg = AppTheme.warning.withOpacity(0.12);
        text = AppTheme.warning;
        break;
      default:
        bg = AppTheme.muted.withOpacity(0.12);
        text = AppTheme.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: text.withOpacity(0.3)),
      ),
      child: Text(status,
        style: TextStyle(
          color: text, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }
}
