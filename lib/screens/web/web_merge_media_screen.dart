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

class WebMergeMediaScreen extends StatefulWidget {
  final VoidCallback onBack;
  final SettingsService? settingsService;
  final MergeMediaController? controller;

  const WebMergeMediaScreen({
    super.key,
    required this.onBack,
    this.settingsService,
    this.controller,
  });

  @override
  State<WebMergeMediaScreen> createState() => _WebMergeMediaScreenState();
}

class _WebMergeMediaScreenState extends State<WebMergeMediaScreen> with WidgetsBindingObserver {
  late final MergeMediaController _controller;
  final ScrollController _timelineScrollController = ScrollController();

  String _selectedFormat = 'mp4';
  String _selectedResolution = '1920x1080';

  final List<String> _resolutions = [
    '1920x1080',
    '1280x720',
    '3840x2160',
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

  void _zoomAtCursor(double cursorViewportX, double scrollDeltaDy) {
    final oldScale = _controller.pixelsPerSecond;
    final zoomFactor = scrollDeltaDy < 0 ? 1.25 : (1.0 / 1.25);
    final targetScale = (oldScale * zoomFactor).clamp(
      MergeMediaController.minPixelsPerSecond,
      MergeMediaController.maxPixelsPerSecond,
    );
    if ((targetScale - oldScale).abs() < 0.001) return;

    final currentScroll = _timelineScrollController.hasClients ? _timelineScrollController.offset : 0.0;
    final timeAtCursor = (currentScroll + cursorViewportX) / oldScale;
    final newContentX = timeAtCursor * targetScale;
    final targetScroll = newContentX - cursorViewportX;

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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.timer_rounded, color: Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              Text(l10n.tr('adjustDuration')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Text(
                '${sec.toStringAsFixed(1)} ${l10n.tr('seconds')}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(height: 8),
              Slider(
                value: sec,
                min: 1.0,
                max: 30.0,
                divisions: 58,
                label: '${sec.toStringAsFixed(1)}s',
                onChanged: (val) {
                  setDlgState(() => sec = val);
                },
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
                _controller.updateImageDuration(
                  item.id,
                  Duration(milliseconds: (sec * 1000).round()),
                );
                Navigator.pop(ctx);
              },
              child: Text(l10n.tr('apply')),
            ),
          ],
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.file_download_rounded, color: Color(0xFF10B981)),
              const SizedBox(width: 10),
              Text(l10n.tr('exportMerge')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.tr('webNoticeDesc'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Text(l10n.tr('targetFormat'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedFormat,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  ...ConversionItem.supportedVideoFormats.map((fmt) {
                    return DropdownMenuItem(
                      value: fmt,
                      child: Row(
                        children: [
                          const Icon(Icons.movie_rounded, size: 16, color: Colors.purpleAccent),
                          const SizedBox(width: 8),
                          Text(l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}')),
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
                          Text(l10n.tr('format${fmt[0].toUpperCase()}${fmt.substring(1)}')),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedFormat = val);
                    setDlgState(() => _selectedFormat = val);
                  }
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
                    if (val != null) {
                      setState(() => _selectedResolution = val);
                      setDlgState(() => _selectedResolution = val);
                    }
                  },
                ),
              ],
            const SizedBox(height: 12),
            Text(
              '${l10n.tr('duration')}: ${_formatDuration(_controller.totalDurationSec)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('close')),
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              // Top Web Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF282B30) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF3F444D) : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l10n.tr('back'),
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        _controller.pause();
                        MergeMediaController.stopAllPlayback();
                        widget.onBack();
                      },
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('screenMergeMedia'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.tr('mergeMediaDesc'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    if (_controller.visualTimeline.isNotEmpty || _controller.audioTimeline.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                        label: Text(l10n.tr('clearTimeline')),
                        onPressed: _controller.clearAll,
                      ),
                    const SizedBox(width: 12),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.movie_creation_rounded, size: 18),
                      label: Text(l10n.tr('exportMerge')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _showExportDialog,
                    ),
                  ],
                ),
              ),

              // Main Workspace
              Expanded(
                child: Column(
                  children: [
                    // Top: Preview Player + Media Pool side-by-side
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildWebPreviewPlayer(isDark, theme, l10n),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 5,
                              child: _buildWebMediaPool(isDark, theme, l10n),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Timeline Divider Bar with Zoom & Pan controls
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      color: isDark ? const Color(0xFF232627) : const Color(0xFFE5E7EB),
                      child: Row(
                        children: [
                          const Icon(Icons.view_timeline_rounded, size: 18, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.tr('timelineHelp'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Zoom controls
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1D2024) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? const Color(0xFF3F444D) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: 'Zoom Out (Scroll Down)',
                                  child: InkWell(
                                    onTap: _controller.zoomLevel > 0.25 ? () => _zoomAroundPlayhead(_controller.zoomLevel / 1.25) : null,
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(Icons.remove_rounded, size: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Reset Zoom (100%)',
                                  child: InkWell(
                                    onTap: () => _zoomAroundPlayhead(1.0),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Text(
                                        '${(_controller.zoomLevel * 100).round()}%',
                                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Zoom In (Scroll Up)',
                                  child: InkWell(
                                    onTap: _controller.zoomLevel < 8.0 ? () => _zoomAroundPlayhead(_controller.zoomLevel * 1.25) : null,
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(Icons.add_rounded, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${_formatDuration(_controller.currentPositionSec)} / ${_formatDuration(_controller.totalDurationSec)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom: 3-Track Timeline
                    Expanded(
                      flex: 5,
                      child: _buildWeb3TrackTimeline(isDark, theme, l10n),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWebPreviewPlayer(bool isDark, ThemeData theme, AppLocalizations l10n) {
    final activeItem = _controller.activeVisualItem;

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill_rounded, size: 18, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Text(
                  l10n.tr('previewPlayer'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                if (activeItem != null)
                  Text(
                    activeItem.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  )
                else if (_controller.activeAudioItem != null)
                  Text(
                    _controller.activeAudioItem!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF10B981)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!_controller.hasContent)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_collection_outlined, size: 48, color: Colors.grey[700]),
                            const SizedBox(height: 10),
                            Text(
                              l10n.tr('noFilesSelected'),
                              style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_controller.isAudioOnly)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                border: Border.all(color: const Color(0xFF10B981), width: 2),
                              ),
                              child: Icon(
                                _controller.isPlaying ? Icons.graphic_eq_rounded : Icons.audiotrack_rounded,
                                size: 44,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                _controller.activeAudioItem?.name ?? _controller.audioTimeline.first.name,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _controller.isPlaying ? 'Playing Audio' : 'Audio Track Ready',
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (activeItem != null && activeItem.isImage && !kIsWeb)
                    Image.file(File(activeItem.path), fit: BoxFit.contain)
                  else if (activeItem != null && activeItem.thumbnailBytes != null)
                    Image.memory(activeItem.thumbnailBytes!, fit: BoxFit.contain)
                  else if (activeItem != null)
                    Icon(activeItem.isImage ? Icons.image_rounded : Icons.movie_rounded, size: 48, color: Colors.white),

                  if (_controller.activeAudioItem != null && !_controller.isAudioOnly)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _controller.isPlaying ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                              size: 14,
                              color: const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _controller.activeAudioItem!.name,
                              style: const TextStyle(fontSize: 11, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xFF282B30) : Colors.grey[100],
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  iconSize: 26,
                  color: const Color(0xFF38BDF8),
                  onPressed: _controller.totalDurationSec > 0 ? _controller.togglePlay : null,
                ),
                IconButton(
                  icon: const Icon(Icons.replay_rounded),
                  iconSize: 20,
                  onPressed: _controller.totalDurationSec > 0 ? () => _controller.seekTo(0) : null,
                ),
                const SizedBox(width: 8),
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
                const SizedBox(width: 8),
                Text(
                  '${_formatDuration(_controller.currentPositionSec)} / ${_formatDuration(_controller.totalDurationSec)}',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebMediaPool(bool isDark, ThemeData theme, AppLocalizations l10n) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.folder_copy_rounded, size: 18, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.tr('mediaPool')} (${_controller.mediaPool.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(l10n.tr('addMediaFiles')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: _controller.pickMediaFiles,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _controller.mediaPool.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxHeight < 70) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text(
                              l10n.tr('mediaPoolEmpty'),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        );
                      }
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.drive_folder_upload_rounded, size: 36, color: Colors.grey[600]),
                              const SizedBox(height: 8),
                              Text(
                                l10n.tr('mediaPoolEmpty'),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _controller.mediaPool.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = _controller.mediaPool[idx];
                      return _buildWebDraggableMediaPoolCard(item, isDark, theme, l10n);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDraggableMediaPoolCard(
    MergeMediaItem item,
    bool isDark,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    Color typeColor;
    IconData typeIcon;
    int targetTrack;

    if (item.isImage) {
      typeColor = const Color(0xFF38BDF8);
      typeIcon = Icons.image_rounded;
      targetTrack = 1;
    } else if (item.isVideo) {
      typeColor = const Color(0xFFF59E0B);
      typeIcon = Icons.movie_rounded;
      targetTrack = 2;
    } else {
      typeColor = const Color(0xFF10B981);
      typeIcon = Icons.audiotrack_rounded;
      targetTrack = 3;
    }

    if (item.isVideo && item.thumbnailBytes == null) {
      _controller.ensureVideoThumbnail(item);
    }

    final cardContent = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282B30) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: typeColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 42,
              height: 42,
              color: typeColor.withOpacity(0.15),
              child: item.thumbnailBytes != null
                  ? Image.memory(item.thumbnailBytes!, fit: BoxFit.cover)
                  : (item.isAudio
                      ? Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: TimelineWaveformPainter(
                                  color: typeColor.withOpacity(0.4),
                                  durationSec: item.durationInSeconds,
                                  seed: item.name.hashCode,
                                ),
                              ),
                            ),
                            Center(child: Icon(Icons.audiotrack_rounded, color: typeColor, size: 20)),
                          ],
                        )
                      : Icon(typeIcon, color: typeColor, size: 22)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.type.name.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(item.durationInSeconds),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add to Track $targetTrack',
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            color: typeColor,
            onPressed: () => _controller.addToTrack(item, targetTrack),
          ),
        ],
      ),
    );

    return Draggable<MergeMediaItem>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 260,
          child: Opacity(opacity: 0.85, child: cardContent),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: cardContent),
      child: cardContent,
    );
  }

  Widget _buildWeb3TrackTimeline(bool isDark, ThemeData theme, AppLocalizations l10n) {
    final totalDur = _controller.totalDurationSec;
    final effectiveDur = math.max(totalDur + 20.0, 45.0);
    final trackAreaWidth = math.max(1200.0, effectiveDur * _pixelsPerSecond);
    final playheadX = _controller.currentPositionSec * _pixelsPerSecond;

    return Container(
      color: isDark ? const Color(0xFF212327) : const Color(0xFFEFEEF1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            // Pinned Left Track Headers (170px)
            SizedBox(
              width: 170,
              child: Column(
                children: [
                  // Corner above ruler
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    color: isDark ? const Color(0xFF1D2024) : const Color(0xFFE2E8F0),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          '00:00',
                          style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF3F444D)),

                  // Track 1: Images Header
                  Expanded(
                    child: _buildWebTrackHeader(
                      trackTitle: l10n.tr('trackImages'),
                      trackIcon: Icons.image_rounded,
                      trackColor: const Color(0xFF38BDF8),
                      isDark: isDark,
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF3F444D)),

                  // Track 2: Videos Header
                  Expanded(
                    child: _buildWebTrackHeader(
                      trackTitle: l10n.tr('trackVideos'),
                      trackIcon: Icons.movie_rounded,
                      trackColor: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF3F444D)),

                  // Track 3: Audio Header
                  Expanded(
                    child: _buildWebTrackHeader(
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

            // Horizontally Scrollable Timeline Track Area with Pointer Wheel Zoom & Panning
            Expanded(
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed ||
                        HardwareKeyboard.instance.isMetaPressed;
                    if (isCtrlPressed) {
                      if (pointerSignal.scrollDelta.dy != 0) {
                        GestureBinding.instance.pointerSignalResolver.register(pointerSignal, (_) {
                          _zoomAtCursor(pointerSignal.localPosition.dx, pointerSignal.scrollDelta.dy);
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
                child: RawScrollbar(
                  controller: _timelineScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 8,
                  radius: const Radius.circular(4),
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
                              // Top Synchronized Time Ruler
                              _buildWebTimelineRuler(isDark, trackAreaWidth),
                              const Divider(height: 1, color: Color(0xFF3F444D)),

                              // Track 1: Images
                              Expanded(
                                child: _buildWebTrackLaneContent(
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
                                child: _buildWebTrackLaneContent(
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
                                child: _buildWebTrackLaneContent(
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
                              left: (playheadX - 6).clamp(0.0, trackAreaWidth - 12),
                              top: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF38BDF8),
                                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF38BDF8).withOpacity(0.5),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.arrow_drop_down, size: 12, color: Colors.black),
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
          ],
        ),
      ),
    );
  }

  Widget _buildWebTimelineRuler(bool isDark, double trackAreaWidth) {
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
      height: 26,
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
                      height: 10,
                      color: isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        _formatDuration(i * stepSec),
                        style: TextStyle(
                          fontSize: 9,
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

  Widget _buildWebTrackHeader({
    required String trackTitle,
    required IconData trackIcon,
    required Color trackColor,
    required bool isDark,
  }) {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: isDark ? const Color(0xFF282B30) : Colors.white,
      child: Row(
        children: [
          Icon(trackIcon, size: 18, color: trackColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              trackTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: trackColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebTrackLaneContent({
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
            if (data is MergeMediaItem) {
              return data.type == acceptedType;
            }
            if (data is MergeTrackDragPayload) {
              return data.sourceTrack == trackIndex;
            }
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
                border: isHovered
                    ? Border.all(color: trackColor, width: 2)
                    : null,
              ),
              child: trackIndex == 3
                  ? _buildWebAudioTrackContents(trackColor, isDark, l10n, trackAreaWidth)
                  : _buildWebVisualTrackContents(trackIndex, trackColor, isDark, l10n, trackAreaWidth),
            );
          },
        ),
      ),
    );
  }

  // Visual Track contents for Track 1 (Images) and Track 2 (Videos)
  Widget _buildWebVisualTrackContents(
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
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      );
    }

    return SizedBox(
      width: trackAreaWidth,
      child: Stack(
        children: [
          for (final idx in matchingIndices)
            _buildWebVisualClipBlock(
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

  Widget _buildWebVisualClipBlock({
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
        if (data is MergeTrackDragPayload) {
          return data.sourceTrack == trackIndex;
        }
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

        final clipWidget = _buildClipContentWidget(
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

        return Draggable<MergeTrackDragPayload>(
          data: MergeTrackDragPayload(
            item: item,
            sourceTrack: trackIndex,
            sourceIndex: idx,
          ),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: clipWidth,
              height: 52,
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
      top: 4,
      bottom: 4,
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

  // Audio Track 3 contents: soundtrack snapping sequentially with real drag-to-reorder
  Widget _buildWebAudioTrackContents(
    Color trackColor,
    bool isDark,
    AppLocalizations l10n,
    double trackAreaWidth,
  ) {
    if (_controller.audioTimeline.isEmpty) {
      return Center(
        child: Text(
          l10n.tr('dragHere'),
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      );
    }

    return SizedBox(
      width: trackAreaWidth,
      child: Stack(
        children: [
          for (int idx = 0; idx < _controller.audioTimeline.length; idx++)
            _buildWebAudioClipBlock(
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

  Widget _buildWebAudioClipBlock({
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
      top: 4,
      bottom: 4,
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

          final clipWidget = _buildClipContentWidget(
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

          return Draggable<MergeTrackDragPayload>(
            data: MergeTrackDragPayload(
              item: item,
              sourceTrack: 3,
              sourceIndex: idx,
            ),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: clipWidth,
                height: 52,
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

  Widget _buildClipContentWidget({
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
          width: (isTargetHovered || isActive) ? 2.5 : 1.5,
        ),
        boxShadow: (isTargetHovered || isActive)
            ? [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withOpacity(0.5),
                  blurRadius: 8,
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: _buildAdaptiveClipDetails(
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

  Widget _buildAdaptiveClipDetails({
    required MergeMediaItem item,
    required double clipWidth,
    required Color trackColor,
    required bool isActive,
    required AppLocalizations l10n,
    required VoidCallback onRemove,
    VoidCallback? onAdjustDuration,
  }) {
    if (clipWidth < 50) {
      return Tooltip(
        message: '${item.name} (${_formatDuration(item.durationInSeconds)})',
        child: Center(
          child: Icon(
            item.isImage ? Icons.image : (item.isVideo ? Icons.movie : Icons.audiotrack),
            size: 14,
            color: trackColor,
          ),
        ),
      );
    }

    if (clipWidth < 120) {
      return Row(
        children: [
          Icon(
            item.isImage ? Icons.image : (item.isVideo ? Icons.movie : Icons.audiotrack),
            size: 14,
            color: trackColor,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatDuration(item.durationInSeconds),
                  style: TextStyle(fontSize: 9, color: trackColor, fontWeight: FontWeight.w600),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          if (clipWidth >= 80)
            InkWell(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded, size: 12, color: Colors.redAccent),
            ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.drag_indicator_rounded, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 28,
            height: 28,
            child: item.thumbnailBytes != null
                ? Image.memory(item.thumbnailBytes!, fit: BoxFit.cover)
                : Icon(
                    item.isImage ? Icons.image : (item.isVideo ? Icons.movie : Icons.audiotrack),
                    size: 16,
                    color: trackColor,
                  ),
          ),
        ),
        const SizedBox(width: 6),
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
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isActive && clipWidth >= 180)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        _controller.isPlaying ? 'PLAYING' : 'ACTIVE',
                        style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                ],
              ),
              Text(
                _formatDuration(item.durationInSeconds),
                style: TextStyle(fontSize: 10, color: trackColor, fontWeight: FontWeight.w600),
                textDirection: TextDirection.ltr,
              ),
            ],
          ),
        ),
        if (onAdjustDuration != null && clipWidth >= 160) ...[
          IconButton(
            tooltip: l10n.tr('adjustDuration'),
            icon: const Icon(Icons.tune_rounded, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onAdjustDuration,
          ),
          const SizedBox(width: 4),
        ],
        if (clipWidth >= 140)
          IconButton(
            tooltip: l10n.tr('removeItem'),
            icon: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onRemove,
          ),
      ],
    );
  }
}
