import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../models/merge_media_item.dart';
import '../../models/conversion_item.dart';
import '../../services/merge_media_controller.dart';
import '../../services/settings_service.dart';
import '../../widgets/timeline_waveform_painter.dart';
import '../../widgets/image_trim_handle.dart';

class MobileMergeMediaScreen extends StatefulWidget {
  final VoidCallback onBack;
  final SettingsService? settingsService;
  final MergeMediaController? controller;

  const MobileMergeMediaScreen({
    super.key,
    required this.onBack,
    this.settingsService,
    this.controller,
  });

  @override
  State<MobileMergeMediaScreen> createState() => _MobileMergeMediaScreenState();
}

class _MobileMergeMediaScreenState extends State<MobileMergeMediaScreen> with WidgetsBindingObserver {
  late final MergeMediaController _controller;
  final ScrollController _timelineScrollController = ScrollController();

  double _baseScale = 50.0;

  String _selectedFormat = 'mp4';
  String _selectedResolution = '1920x1080';

  final List<String> _resolutions = [
    '1920x1080',
    '1280x720',
    '854x480',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = widget.controller ?? MergeMediaController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timelineScrollController.dispose();
    if (widget.controller == null) {
      _controller.dispose();
      MergeMediaController.stopAllPlayback();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _controller.pause();
      MergeMediaController.stopAllPlayback();
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    _controller.pause();
    MergeMediaController.stopAllPlayback();
    return AppExitResponse.exit;
  }

  double get _pixelsPerSecond => _controller.pixelsPerSecond;

  void _zoomAtPoint(double localX, double scaleFactor) {
    final oldScale = _controller.pixelsPerSecond;
    final targetScale = (oldScale * scaleFactor).clamp(
      MergeMediaController.minPixelsPerSecond,
      MergeMediaController.maxPixelsPerSecond,
    );
    if ((targetScale - oldScale).abs() < 0.001) return;

    final currentScroll = _timelineScrollController.hasClients ? _timelineScrollController.offset : 0.0;
    final timeAtPoint = (currentScroll + localX) / oldScale;
    final newContentX = timeAtPoint * targetScale;
    final targetScroll = newContentX - localX;

    _controller.setPixelsPerSecond(targetScale);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_timelineScrollController.hasClients) {
        final maxScroll = _timelineScrollController.position.maxScrollExtent;
        _timelineScrollController.jumpTo(targetScroll.clamp(0.0, maxScroll));
      }
    });
  }

  void _zoomAroundPlayhead(double targetZoom) {
    final oldScale = _controller.pixelsPerSecond;
    final targetScale = (MergeMediaController.defaultPixelsPerSecond * targetZoom).clamp(
      MergeMediaController.minPixelsPerSecond,
      MergeMediaController.maxPixelsPerSecond,
    );
    if ((targetScale - oldScale).abs() < 0.001) return;

    final currentPos = _controller.currentPositionSec;
    _controller.setPixelsPerSecond(targetScale);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_timelineScrollController.hasClients) {
        final playheadContentX = currentPos * _controller.pixelsPerSecond;
        final viewportWidth = _timelineScrollController.position.viewportDimension;
        final targetScroll = playheadContentX - (viewportWidth / 2);
        final maxScroll = _timelineScrollController.position.maxScrollExtent;
        _timelineScrollController.jumpTo(targetScroll.clamp(0.0, maxScroll));
      }
    });
  }

  String _formatDuration(double seconds) => _controller.formatTimecode(seconds);

  void _showImageDurationDialog(MergeMediaItem item) {
    final l10n = AppLocalizations.of(context);
    double sec = item.durationInSeconds;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_rounded, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Text(l10n.tr('adjustDuration'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              Text(
                '${sec.toStringAsFixed(1)} ${l10n.tr('seconds')}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
              ),
              Slider(
                value: sec,
                min: 1.0,
                max: 30.0,
                divisions: 58,
                label: '${sec.toStringAsFixed(1)}s',
                onChanged: (val) {
                  setSheetState(() => sec = val);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove),
                    onPressed: sec > 1.0 ? () => setSheetState(() => sec = (sec - 1.0).clamp(1.0, 30.0)) : null,
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: sec < 30.0 ? () => setSheetState(() => sec = (sec + 1.0).clamp(1.0, 30.0)) : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _controller.updateImageDuration(
                      item.id,
                      Duration(milliseconds: (sec * 1000).round()),
                    );
                    Navigator.pop(ctx);
                  },
                  child: Text(l10n.tr('apply')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportDialog() {
    final l10n = AppLocalizations.of(context);
    if (!_controller.hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tr('noVisualItemsWarning')),
          backgroundColor: Colors.amber[800],
        ),
      );
      return;
    }

    if (_controller.isAudioOnly && !ConversionItem.supportedAudioOutputFormats.contains(_selectedFormat)) {
      _selectedFormat = 'mp3';
    } else if (!_controller.isAudioOnly &&
        !ConversionItem.supportedVideoFormats.contains(_selectedFormat) &&
        !ConversionItem.supportedAudioOutputFormats.contains(_selectedFormat)) {
      _selectedFormat = 'mp4';
    }

    showDialog(
      context: context,
      barrierDismissible: !_controller.isExporting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return ListenableBuilder(
            listenable: _controller,
            builder: (ctx, _) {
              if (_controller.isExporting) {
                return AlertDialog(
                  title: Row(
                    children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text(l10n.tr('exportingMerge')),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(value: _controller.exportProgress),
                      const SizedBox(height: 12),
                      Text('${(_controller.exportProgress * 100).toStringAsFixed(0)}%'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _controller.cancelExport();
                        Navigator.pop(ctx);
                      },
                      child: Text(l10n.tr('cancel')),
                    ),
                  ],
                );
              }

              return AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.file_download_rounded, color: Color(0xFF10B981)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l10n.tr('exportMerge'))),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.tr('targetFormat'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedFormat,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: [
                        ...ConversionItem.supportedVideoFormats.map((fmt) {
                          return DropdownMenuItem(
                            value: fmt,
                            child: Row(
                              children: [
                                const Icon(Icons.movie_rounded, size: 16, color: Colors.purpleAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        ...ConversionItem.supportedAudioOutputFormats.map((fmt) {
                          return DropdownMenuItem(
                            value: fmt,
                            child: Row(
                              children: [
                                const Icon(Icons.music_note_rounded, size: 16, color: Colors.blueAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => _selectedFormat = val);
                      },
                    ),
                    if (!ConversionItem.supportedAudioOutputFormats.contains(_selectedFormat)) ...[
                      const SizedBox(height: 14),
                      Text(l10n.tr('outputResolution'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedResolution,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: _resolutions.map((res) {
                          return DropdownMenuItem(value: res, child: Text(res));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => _selectedResolution = val);
                        },
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.tr('cancel')),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final success = await _controller.exportMergedMedia(
                        targetFormat: _selectedFormat,
                        resolution: _selectedResolution,
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (!mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${l10n.tr('mergeExportSuccess')}\n${_controller.exportedFilePath ?? ''}',
                            ),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      } else if (_controller.exportErrorMessage != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_controller.exportErrorMessage!),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                    child: Text(l10n.tr('start')),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('screenMergeMedia')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            _controller.pause();
            MergeMediaController.stopAllPlayback();
            widget.onBack();
          },
        ),
        actions: [
          if (_controller.visualTimeline.isNotEmpty || _controller.audioTimeline.isNotEmpty)
            IconButton(
              tooltip: l10n.tr('clearTimeline'),
              icon: const Icon(Icons.clear_all_rounded),
              onPressed: _controller.clearAll,
            ),
          IconButton(
            tooltip: l10n.tr('exportMerge'),
            icon: const Icon(Icons.movie_creation_rounded, color: Color(0xFF38BDF8)),
            onPressed: _showExportDialog,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              // Top Preview Player (Aspect ratio 16:9)
              _buildMobilePreviewPlayer(isDark, theme, l10n),

              // Media Pool Strip
              _buildMobileMediaPool(isDark, theme, l10n),

              // Timeline Label & Counter with Pinch/Tap Zoom Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: isDark ? const Color(0xFF232627) : const Color(0xFFE5E7EB),
                child: Row(
                  children: [
                    const Icon(Icons.view_timeline_rounded, size: 16, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    // Compact mobile zoom controls
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1D2024) : Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3F444D) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: _controller.zoomLevel > 0.25 ? () => _zoomAroundPlayhead(_controller.zoomLevel / 1.25) : null,
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.remove_rounded, size: 13),
                            ),
                          ),
                          InkWell(
                            onTap: () => _zoomAroundPlayhead(1.0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              child: Text(
                                '${(_controller.zoomLevel * 100).round()}%',
                                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _controller.zoomLevel < 8.0 ? () => _zoomAroundPlayhead(_controller.zoomLevel * 1.25) : null,
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.add_rounded, size: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${_formatDuration(_controller.currentPositionSec)} / ${_formatDuration(_controller.totalDurationSec)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3-Track Timeline
              Expanded(
                child: _buildMobile3TrackTimeline(isDark, theme, l10n),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobilePreviewPlayer(bool isDark, ThemeData theme, AppLocalizations l10n) {
    final activeItem = _controller.activeVisualItem;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!_controller.hasContent)
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_collection_outlined, size: 36, color: Colors.grey[700]),
                          const SizedBox(height: 6),
                          Text(
                            l10n.tr('noFilesSelected'),
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_controller.isAudioOnly)
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF10B981).withOpacity(0.2),
                              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                            ),
                            child: Icon(
                              _controller.isPlaying ? Icons.graphic_eq_rounded : Icons.audiotrack_rounded,
                              size: 32,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _controller.activeAudioItem?.name ?? _controller.audioTimeline.first.name,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _controller.isPlaying ? 'Playing Audio' : 'Audio Track',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (activeItem != null && activeItem.isImage)
                  Image.file(
                    File(activeItem.path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => activeItem.thumbnailBytes != null
                        ? Image.memory(activeItem.thumbnailBytes!, fit: BoxFit.contain)
                        : const Icon(Icons.image_rounded, size: 40, color: Colors.white),
                  )
                else if (activeItem != null && activeItem.isVideo)
                  activeItem.thumbnailBytes != null
                      ? Image.memory(activeItem.thumbnailBytes!, fit: BoxFit.contain)
                      : const Icon(Icons.movie_creation_rounded, size: 40, color: Colors.white),

                // Soundtrack Audio Badge Indicator
                if (_controller.activeAudioItem != null && !_controller.isAudioOnly)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF10B981), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _controller.isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                            size: 12,
                            color: const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _controller.activeAudioItem!.name,
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Mini controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            color: isDark ? const Color(0xFF282B30) : Colors.grey[200],
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  iconSize: 22,
                  color: const Color(0xFF38BDF8),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _controller.totalDurationSec > 0 ? _controller.togglePlay : null,
                ),
                IconButton(
                  icon: const Icon(Icons.replay_rounded),
                  iconSize: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(),
                  onPressed: _controller.totalDurationSec > 0 ? () => _controller.seekTo(0) : null,
                ),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Slider(
                      value: _controller.currentPositionSec.clamp(
                        0.0,
                        _controller.totalDurationSec > 0 ? _controller.totalDurationSec : 1.0,
                      ),
                      max: _controller.totalDurationSec > 0 ? _controller.totalDurationSec : 1.0,
                      onChanged: (val) => _controller.seekTo(val),
                    ),
                  ),
                ),
                Text(
                  '${_formatDuration(_controller.currentPositionSec)} / ${_formatDuration(_controller.totalDurationSec)}',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMediaPool(bool isDark, ThemeData theme, AppLocalizations l10n) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      color: isDark ? const Color(0xFF282B30) : Colors.white,
      child: Row(
        children: [
          // Add media button
          InkWell(
            onTap: _controller.pickMediaFiles,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF38BDF8)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: Color(0xFF38BDF8), size: 24),
                  Text('Add', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Horizontal scroll of pool items
          Expanded(
            child: _controller.mediaPool.isEmpty
                ? Center(
                    child: Text(
                      l10n.tr('mediaPoolEmpty'),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _controller.mediaPool.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final item = _controller.mediaPool[idx];
                      return _buildMobileDraggablePoolItem(item, isDark, theme, l10n);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDraggablePoolItem(
    MergeMediaItem item,
    bool isDark,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    Color color;
    IconData icon;
    int targetTrack;

    if (item.isImage) {
      color = const Color(0xFF38BDF8);
      icon = Icons.image_rounded;
      targetTrack = 1;
    } else if (item.isVideo) {
      color = const Color(0xFFF59E0B);
      icon = Icons.movie_rounded;
      targetTrack = 2;
    } else {
      color = const Color(0xFF10B981);
      icon = Icons.audiotrack_rounded;
      targetTrack = 3;
    }

    if (item.isVideo && item.thumbnailBytes == null) {
      _controller.ensureVideoThumbnail(item);
    }

    final itemWidget = Container(
      width: 108,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF212327) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 28,
              height: 28,
              color: color.withOpacity(0.2),
              child: item.thumbnailBytes != null
                  ? Image.memory(item.thumbnailBytes!, fit: BoxFit.cover)
                  : (item.isImage && !kIsWeb
                      ? Image.file(
                          File(item.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 14),
                        )
                      : (item.isAudio
                          ? Stack(
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: TimelineWaveformPainter(
                                      color: color.withOpacity(0.4),
                                      durationSec: item.durationInSeconds,
                                      seed: item.name.hashCode,
                                    ),
                                  ),
                                ),
                                Center(child: Icon(Icons.audiotrack_rounded, color: color, size: 14)),
                              ],
                            )
                          : Icon(icon, color: color, size: 14))),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, height: 1.1),
                ),
                Text(
                  _formatDuration(item.durationInSeconds),
                  style: const TextStyle(fontSize: 9, color: Colors.grey, height: 1.1),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _controller.addToTrack(item, targetTrack),
            child: Icon(Icons.add_circle, color: color, size: 16),
          ),
        ],
      ),
    );

    return LongPressDraggable<MergeMediaItem>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 120, child: Opacity(opacity: 0.85, child: itemWidget)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: itemWidget),
      child: itemWidget,
    );
  }

  Widget _buildMobile3TrackTimeline(bool isDark, ThemeData theme, AppLocalizations l10n) {
    final totalDur = _controller.totalDurationSec;
    final effectiveDur = math.max(totalDur + 20.0, 45.0);
    final trackAreaWidth = math.max(800.0, effectiveDur * _pixelsPerSecond);
    final playheadX = _controller.currentPositionSec * _pixelsPerSecond;

    return Container(
      color: isDark ? const Color(0xFF212327) : const Color(0xFFEFEEF1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            // Pinned Left Track Headers (110px)
            SizedBox(
              width: 110,
              child: Column(
                children: [
                  Container(
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    color: isDark ? const Color(0xFF1D2024) : const Color(0xFFE2E8F0),
                    child: Text(
                      '00:00',
                      style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.grey[500]),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF3F444D)),

                  // Track 1 Header
                  Expanded(
                    child: _buildMobileTrackHeader(
                      trackTitle: l10n.tr('trackImages'),
                      trackIcon: Icons.image_rounded,
                      trackColor: const Color(0xFF38BDF8),
                      isDark: isDark,
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF3F444D)),

                  // Track 2 Header
                  Expanded(
                    child: _buildMobileTrackHeader(
                      trackTitle: l10n.tr('trackVideos'),
                      trackIcon: Icons.movie_rounded,
                      trackColor: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF3F444D)),

                  // Track 3 Header
                  Expanded(
                    child: _buildMobileTrackHeader(
                      trackTitle: l10n.tr('trackAudio'),
                      trackIcon: Icons.audiotrack_rounded,
                      trackColor: const Color(0xFF10B981),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF3F444D)),

            // Horizontally Scrollable Timeline Track Area with Touch Pinch-to-Zoom & Pointer Scroll Zoom
            Expanded(
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed ||
                        HardwareKeyboard.instance.isMetaPressed;
                    if (isCtrlPressed) {
                      if (pointerSignal.scrollDelta.dy != 0) {
                        GestureBinding.instance.pointerSignalResolver.register(pointerSignal, (_) {
                          final zoomFactor = pointerSignal.scrollDelta.dy < 0 ? 1.25 : (1.0 / 1.25);
                          _zoomAtPoint(pointerSignal.localPosition.dx, zoomFactor);
                        });
                      }
                    } else {
                      // Plain scroll (mouse wheel) pans timeline horizontally
                      if (pointerSignal.scrollDelta.dy != 0 && pointerSignal.scrollDelta.dx == 0) {
                        GestureBinding.instance.pointerSignalResolver.register(pointerSignal, (_) {
                          if (_timelineScrollController.hasClients) {
                            final target = (_timelineScrollController.offset + pointerSignal.scrollDelta.dy)
                                .clamp(0.0, _timelineScrollController.position.maxScrollExtent);
                            _timelineScrollController.jumpTo(target);
                          }
                        });
                      }
                    }
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onScaleStart: (details) {
                    if (details.pointerCount > 1) {
                      _baseScale = _controller.pixelsPerSecond;
                    }
                  },
                  onScaleUpdate: (details) {
                    if (details.pointerCount > 1) {
                      final newScale = (_baseScale * details.scale).clamp(
                        MergeMediaController.minPixelsPerSecond,
                        MergeMediaController.maxPixelsPerSecond,
                      );
                      if ((newScale - _controller.pixelsPerSecond).abs() > 0.5) {
                        _zoomAtPoint(details.localFocalPoint.dx, details.scale);
                      }
                    }
                  },
                  child: RawScrollbar(
                    controller: _timelineScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(3),
                    thumbColor: isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8),
                    trackColor: isDark ? const Color(0xFF181A1D) : const Color(0xFFF1F5F9),
                    child: SingleChildScrollView(
                      controller: _timelineScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: trackAreaWidth,
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                // Top Mobile Time Ruler (LTR)
                                _buildMobileTimelineRuler(isDark, trackAreaWidth),
                                const Divider(height: 1, color: Color(0xFF3F444D)),

                                // Track 1: Images
                                Expanded(
                                  child: _buildMobileTrackLaneContent(
                                    trackIndex: 1,
                                    acceptedType: MergeMediaType.image,
                                    trackColor: const Color(0xFF38BDF8),
                                    isDark: isDark,
                                    trackAreaWidth: trackAreaWidth,
                                    l10n: l10n,
                                  ),
                                ),
                                const Divider(height: 1, color: Color(0xFF3F444D)),

                                // Track 2: Videos
                                Expanded(
                                  child: _buildMobileTrackLaneContent(
                                    trackIndex: 2,
                                    acceptedType: MergeMediaType.video,
                                    trackColor: const Color(0xFFF59E0B),
                                    isDark: isDark,
                                    trackAreaWidth: trackAreaWidth,
                                    l10n: l10n,
                                  ),
                                ),
                                const Divider(height: 1, color: Color(0xFF3F444D)),

                                // Track 3: Audio only
                                Expanded(
                                  child: _buildMobileTrackLaneContent(
                                    trackIndex: 3,
                                    acceptedType: MergeMediaType.audio,
                                    trackColor: const Color(0xFF10B981),
                                    isDark: isDark,
                                    trackAreaWidth: trackAreaWidth,
                                    l10n: l10n,
                                  ),
                                ),
                              ],
                            ),

                            // Full-Height Playhead Needle across ruler and all 3 tracks
                            if (totalDur > 0 || _controller.currentPositionSec > 0)
                              Positioned(
                                left: (playheadX - 5).clamp(0.0, trackAreaWidth - 10),
                                top: 0,
                                bottom: 0,
                                child: IgnorePointer(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF38BDF8),
                                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF38BDF8).withOpacity(0.5),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.arrow_drop_down, size: 10, color: Colors.black),
                                      ),
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF38BDF8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF38BDF8).withOpacity(0.4),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTimelineRuler(bool isDark, double trackAreaWidth) {
    final totalDur = _controller.totalDurationSec;
    final scale = _pixelsPerSecond;

    final double stepSec;
    if (scale >= 150) {
      stepSec = 1.0;
    } else if (scale >= 75) {
      stepSec = 2.0;
    } else if (scale >= 35) {
      stepSec = 5.0;
    } else if (scale >= 15) {
      stepSec = 10.0;
    } else if (scale >= 7) {
      stepSec = 30.0;
    } else {
      stepSec = 60.0;
    }

    final maxSec = trackAreaWidth / scale;
    final markerCount = (maxSec / stepSec).ceil();

    return Container(
      height: 22,
      color: isDark ? const Color(0xFF1D2024) : const Color(0xFFE2E8F0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final clickedSec = details.localPosition.dx / scale;
          _controller.seekTo(clickedSec.clamp(0.0, math.max(totalDur, 0.0)));
        },
        onHorizontalDragUpdate: (details) {
          final clickedSec = details.localPosition.dx / scale;
          _controller.seekTo(clickedSec.clamp(0.0, math.max(totalDur, 0.0)));
        },
        child: Stack(
          children: [
            for (int i = 0; i <= markerCount; i++) ...[
              Positioned(
                left: i * stepSec * scale,
                top: 0,
                bottom: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 1,
                      height: 8,
                      color: isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 3),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        _formatDuration(i * stepSec),
                        style: TextStyle(
                          fontSize: 8,
                          fontFamily: 'monospace',
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTrackHeader({
    required String trackTitle,
    required IconData trackIcon,
    required Color trackColor,
    required bool isDark,
  }) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? const Color(0xFF282B30) : Colors.white,
      child: Row(
        children: [
          Icon(trackIcon, size: 16, color: trackColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              trackTitle,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: trackColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTrackLaneContent({
    required int trackIndex,
    required MergeMediaType acceptedType,
    required Color trackColor,
    required bool isDark,
    required double trackAreaWidth,
    required AppLocalizations l10n,
  }) {
    return SizedBox(
      width: trackAreaWidth,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DragTarget<Object>(
          onWillAcceptWithDetails: (details) {
            final data = details.data;
            if (data is MergeMediaItem) return data.type == acceptedType;
            if (data is MergeTrackDragPayload) return data.sourceTrack == trackIndex;
            return false;
          },
          onAcceptWithDetails: (details) {
            final data = details.data;
            if (data is MergeMediaItem) {
              _controller.addToTrack(data, trackIndex);
            } else if (data is MergeTrackDragPayload) {
              if (trackIndex == 3) {
                _controller.reorderAudioItem(data.sourceIndex, _controller.audioTimeline.length);
              } else {
                _controller.reorderVisualItem(data.sourceIndex, _controller.visualTimeline.length);
              }
            }
          },
          builder: (context, candidateData, rejectedData) {
            final isHovered = candidateData.isNotEmpty;

            return Container(
              decoration: BoxDecoration(
                color: isHovered
                    ? trackColor.withOpacity(0.12)
                    : (isDark ? const Color(0xFF212327) : const Color(0xFFF9FAFB)),
                border: isHovered ? Border.all(color: trackColor, width: 2) : null,
              ),
              child: trackIndex == 3
                  ? _buildMobileAudioContents(trackColor, isDark, l10n, trackAreaWidth)
                  : _buildMobileVisualContents(trackIndex, trackColor, isDark, l10n, trackAreaWidth),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileVisualContents(
    int trackIndex,
    Color trackColor,
    bool isDark,
    AppLocalizations l10n,
    double trackAreaWidth,
  ) {
    final matchingIndices = <int>[];
    for (int i = 0; i < _controller.visualTimeline.length; i++) {
      final item = _controller.visualTimeline[i];
      if ((trackIndex == 1 && item.isImage) || (trackIndex == 2 && item.isVideo)) {
        matchingIndices.add(i);
      }
    }

    if (matchingIndices.isEmpty) {
      return Center(
        child: Text(
          l10n.tr('dragHere'),
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      );
    }

    return SizedBox(
      width: trackAreaWidth,
      child: Stack(
        children: [
          for (final idx in matchingIndices)
            _buildMobileVisualClipBlock(
              idx: idx,
              item: _controller.visualTimeline[idx],
              trackIndex: trackIndex,
              trackColor: trackColor,
              isDark: isDark,
              l10n: l10n,
            ),
        ],
      ),
    );
  }

  Widget _buildMobileVisualClipBlock({
    required int idx,
    required MergeMediaItem item,
    required int trackIndex,
    required Color trackColor,
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    final itemStartSec = _controller.getVisualItemStartSec(idx);
    final clipLeft = itemStartSec * _pixelsPerSecond;
    final clipWidth = math.max(4.0, item.durationInSeconds * _pixelsPerSecond);
    final isActive = item.id == _controller.activeVisualItem?.id;

    final blockContent = DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data is MergeMediaItem) {
          return (trackIndex == 1 && data.isImage) || (trackIndex == 2 && data.isVideo);
        }
        if (data is MergeTrackDragPayload) return data.sourceTrack == trackIndex;
        return false;
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is MergeTrackDragPayload) {
          _controller.reorderVisualItem(data.sourceIndex, idx);
        } else if (data is MergeMediaItem) {
          _controller.addToTrack(data, trackIndex, idx);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isTargetHovered = candidateData.isNotEmpty;

        final clipWidget = _buildMobileClipContentWidget(
          item: item,
          trackColor: trackColor,
          isDark: isDark,
          l10n: l10n,
          clipWidth: clipWidth,
          isActive: isActive,
          isTargetHovered: isTargetHovered,
          onRemove: () => _controller.removeVisualItem(idx),
          onAdjustDuration: item.isImage ? () => _showImageDurationDialog(item) : null,
        );

        return LongPressDraggable<MergeTrackDragPayload>(
          data: MergeTrackDragPayload(
            item: item,
            sourceTrack: trackIndex,
            sourceIndex: idx,
          ),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: clipWidth,
              height: 40,
              child: Opacity(opacity: 0.85, child: clipWidget),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: clipWidget),
          child: clipWidget,
        );
      },
    );

    return Positioned(
      key: ValueKey('timeline_clip_${item.id}'),
      left: clipLeft,
      width: clipWidth,
      top: 3,
      bottom: 3,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: blockContent),
          if (item.isImage) ...[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ImageTrimHandle(
                isLeft: true,
                item: item,
                pixelsPerSecond: _pixelsPerSecond,
                onDurationChanged: (newDur) => _controller.updateImageDuration(item.id, newDur),
                color: trackColor,
                handleWidth: math.min(14.0, clipWidth / 2),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: ImageTrimHandle(
                isLeft: false,
                item: item,
                pixelsPerSecond: _pixelsPerSecond,
                onDurationChanged: (newDur) => _controller.updateImageDuration(item.id, newDur),
                color: trackColor,
                handleWidth: math.min(14.0, clipWidth / 2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileAudioContents(
    Color trackColor,
    bool isDark,
    AppLocalizations l10n,
    double trackAreaWidth,
  ) {
    if (_controller.audioTimeline.isEmpty) {
      return Center(
        child: Text(
          l10n.tr('dragHere'),
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      );
    }

    return SizedBox(
      width: trackAreaWidth,
      child: Stack(
        children: [
          for (int idx = 0; idx < _controller.audioTimeline.length; idx++)
            _buildMobileAudioClipBlock(
              idx: idx,
              item: _controller.audioTimeline[idx],
              trackColor: trackColor,
              isDark: isDark,
              l10n: l10n,
            ),
        ],
      ),
    );
  }

  Widget _buildMobileAudioClipBlock({
    required int idx,
    required MergeMediaItem item,
    required Color trackColor,
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    final itemStartSec = _controller.getAudioItemStartSec(idx);
    final clipLeft = itemStartSec * _pixelsPerSecond;
    final clipWidth = math.max(4.0, item.durationInSeconds * _pixelsPerSecond);
    final isActive = item.id == _controller.activeAudioItem?.id;

    return Positioned(
      key: ValueKey('timeline_clip_${item.id}'),
      left: clipLeft,
      width: clipWidth,
      top: 3,
      bottom: 3,
      child: DragTarget<Object>(
        onWillAcceptWithDetails: (details) {
          final data = details.data;
          if (data is MergeMediaItem) return data.isAudio;
          if (data is MergeTrackDragPayload) return data.sourceTrack == 3;
          return false;
        },
        onAcceptWithDetails: (details) {
          final data = details.data;
          if (data is MergeTrackDragPayload) {
            _controller.reorderAudioItem(data.sourceIndex, idx);
          } else if (data is MergeMediaItem) {
            _controller.addToTrack(data, 3, idx);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isTargetHovered = candidateData.isNotEmpty;

          final clipWidget = _buildMobileClipContentWidget(
            item: item,
            trackColor: trackColor,
            isDark: isDark,
            l10n: l10n,
            clipWidth: clipWidth,
            isActive: isActive,
            isTargetHovered: isTargetHovered,
            onRemove: () => _controller.removeAudioItem(idx),
            onAdjustDuration: null,
          );

          return LongPressDraggable<MergeTrackDragPayload>(
            data: MergeTrackDragPayload(
              item: item,
              sourceTrack: 3,
              sourceIndex: idx,
            ),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: clipWidth,
                height: 40,
                child: Opacity(opacity: 0.85, child: clipWidget),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: clipWidget),
            child: clipWidget,
          );
        },
      ),
    );
  }

  Widget _buildMobileClipContentWidget({
    required MergeMediaItem item,
    required Color trackColor,
    required bool isDark,
    required AppLocalizations l10n,
    required double clipWidth,
    required bool isActive,
    required bool isTargetHovered,
    required VoidCallback onRemove,
    VoidCallback? onAdjustDuration,
  }) {
    final showWaveform = item.isVideo || item.isAudio;

    return Container(
      width: clipWidth,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282B30) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isTargetHovered
              ? const Color(0xFF38BDF8)
              : (isActive ? const Color(0xFF38BDF8) : trackColor),
          width: (isTargetHovered || isActive) ? 2.0 : 1.5,
        ),
        boxShadow: (isTargetHovered || isActive)
            ? [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.5),
        child: Stack(
          children: [
            // Waveform background for audio & video clips
            if (showWaveform)
              Positioned.fill(
                child: CustomPaint(
                  painter: TimelineWaveformPainter(
                    color: trackColor.withOpacity(isDark ? 0.35 : 0.25),
                    durationSec: item.durationInSeconds,
                    seed: item.name.hashCode,
                  ),
                ),
              ),

            // Adaptive content overlay
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: _buildMobileAdaptiveClipDetails(
                  item: item,
                  clipWidth: clipWidth,
                  trackColor: trackColor,
                  isActive: isActive,
                  l10n: l10n,
                  onRemove: onRemove,
                  onAdjustDuration: onAdjustDuration,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileAdaptiveClipDetails({
    required MergeMediaItem item,
    required double clipWidth,
    required Color trackColor,
    required bool isActive,
    required AppLocalizations l10n,
    required VoidCallback onRemove,
    VoidCallback? onAdjustDuration,
  }) {
    if (clipWidth < 45) {
      return Tooltip(
        message: '${item.name} (${_formatDuration(item.durationInSeconds)})',
        child: Center(
          child: Icon(
            item.isImage ? Icons.image : (item.isVideo ? Icons.movie : Icons.audiotrack),
            size: 13,
            color: trackColor,
          ),
        ),
      );
    }

    if (clipWidth < 90) {
      return Row(
        children: [
          Icon(
            item.isImage ? Icons.image : (item.isVideo ? Icons.movie : Icons.audiotrack),
            size: 13,
            color: trackColor,
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.drag_indicator_rounded, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        _controller.isPlaying ? 'PLAY' : 'ACT',
                        style: const TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                ],
              ),
              Text(
                _formatDuration(item.durationInSeconds),
                style: TextStyle(fontSize: 8.5, color: trackColor, fontWeight: FontWeight.w600),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ),
        if (onAdjustDuration != null && clipWidth >= 120)
          IconButton(
            tooltip: l10n.tr('adjustDuration'),
            icon: const Icon(Icons.tune_rounded, size: 12),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onAdjustDuration,
          ),
        if (clipWidth >= 105)
          IconButton(
            tooltip: l10n.tr('removeItem'),
            icon: const Icon(Icons.close_rounded, size: 12, color: Colors.redAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onRemove,
          ),
      ],
    );
  }
}

