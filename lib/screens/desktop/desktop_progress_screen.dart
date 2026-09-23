import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversion_item.dart';
import '../../services/batch_conversion_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/thumbnail_preview.dart';

class DesktopProgressScreen extends StatelessWidget {
  final BatchConversionService batchService;
  final SettingsService settingsService;
  final VoidCallback onBackToHome;
  final VoidCallback? onNewProject;

  const DesktopProgressScreen({
    super.key,
    required this.batchService,
    required this.settingsService,
    required this.onBackToHome,
    this.onNewProject,
  });

  void _openFolder(BuildContext context, String? folderPath) {
    if (folderPath == null || folderPath.isEmpty) return;
    try {
      if (Platform.isLinux) {
        Process.run('xdg-open', [folderPath]);
      } else if (Platform.isMacOS) {
        Process.run('open', [folderPath]);
      } else if (Platform.isWindows) {
        Process.run('explorer.exe', [folderPath]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open folder: $e')),
      );
    }
  }

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
                TextButton.icon(
                  onPressed: batchService.cancelAll,
                  icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
                  label: Text(
                    l10n.tr('cancelAll'),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              else ...[
                if (onNewProject != null)
                  ElevatedButton.icon(
                    onPressed: onNewProject,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(l10n.tr('startNewProject')),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    final outDir = settingsService.conversionSettings.outputFolder ??
                        (items.isNotEmpty ? File(items.first.sourcePath).parent.path : null);
                    _openFolder(context, outDir);
                  },
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(l10n.tr('openOutputFolder')),
                ),
              ],
              const SizedBox(width: 16),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Overall Progress Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
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
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  l10n.tr(
                                    'itemsCompleted',
                                    {'done': completed.toString(), 'total': total.toString()},
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: overall,
                                minHeight: 12,
                                backgroundColor: isDark
                                    ? const Color(0xFF1E2024)
                                    : const Color(0xFFE5E7EB),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                            if (!batchService.isProcessing && total > 0 && completed == total) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        l10n.tr('conversionCompleteMessage'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                    if (onNewProject != null)
                                      ElevatedButton.icon(
                                        onPressed: onNewProject,
                                        icon: const Icon(Icons.add_rounded, size: 16),
                                        label: Text(l10n.tr('startNewProject')),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Queue Items List
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _buildProgressItemCard(item, l10n, theme, isDark);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressItemCard(
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
        statusText = l10n.tr(
          'statusConverting',
          {'percent': (item.progress * 100).toInt().toString()},
        );
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

    final isAudio = item.isAudioInput;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                ThumbnailPreview(
                  bytes: item.thumbnailBytes,
                  size: 56,
                  placeholderIcon: isAudio
                      ? Icons.music_note_rounded
                      : Icons.videocam_rounded,
                  badgeText: item.fileExtension.toUpperCase(),
                  badgeColor: isAudio ? Colors.blueAccent : Colors.purpleAccent,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (item.isTargetAudio ? Colors.blue : Colors.purple).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.fileExtension.toUpperCase()} ➔ ${item.targetFormat.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: item.isTargetAudio ? Colors.blue : Colors.purple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                          if (item.outputPath != null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '➔ ${item.outputPath!.split('/').last.split('\\').last}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Inline Retry or Cancel
                if (item.status == ConversionStatus.failed ||
                    item.status == ConversionStatus.cancelled)
                  IconButton(
                    tooltip: l10n.tr('retryItem'),
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8)),
                    onPressed: () {
                      batchService.retryItem(
                        item,
                        settingsService.conversionSettings,
                      );
                    },
                  )
                else if (item.status == ConversionStatus.converting)
                  IconButton(
                    tooltip: l10n.tr('cancelItem'),
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                    onPressed: batchService.cancelCurrent,
                  ),
              ],
            ),

            if (item.status == ConversionStatus.converting) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress > 0 ? item.progress : null,
                  minHeight: 6,
                  backgroundColor: isDark ? const Color(0xFF1E2024) : const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                ),
              ),
            ],

            if (item.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.errorMessage!,
                  style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
