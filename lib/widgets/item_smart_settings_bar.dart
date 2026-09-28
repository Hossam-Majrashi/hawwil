import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/conversion_item.dart';
import '../services/batch_conversion_service.dart';

class ItemSmartSettingsBar extends StatelessWidget {
  final ConversionItem item;
  final BatchConversionService batchService;
  final bool isCompact;

  const ItemSmartSettingsBar({
    super.key,
    required this.item,
    required this.batchService,
    this.isCompact = false,
  });

  static String formatFps(double fps) {
    if (fps == fps.roundToDouble()) {
      return fps.toInt().toString();
    }
    final s = fps.toStringAsFixed(2);
    if (s.endsWith('0')) {
      return fps.toStringAsFixed(1);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentResolution = item.resolutionOverride ?? '1920x1080';
    final effectiveFps = item.fpsOverride ?? (item.isAudioInput ? 2.0 : 30.0);
    final fpsLabel = '${formatFps(effectiveFps)} ${l10n.tr('fps')}';

    final bgColor = isDark ? const Color(0xFF1E2024) : const Color(0xFFF3F4F6);
    final borderColor = isDark ? const Color(0xFF2C3036) : const Color(0xFFE5E7EB);

    final content = [
      // Badge / Label
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: 5),
          Text(
            l10n.tr('suggestedSettings'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
      if (!isCompact) const SizedBox(width: 12),
      if (isCompact) const SizedBox(height: 6),

      // Resolution selector pill
      _buildResolutionSelector(context, l10n, isDark, currentResolution),

      if (!isCompact) const SizedBox(width: 8),
      if (isCompact) const SizedBox(height: 6),

      // FPS selector pill
      _buildFpsSelector(context, l10n, isDark, effectiveFps, fpsLabel),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: isCompact ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            )
          : Row(
              children: [
                content[0],
                content[1],
                content[2],
                content[3],
                content[4],
              ],
            ),
    );
  }

  Widget _buildResolutionSelector(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
    String currentResolution,
  ) {
    const commonResolutions = [
      '3840x2160',
      '1920x1080',
      '1280x720',
      '1080x1080',
      '720x1280',
      '854x480',
      '640x360',
    ];

    final List<String> options = [];
    if (!commonResolutions.contains(currentResolution)) {
      options.add(currentResolution);
    }
    options.addAll(commonResolutions);

    return PopupMenuButton<String>(
      tooltip: l10n.tr('resolution'),
      initialValue: currentResolution,
      onSelected: (val) {
        if (val == '__custom__') {
          _showCustomResolutionDialog(context, l10n);
        } else {
          batchService.setItemResolution(item, val);
        }
      },
      itemBuilder: (ctx) => [
        ...options.map((res) {
          final isSelected = res == currentResolution;
          return PopupMenuItem<String>(
            value: res,
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.crop_free_rounded,
                  size: 15,
                  color: isSelected ? const Color(0xFF10B981) : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  res == item.resolutionOverride
                      ? '$res (${l10n.tr('suggested')})'
                      : res,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF10B981) : null,
                  ),
                ),
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: '__custom__',
          child: Row(
            children: [
              const Icon(Icons.edit_rounded, size: 15, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                l10n.tr('customResolution'),
                style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282B30) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF3F444D) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.aspect_ratio_rounded, size: 13, color: Colors.cyanAccent),
            const SizedBox(width: 5),
            Text(
              currentResolution,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildFpsSelector(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
    double effectiveFps,
    String fpsLabel,
  ) {
    final List<double> commonFps = [60, 50, 30, 29.97, 25, 24, 23.976, 15, 2, 1];
    final List<double> options = [];
    final currentRounded = double.parse(effectiveFps.toStringAsFixed(2));
    if (!commonFps.any((f) => (f - currentRounded).abs() < 0.01)) {
      options.add(currentRounded);
    }
    options.addAll(commonFps);

    return PopupMenuButton<String>(
      tooltip: l10n.tr('frameRate'),
      initialValue: effectiveFps.toString(),
      onSelected: (val) {
        if (val == '__custom__') {
          _showCustomFpsDialog(context, l10n);
        } else {
          final parsed = double.tryParse(val);
          if (parsed != null && parsed > 0) {
            batchService.setItemFps(item, parsed);
          }
        }
      },
      itemBuilder: (ctx) => [
        ...options.map((fps) {
          final isSelected = (fps - effectiveFps).abs() < 0.01;
          final isSuggested = item.fpsOverride != null && (fps - item.fpsOverride!).abs() < 0.01;
          return PopupMenuItem<String>(
            value: fps.toString(),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.speed_rounded,
                  size: 15,
                  color: isSelected ? const Color(0xFF10B981) : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  isSuggested
                      ? '${formatFps(fps)} ${l10n.tr('fps')} (${l10n.tr('suggested')})'
                      : '${formatFps(fps)} ${l10n.tr('fps')}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF10B981) : null,
                  ),
                ),
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: '__custom__',
          child: Row(
            children: [
              const Icon(Icons.edit_rounded, size: 15, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                l10n.tr('customFps'),
                style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282B30) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF3F444D) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed_rounded, size: 13, color: Colors.amberAccent),
            const SizedBox(width: 5),
            Text(
              fpsLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showCustomResolutionDialog(BuildContext context, AppLocalizations l10n) {
    final current = item.resolutionOverride ?? '1920x1080';
    final parts = current.split('x');
    final wCtrl = TextEditingController(text: parts.isNotEmpty ? parts[0] : '1920');
    final hCtrl = TextEditingController(text: parts.length > 1 ? parts[1] : '1080');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tr('customResolution'), style: const TextStyle(fontSize: 16)),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: wCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Width', hintText: '1920'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('×', style: TextStyle(fontSize: 20)),
            ),
            Expanded(
              child: TextField(
                controller: hCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Height', hintText: '1080'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final w = int.tryParse(wCtrl.text.trim());
              final h = int.tryParse(hCtrl.text.trim());
              if (w != null && h != null && w > 0 && h > 0) {
                final evenW = w.isEven ? w : w - 1;
                final evenH = h.isEven ? h : h - 1;
                batchService.setItemResolution(item, '${evenW}x$evenH');
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.tr('apply')),
          ),
        ],
      ),
    );
  }

  void _showCustomFpsDialog(BuildContext context, AppLocalizations l10n) {
    final effective = item.fpsOverride ?? (item.isAudioInput ? 2.0 : 30.0);
    final fpsCtrl = TextEditingController(text: formatFps(effective));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tr('customFps'), style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: fpsCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.tr('frameRate'),
            hintText: 'e.g. 24 or 29.97',
            suffixText: l10n.tr('fps'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(fpsCtrl.text.trim());
              if (val != null && val > 0 && val <= 240) {
                batchService.setItemFps(item, val);
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.tr('apply')),
          ),
        ],
      ),
    );
  }
}
