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

class DesktopCreateProjectScreen extends StatefulWidget {
  final BatchConversionService batchService;
  final SettingsService settingsService;
  final VoidCallback onStartConversion;
  final VoidCallback onBack;

  const DesktopCreateProjectScreen({
    super.key,
    required this.batchService,
    required this.settingsService,
    required this.onStartConversion,
    required this.onBack,
  });

  @override
  State<DesktopCreateProjectScreen> createState() =>
      _DesktopCreateProjectScreenState();
}

class _DesktopCreateProjectScreenState extends State<DesktopCreateProjectScreen> {
  late ConversionSettings _projectSettings;
  HwAccelInfo? _hwAccelInfo;

  @override
  void initState() {
    super.initState();
    _projectSettings = widget.settingsService.conversionSettings.copyWith();
    widget.batchService.addListener(_onBatchServiceUpdated);

    // If queue contains already-completed items from a previous conversion, clear them
    if (!widget.batchService.isProcessing && widget.batchService.hasCompletedItems) {
      widget.batchService.clearCompleted();
    }

    FFmpegService.detectHardwareAcceleration().then((info) {
      if (mounted) {
        setState(() => _hwAccelInfo = info);
      }
    });
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

  Future<void> _pickOutputFolder() async {
    final selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory != null && mounted) {
      setState(() {
        _projectSettings.outputFolder = selectedDirectory;
      });
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  void _showMetadataDialog(ConversionItem item) {
    final l10n = AppLocalizations.of(context);
    final titleCtrl = TextEditingController(text: item.title ?? '');
    final artistCtrl = TextEditingController(text: item.artist ?? '');
    final albumCtrl = TextEditingController(text: item.album ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tr('editMetadata')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('cancel')),
          ),
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
              if (items.isNotEmpty)
                TextButton.icon(
                  onPressed: widget.batchService.clearQueue,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: Text(l10n.tr('clearQueue')),
                ),
              const SizedBox(width: 16),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 950;

              if (isWide) {
                return Row(
                  children: [
                    // Left Column: File List & Pick Zone
                    Expanded(
                      flex: 6,
                      child: _buildFileListSection(l10n, theme, isDark, items),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: isDark ? const Color(0xFF3F444D) : const Color(0xFFE5E7EB),
                    ),
                    // Right Column: Output Configuration Panel
                    SizedBox(
                      width: 380,
                      child: _buildSettingsPanel(l10n, theme, isDark, items),
                    ),
                  ],
                );
              } else {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildFileListSection(l10n, theme, isDark, items),
                      const SizedBox(height: 24),
                      _buildSettingsPanel(l10n, theme, isDark, items),
                    ],
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildFileListSection(
    AppLocalizations l10n,
    ThemeData theme,
    bool isDark,
    List<ConversionItem> items,
  ) {
    return Column(
      children: [
        // Drop/Pick Bar
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF282B30) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF3F444D) : const Color(0xFFD1D5DB),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.file_upload_outlined,
                  color: Color(0xFF38BDF8),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('pickFilesDesc'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.tr('fileQueueCount', {'count': items.length.toString()}),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.tr('pickFiles')),
              ),
            ],
          ),
        ),

        // Items List
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        size: 64,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.tr('noFilesSelected'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.tr('pickFiles')),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildFileItemCard(item, l10n, theme, isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFileItemCard(
    ConversionItem item,
    AppLocalizations l10n,
    ThemeData theme,
    bool isDark,
  ) {
    final isAudioLike = item.isAudioInput || item.hasVideoStream == false;
    final isMp3ToMp4 = item.direction == ConversionDirection.mp3ToMp4 || isAudioLike;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Thumbnail
                ThumbnailPreview(
                  bytes: item.thumbnailBytes,
                  size: 64,
                  placeholderIcon: isMp3ToMp4
                      ? Icons.music_note_rounded
                      : Icons.videocam_rounded,
                  badgeText: item.fileExtension.toUpperCase(),
                  badgeColor: isMp3ToMp4 ? Colors.blueAccent : Colors.purpleAccent,
                ),
                const SizedBox(width: 16),

                // File Details
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
                      Row(
                        children: [
                          if (item.title != null && item.title!.isNotEmpty)
                            Flexible(
                              child: Text(
                                '${item.title}${item.artist != null && item.artist!.isNotEmpty ? " • ${item.artist}" : ""}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Target Format Selector Menu
                      PopupMenuButton<String>(
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
                                child: Row(
                                  children: [
                                    const Icon(Icons.movie_rounded, size: 16, color: Colors.purpleAccent),
                                    const SizedBox(width: 8),
                                    Text(l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}')),
                                  ],
                                ),
                              ),
                            ).toList();
                          } else {
                            return [
                              ...ConversionItem.supportedAudioOutputFormats.map(
                                (fmt) => PopupMenuItem(
                                  value: fmt,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.music_note_rounded, size: 16, color: Colors.blueAccent),
                                      const SizedBox(width: 8),
                                      Text(l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}')),
                                    ],
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              ...ConversionItem.supportedVideoFormats.map(
                                (fmt) => PopupMenuItem(
                                  value: fmt,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.movie_rounded, size: 16, color: Colors.purpleAccent),
                                      const SizedBox(width: 8),
                                      Text(l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}')),
                                    ],
                                  ),
                                ),
                              ),
                            ];
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (item.isTargetAudio ? Colors.blue : Colors.purple)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (item.isTargetAudio ? Colors.blue : Colors.purple)
                                  .withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.isTargetAudio ? Icons.music_note_rounded : Icons.videocam_rounded,
                                size: 14,
                                color: item.isTargetAudio ? Colors.blue : Colors.purple,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${item.fileExtension.toUpperCase()} ➔ ${item.targetFormat.toUpperCase()}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: item.isTargetAudio ? Colors.blue : Colors.purple,
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
                    ],
                  ),
                ),

                // Item Actions
                IconButton(
                  tooltip: l10n.tr('editMetadata'),
                  icon: const Icon(Icons.edit_note_rounded, size: 22),
                  onPressed: () => _showMetadataDialog(item),
                ),
                IconButton(
                  tooltip: l10n.tr('delete'),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => widget.batchService.removeItem(item.id),
                ),
              ],
            ),

            // Extra Controls (Image Selection for MP3 or Frame Scrub for MP4)
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2024) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isMp3ToMp4
                  ? Row(
                      children: [
                        Icon(
                          item.hasEmbeddedCover || item.customImagePath != null
                              ? Icons.image_rounded
                              : Icons.image_not_supported_rounded,
                          size: 16,
                          color: item.hasEmbeddedCover || item.customImagePath != null
                              ? Colors.greenAccent
                              : Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.hasEmbeddedCover
                                ? l10n.tr('embeddedCover')
                                : (item.customImagePath != null
                                    ? l10n.tr('changeImage')
                                    : l10n.tr('noCover')),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _pickCustomImage(item),
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: Text(
                            item.thumbnailBytes == null
                                ? l10n.tr('pickImageForVideo')
                                : l10n.tr('changeImage'),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.purpleAccent),
                        const SizedBox(width: 8),
                        Text(
                          l10n.tr('scrubFrame'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 12),
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
                                setState(() {
                                  item.thumbnailBytes = frame;
                                });
                              }
                            },
                          ),
                        ),
                        Text(
                          '${item.videoScrubSeconds.toStringAsFixed(1)}s',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPanel(
    AppLocalizations l10n,
    ThemeData theme,
    bool isDark,
    List<ConversionItem> items,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: isDark ? const Color(0xFF282B30) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.tr('outputSettings'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hardware Acceleration
                  Text(l10n.tr('hardwareAcceleration'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _projectSettings.hardwareAcceleration,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      DropdownMenuItem(value: 'auto', child: Text(l10n.tr('hwAccelAuto'), style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'nvenc', child: Text(l10n.tr('hwAccelNvenc'), style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'qsv', child: Text(l10n.tr('hwAccelQsv'), style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'videotoolbox', child: Text(l10n.tr('hwAccelVideoToolbox'), style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'vaapi', child: Text(l10n.tr('hwAccelVaapi'), style: const TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'cpu_ultrafast', child: Text(l10n.tr('hwAccelCpuUltrafast'), style: const TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _projectSettings.hardwareAcceleration = val);
                      }
                    },
                  ),
                  if (_hwAccelInfo != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.speed_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _hwAccelInfo!.description,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Batch Video Output Format
                  Text(l10n.tr('videoOutputFormatBatch'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _projectSettings.defaultVideoOutputFormat,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
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
                  const SizedBox(height: 16),

                  // Resolution
                  Text(l10n.tr('resolution'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _projectSettings.defaultResolution,
                    items: ConversionSettings.availableResolutions.map((res) {
                      return DropdownMenuItem(
                        value: res,
                        child: Text(res == 'original' ? l10n.tr('resOriginal') : res),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _projectSettings.defaultResolution = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Video Bitrate
                  Text(l10n.tr('videoBitrate'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _projectSettings.defaultVideoBitrate,
                    items: ConversionSettings.availableVideoBitrates.map((br) {
                      return DropdownMenuItem(
                        value: br,
                        child: Text(br == 'auto' ? l10n.tr('bitrateAuto') : br),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _projectSettings.defaultVideoBitrate = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Audio Bitrate
                  Text(l10n.tr('audioBitrate'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _projectSettings.defaultAudioBitrate,
                    items: ConversionSettings.availableAudioBitrates.map((br) {
                      return DropdownMenuItem(
                        value: br,
                        child: Text(br == 'auto' ? l10n.tr('audioBitrateAuto') : br),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _projectSettings.defaultAudioBitrate = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Output Folder
                  Text(l10n.tr('defaultOutputFolder'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickOutputFolder,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3F444D) : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open_rounded, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _projectSettings.outputFolder ?? l10n.tr('notSet'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Start Button
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
        ],
      ),
    );
  }
}
