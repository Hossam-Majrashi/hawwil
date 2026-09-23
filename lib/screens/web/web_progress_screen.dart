import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversion_item.dart';
import '../../services/batch_conversion_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/thumbnail_preview.dart';

class WebProgressScreen extends StatelessWidget {
  final BatchConversionService batchService;
  final SettingsService settingsService;
  final VoidCallback onBackToHome;
  final VoidCallback? onNewProject;

  const WebProgressScreen({
    super.key,
    required this.batchService,
    required this.settingsService,
    required this.onBackToHome,
    this.onNewProject,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: batchService,
      builder: (context, _) {
        final overall = batchService.overallProgress;
        final items = batchService.items;

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.tr('screenProgress')),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBackToHome,
            ),
            actions: [
              if (onNewProject != null)
                TextButton.icon(
                  onPressed: onNewProject,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.tr('startNewProject')),
                ),
              const SizedBox(width: 16),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    // Web Notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.tr('webNoticeDesc'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Overall Progress
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.tr(
                                'overallProgress',
                                {'percent': (overall * 100).toInt().toString()},
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: overall,
                                minHeight: 8,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Items
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];

                          return Card(
                            child: ListTile(
                              leading: ThumbnailPreview(
                                bytes: item.thumbnailBytes,
                                size: 48,
                                badgeText: item.fileExtension.toUpperCase(),
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(item.fileName, maxLines: 1)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: (item.isTargetAudio ? Colors.blue : Colors.purple).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
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
                              subtitle: Text(
                                item.errorMessage ??
                                    (item.status == ConversionStatus.completed
                                        ? l10n.tr('statusCompleted')
                                        : (item.status == ConversionStatus.converting
                                            ? '${(item.progress * 100).toInt()}%'
                                            : l10n.tr('statusQueued'))),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: item.errorMessage != null
                                       ? Colors.redAccent
                                       : (item.status == ConversionStatus.completed
                                           ? const Color(0xFF10B981)
                                           : Colors.grey),
                                ),
                              ),
                            ),
                          );
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
}
