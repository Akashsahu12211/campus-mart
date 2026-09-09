import 'dart:convert';

import 'package:flutter/material.dart';

class AppImage extends StatelessWidget {
  final String? source;
  final BoxFit fit;
  final Widget? placeholder;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;

  const AppImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    final value = source?.trim() ?? '';
    final fallback = placeholder ??
        Container(
          color: const Color(0xFF1E2438),
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              color: Color(0xFF4A5568),
            ),
          ),
        );

    if (value.isEmpty) {
      return SizedBox(width: width, height: height, child: fallback);
    }

    if (value.startsWith('data:image')) {
      try {
        final bytes = base64Decode(value.split(',').last);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          filterQuality: FilterQuality.low,
        );
      } catch (_) {
        return SizedBox(width: width, height: height, child: fallback);
      }
    }

    return Image.network(
      value,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
