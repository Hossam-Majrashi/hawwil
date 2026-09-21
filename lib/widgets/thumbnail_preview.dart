import 'dart:typed_data';
import 'package:flutter/material.dart';

class ThumbnailPreview extends StatelessWidget {
  final Uint8List? bytes;
  final double size;
  final double borderRadius;
  final IconData placeholderIcon;
  final String? badgeText;
  final Color? badgeColor;
  final BoxFit fit;
  final VoidCallback? onTap;

  const ThumbnailPreview({
    super.key,
    required this.bytes,
    this.size = 64.0,
    this.borderRadius = 12.0,
    this.placeholderIcon = Icons.music_note_rounded,
    this.badgeText,
    this.badgeColor,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content;
    if (bytes != null && bytes!.isNotEmpty) {
      content = Image.memory(
        bytes!,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(isDark),
      );
    } else {
      content = _buildPlaceholder(isDark);
    }

    final container = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282B30) : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark ? const Color(0xFF3F444D) : const Color(0xFFD1D5DB),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: content),
            if (badgeText != null)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? (isDark ? Colors.black87 : Colors.white),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black12,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: container,
      );
    }

    return container;
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Icon(
        placeholderIcon,
        size: size * 0.45,
        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
      ),
    );
  }
}
