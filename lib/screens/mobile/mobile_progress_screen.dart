import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversion_item.dart';
import '../../services/batch_conversion_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/thumbnail_preview.dart';

class MobileProgressScreen extends StatelessWidget {
  final BatchConversionService batchService;
  final SettingsService settingsService;
  final VoidCallback onBackToHome;
  final VoidCallback? onNewProject;

  const MobileProgressScreen({
    super.key,
    required this.batchService,
    required this.settingsService,
    required this.onBackToHome,
    this.onNewProject,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: batchService,
      builder: (context, _) {
        final overall = batchService.overallProgress;
        final items = batchService.items;
        final completed = batchService.completedCount;
        final total = batchService.totalCount;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.tr('screenProgress')),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBackToHome,
            ),
            actions: [
              if (batchService.isProcessing)
                IconButton(
                  tooltip: l10n.tr('cancelAll'),
                  icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
                  onPressed: batchService.cancelAll,
                )
              else if (onNewProject != null)
                IconButton(
                  tooltip: l10n.tr('startNewProject'),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: onNewProject,
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Overall Progress Card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.tr(
                                  'overallProgress',
                                  {'percent': (overall * 100).toInt().toString()},
                                ),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '$completed / $total',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: overall,
                              minHeight: 8,
                              backgroundColor: isDark
                                  ? const Color(0xFF1E2024)
                                  : const Color(0xFFE5E7EB),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                          if (!batchService.isProcessing && total > 0 && completed == total) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          l10n.tr('conversionCompleteMessage'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (onNewProject != null) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: onNewProject,
                                        icon: const Icon(Icons.add_rounded, size: 16),
                                        label: Text(l10n.tr('startNewProject')),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Items List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildMobileProgressItem(item, l10n, theme, isDark);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileProgressItem(
    ConversionItem item,
    AppLocalizations l10n,
    ThemeData theme,
    bool isDark,
  ) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (item.status) {
      case ConversionStatus.completed:
        statusColor = const Color(0xFF10B981);
        statusText = l10n.tr('statusCompleted');
        statusIcon = Icons.check_circle_rounded;
        break;
      case ConversionStatus.failed:
        statusColor = Colors.redAccent;
        statusText = l10n.tr('statusFailed');
        statusIcon = Icons.error_outline_rounded;
        break;
      case ConversionStatus.cancelled:
        statusColor = Colors.amber;
        statusText = l10n.tr('statusCancelled');
        statusIcon = Icons.cancel_outlined;
        break;
      case ConversionStatus.converting:
        statusColor = const Color(0xFF38BDF8);
        statusText = '${(item.progress * 100).toInt()}%';
        statusIcon = Icons.sync_rounded;
        break;
      case ConversionStatus.extractingThumbnail:
        statusColor = Colors.purpleAccent;
        statusText = l10n.tr('loading');
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case ConversionStatus.queued:
        statusColor = Colors.grey;
        statusText = l10n.tr('statusQueued');
        statusIcon = Icons.schedule_rounded;
        break;
    }

    final isMp3ToMp4 = item.direction == ConversionDirection.mp3ToMp4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                ThumbnailPreview(
                  bytes: item.thumbnailBytes,
                  size: 48,
                  placeholderIcon: isMp3ToMp4
                      ? Icons.music_note_rounded
                      : Icons.videocam_rounded,
                  badgeText: isMp3ToMp4 ? 'MP3' : 'MP4',
                  badgeColor: isMp3ToMp4 ? Colors.blueAccent : Colors.purpleAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (item.status == ConversionStatus.failed ||
                    item.status == ConversionStatus.cancelled)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: () {
                      batchService.retryItem(
                        item,
                        settingsService.conversionSettings,
                      );
                    },
                  )
                else if (item.status == ConversionStatus.converting)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                    onPressed: batchService.cancelCurrent,
                  ),
              ],
            ),
            if (item.status == ConversionStatus.converting) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress > 0 ? item.progress : null,
                  minHeight: 4,
                  backgroundColor: isDark ? const Color(0xFF1E2024) : const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                ),
              ),
            ],
            if (item.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                item.errorMessage!,
                style: const TextStyle(fontSize: 10, color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
