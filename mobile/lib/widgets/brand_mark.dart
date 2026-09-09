import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/site_settings_provider.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 28,
    this.color = Colors.white,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final src = context.watch<SiteSettingsProvider>().cartLogoUrl.trim();

    if (src.isEmpty) {
      return Icon(Icons.shopping_cart_rounded, size: size, color: color);
    }

    if (src.startsWith('data:image')) {
      final bytes = _decodeDataUrl(src);
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.shopping_cart_rounded, size: size, color: color),
        );
      }
    }

    return Image.network(
      src,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.shopping_cart_rounded, size: size, color: color),
    );
  }

  Uint8List? _decodeDataUrl(String value) {
    try {
      final parts = value.split(',');
      if (parts.length < 2) return null;
      return base64Decode(parts.last);
    } catch (_) {
      return null;
    }
  }
}
