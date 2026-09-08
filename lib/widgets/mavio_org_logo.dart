import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/theme.dart';

class MavioOrgLogo extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final double borderRadius;
  final bool showBorder;

  // Static in-memory cache to prevent re-decoding base64 strings on each frame build
  static final Map<String, Uint8List> _base64Cache = {};

  const MavioOrgLogo({
    super.key,
    required this.logoUrl,
    this.size = 38,
    this.borderRadius = 8,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    if (logoUrl == null || logoUrl!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final raw = logoUrl!.trim();
    Uint8List? imageBytes;

    if (_base64Cache.containsKey(raw)) {
      imageBytes = _base64Cache[raw];
    } else {
      try {
        if (raw.startsWith('data:image')) {
          final commaIdx = raw.indexOf(',');
          if (commaIdx != -1) {
            imageBytes = base64Decode(raw.substring(commaIdx + 1));
            _base64Cache[raw] = imageBytes;
          }
        } else if (!raw.startsWith('http')) {
          imageBytes = base64Decode(raw);
          _base64Cache[raw] = imageBytes;
        }
      } catch (_) {}
    }

    Widget imageWidget;
    if (imageBytes != null) {
      imageWidget = Image.memory(
        imageBytes,
        width: size,
        height: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    } else if (raw.startsWith('http')) {
      imageWidget = Image.network(
        raw,
        width: size,
        height: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return Container(
            width: size,
            height: size,
            color: Colors.white,
          );
        },
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(color: AppColors.borderLight, width: 1.0) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1),
        child: imageWidget,
      ),
    );
  }
}
