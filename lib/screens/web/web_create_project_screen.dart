import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversion_item.dart';
import '../../models/conversion_settings.dart';
import '../../services/batch_conversion_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/thumbnail_preview.dart';

class WebCreateProjectScreen extends StatefulWidget {
  final BatchConversionService batchService;
  final SettingsService settingsService;
  final VoidCallback onStartConversion;
  final VoidCallback onBack;

  const WebCreateProjectScreen({
    super.key,
    required this.batchService,
    required this.settingsService,
    required this.onStartConversion,
    required this.onBack,
  });

  @override
  State<WebCreateProjectScreen> createState() => _WebCreateProjectScreenState();
}

class _WebCreateProjectScreenState extends State<WebCreateProjectScreen> {
  late ConversionSettings _projectSettings;

  @override
  void initState() {
    super.initState();
    _projectSettings = widget.settingsService.conversionSettings.copyWith();
    widget.batchService.addListener(_onBatchServiceUpdated);

    // If queue contains already-completed items from a previous conversion, clear them
    if (!widget.batchService.isProcessing && widget.batchService.hasCompletedItems) {
      widget.batchService.clearCompleted();
    }
  }

  @override
  void dispose() {
    widget.batchService.removeListener(_onBatchServiceUpdated);
    super.dispose();
  }

  void _onBatchServiceUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'mp4', 'm4v', 'mov', 'mkv', 'webm', 'wav'],
    );

    if (files.isNotEmpty) {
      for (final f in files) {
        final path = f.name;
        widget.batchService.addFiles([path]);
      }
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.scheduleFrame();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.batchService,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final items = widget.batchService.items;

        return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('screenCreateProject')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Items
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(l10n.tr('pickFiles')),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: items.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.tr('noFilesSelected'),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final isMp3 = item.direction == ConversionDirection.mp3ToMp4;

                                  return Card(
                                    child: ListTile(
                                      leading: ThumbnailPreview(
                                        bytes: item.thumbnailBytes,
                                        size: 48,
                                        badgeText: isMp3 ? 'MP3' : 'MP4',
                                      ),
                                      title: Text(item.fileName, maxLines: 1),
                                      subtitle: Text(
                                        isMp3 ? l10n.tr('mp3ToMp4') : l10n.tr('mp4ToMp3'),
                                        style: TextStyle(
                                          color: isMp3 ? Colors.blue : Colors.purple,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        onPressed: () => widget.batchService.removeItem(item.id),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Right Column: Output Settings
                SizedBox(
                  width: 320,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.tr('outputSettings'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.tr('resolution'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _projectSettings.defaultResolution,
                            items: ConversionSettings.availableResolutions.map((r) {
                              return DropdownMenuItem(value: r, child: Text(r));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _projectSettings.defaultResolution = val);
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(l10n.tr('videoBitrate'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _projectSettings.defaultVideoBitrate,
                            items: ConversionSettings.availableVideoBitrates.map((b) {
                              return DropdownMenuItem(value: b, child: Text(b));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _projectSettings.defaultVideoBitrate = val);
                            },
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: items.isEmpty
                                ? null
                                : () {
                                    widget.onStartConversion();
                                    widget.batchService.startBatch(_projectSettings);
                                  },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              l10n.tr('startConversion', {'count': items.length.toString()}),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
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
