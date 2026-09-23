import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversion_item.dart';
import '../../models/conversion_settings.dart';
import '../../services/batch_conversion_service.dart';
import '../../services/settings_service.dart';
import '../../services/ffmpeg_service.dart';
import '../../widgets/thumbnail_preview.dart';

class MobileCreateProjectScreen extends StatefulWidget {
  final BatchConversionService batchService;
  final SettingsService settingsService;
  final VoidCallback onStartConversion;
  final VoidCallback onBack;

  const MobileCreateProjectScreen({
    super.key,
    required this.batchService,
    required this.settingsService,
    required this.onStartConversion,
    required this.onBack,
  });

  @override
  State<MobileCreateProjectScreen> createState() =>
      _MobileCreateProjectScreenState();
}

class _MobileCreateProjectScreenState extends State<MobileCreateProjectScreen> {
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
      final validPaths = files.map((f) => f.path).whereType<String>().toList();
      widget.batchService.addFiles(
        validPaths,
        defaultVideoTarget: _projectSettings.defaultVideoOutputFormat,
      );
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.scheduleFrame();
      }
    }
  }

  Future<void> _pickCustomImage(ConversionItem item) async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
    );

    if (files.isNotEmpty && files.first.path != null) {
      final imgPath = files.first.path!;
      final bytes = await File(imgPath).readAsBytes();
      widget.batchService.setCustomImage(item, imgPath, bytes);
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.scheduleFrame();
      }
    }
  }

  void _showSettingsModal() {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.tr('outputSettings'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Batch Video Output Format
              Text(l10n.tr('videoOutputFormatBatch'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _projectSettings.defaultVideoOutputFormat,
                isExpanded: true,
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
                    setModalState(() => _projectSettings.defaultVideoOutputFormat = val);
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () {
                    widget.batchService.setBatchTargetFormat(_projectSettings.defaultVideoOutputFormat);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${l10n.tr('applyToAllVideos')}: ${_projectSettings.defaultVideoOutputFormat.toUpperCase()}',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 15),
                  label: Text(l10n.tr('applyToAllVideos'), style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(height: 12),
              // Resolution
              Text(l10n.tr('resolution'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _projectSettings.defaultResolution,
                items: ConversionSettings.availableResolutions.map((r) {
                  return DropdownMenuItem(value: r, child: Text(r));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => _projectSettings.defaultResolution = val);
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 12),
              // Video Bitrate
              Text(l10n.tr('videoBitrate'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _projectSettings.defaultVideoBitrate,
                items: ConversionSettings.availableVideoBitrates.map((b) {
                  return DropdownMenuItem(value: b, child: Text(b));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => _projectSettings.defaultVideoBitrate = val);
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 12),
              // Audio Bitrate
              Text(l10n.tr('audioBitrate'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _projectSettings.defaultAudioBitrate,
                items: ConversionSettings.availableAudioBitrates.map((a) {
                  return DropdownMenuItem(value: a, child: Text(a));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => _projectSettings.defaultAudioBitrate = val);
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.tr('apply')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMetadataModal(ConversionItem item) {
    final l10n = AppLocalizations.of(context);
    final titleCtrl = TextEditingController(text: item.title ?? '');
    final artistCtrl = TextEditingController(text: item.artist ?? '');
    final albumCtrl = TextEditingController(text: item.album ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.tr('editMetadata'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(labelText: l10n.tr('title')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artistCtrl,
              decoration: InputDecoration(labelText: l10n.tr('artist')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: albumCtrl,
              decoration: InputDecoration(labelText: l10n.tr('album')),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                widget.batchService.setMetadata(
                  item,
                  title: titleCtrl.text.trim(),
                  artist: artistCtrl.text.trim(),
                  album: albumCtrl.text.trim(),
                );
                Navigator.pop(ctx);
              },
              child: Text(l10n.tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.batchService,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final items = widget.batchService.items;

        return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('screenCreateProject')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            tooltip: l10n.tr('outputSettings'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showSettingsModal,
          ),
          if (items.isNotEmpty)
            IconButton(
              tooltip: l10n.tr('clearQueue'),
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: widget.batchService.clearQueue,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Add files trigger button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: Text(l10n.tr('pickFiles')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),

            // Queue List
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            size: 64,
                            color: Colors.grey.withOpacity(0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.tr('noFilesSelected'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
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
                                      size: 52,
                                      placeholderIcon: isMp3ToMp4
                                          ? Icons.music_note_rounded
                                          : Icons.videocam_rounded,
                                      badgeText: item.fileExtension.toUpperCase(),
                                      badgeColor: isMp3ToMp4
                                          ? Colors.blueAccent
                                          : Colors.purpleAccent,
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
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          PopupMenuButton<String>(
                                            tooltip: l10n.tr('targetFormat'),
                                            initialValue: item.targetFormat,
                                            onSelected: (val) {
                                              widget.batchService.setTargetFormat(item, val);
                                            },
                                            itemBuilder: (context) {
                                              if (item.isAudioInput) {
                                                return ConversionSettings.availableVideoFormats.map(
                                                  (fmt) => PopupMenuItem(
                                                    value: fmt,
                                                    child: Text(l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}')),
                                                  ),
                                                ).toList();
                                              } else {
                                                return [
                                                  PopupMenuItem(
                                                    value: 'mp3',
                                                    child: Text(l10n.tr('formatMp3')),
                                                  ),
                                                  const PopupMenuDivider(),
                                                  ...ConversionSettings.availableVideoFormats.map(
                                                    (fmt) => PopupMenuItem(
                                                      value: fmt,
                                                      child: Text(l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}')),
                                                    ),
                                                  ),
                                                ];
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (item.isTargetAudio ? Colors.blue : Colors.purple)
                                                    .withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: (item.isTargetAudio ? Colors.blue : Colors.purple)
                                                      .withOpacity(0.3),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '${item.fileExtension.toUpperCase()} ➔ ${item.targetFormat.toUpperCase()}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: item.isTargetAudio ? Colors.blue : Colors.purple,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Icon(
                                                    Icons.arrow_drop_down_rounded,
                                                    size: 16,
                                                    color: item.isTargetAudio ? Colors.blue : Colors.purple,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                                      onPressed: () => _showMetadataModal(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: () => widget.batchService.removeItem(item.id),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Sub controls
                                if (isMp3ToMp4)
                                  Row(
                                    children: [
                                      Text(
                                        item.hasEmbeddedCover
                                            ? l10n.tr('embeddedCover')
                                            : l10n.tr('noCover'),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () => _pickCustomImage(item),
                                        icon: const Icon(Icons.image_outlined, size: 14),
                                        label: Text(
                                          item.thumbnailBytes == null
                                              ? l10n.tr('pickImageForVideo')
                                              : l10n.tr('changeImage'),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      const Text('Frame:', style: TextStyle(fontSize: 11)),
                                      Expanded(
                                        child: Slider(
                                          value: item.videoScrubSeconds,
                                          min: 0.0,
                                          max: (item.durationSeconds != null && item.durationSeconds! > 0)
                                              ? item.durationSeconds!
                                              : 60.0,
                                          onChanged: (val) {
                                            widget.batchService.setVideoScrub(item, val);
                                          },
                                          onChangeEnd: (val) async {
                                            final frame = await FFmpegService.extractVideoFrame(
                                              videoPath: item.sourcePath,
                                              timestampSeconds: val,
                                            );
                                            if (frame != null) {
                                              setState(() => item.thumbnailBytes = frame);
                                            }
                                          },
                                        ),
                                      ),
                                      Text(
                                        '${item.videoScrubSeconds.toStringAsFixed(1)}s',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Start Conversion Sticky Bottom Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282B30) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF3F444D) : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: items.isEmpty
                      ? null
                      : () {
                          widget.onStartConversion();
                          widget.batchService.startBatch(_projectSettings);
                        },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    l10n.tr('startConversion', {'count': items.length.toString()}),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
