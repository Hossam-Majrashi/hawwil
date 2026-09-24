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
      allowedExtensions: ConversionItem.allAllowedInputExtensions,
    );

    if (files.isNotEmpty) {
      final paths = files.map((f) => f.name).toList();
      widget.batchService.addFiles(
        paths,
        defaultVideoTarget: _projectSettings.defaultVideoOutputFormat,
      );
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

                                  return Card(
                                    child: ListTile(
                                      leading: ThumbnailPreview(
                                        bytes: item.thumbnailBytes,
                                        size: 48,
                                        placeholderIcon: (item.isAudioInput || item.hasVideoStream == false)
                                            ? Icons.music_note_rounded
                                            : Icons.videocam_rounded,
                                        badgeText: item.fileExtension.toUpperCase(),
                                        badgeColor: (item.isAudioInput || item.hasVideoStream == false)
                                            ? Colors.blueAccent
                                            : Colors.purpleAccent,
                                      ),
                                      title: Text(item.fileName, maxLines: 1),
                                      subtitle: PopupMenuButton<String>(
                                        tooltip: l10n.tr('targetFormat'),
                                        initialValue: item.targetFormat,
                                        onSelected: (val) {
                                          widget.batchService.setTargetFormat(item, val);
                                        },
                                        itemBuilder: (context) {
                                          if (item.isAudioInput) {
                                            return ConversionItem.supportedVideoFormats.map(
                                              (fmt) => PopupMenuItem(
                                                value: fmt,
                                                child: Text(l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}')),
                                              ),
                                            ).toList();
                                          } else {
                                            return [
                                              ...ConversionItem.supportedAudioOutputFormats.map(
                                                (fmt) => PopupMenuItem(
                                                  value: fmt,
                                                  child: Text(l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}')),
                                                ),
                                              ),
                                              const PopupMenuDivider(),
                                              ...ConversionItem.supportedVideoFormats.map(
                                                (fmt) => PopupMenuItem(
                                                  value: fmt,
                                                  child: Text(l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}')),
                                                ),
                                              ),
                                            ];
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${item.fileExtension.toUpperCase()} ➔ ${item.targetFormat.toUpperCase()}',
                                                style: TextStyle(
                                                  color: item.isTargetAudio ? Colors.blue : Colors.purple,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_drop_down_rounded,
                                                size: 16,
                                                color: item.isTargetAudio ? Colors.blue : Colors.purple,
                                              ),
                                            ],
                                          ),
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
                          Text(l10n.tr('videoOutputFormatBatch'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _projectSettings.defaultVideoOutputFormat,
                            items: ConversionSettings.allOutputFormatsForVideos.map((fmt) {
                              return DropdownMenuItem(
                                value: fmt,
                                child: Text(
                                  l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _projectSettings.defaultVideoOutputFormat = val);
                                widget.batchService.setBatchTargetFormat(val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(l10n.tr('resolution'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _projectSettings.defaultResolution,
                            items: ConversionSettings.availableResolutions.map((r) {
                              return DropdownMenuItem(
                                value: r,
                                child: Text(r == 'original' ? l10n.tr('resOriginal') : r),
                              );
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
                              return DropdownMenuItem(
                                value: b,
                                child: Text(b == 'auto' ? l10n.tr('bitrateAuto') : b),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _projectSettings.defaultVideoBitrate = val);
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(l10n.tr('audioBitrate'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _projectSettings.defaultAudioBitrate,
                            items: ConversionSettings.availableAudioBitrates.map((a) {
                              return DropdownMenuItem(
                                value: a,
                                child: Text(a == 'auto' ? l10n.tr('audioBitrateAuto') : a),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _projectSettings.defaultAudioBitrate = val);
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
