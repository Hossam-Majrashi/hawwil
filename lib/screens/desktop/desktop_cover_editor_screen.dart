import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../l10n/app_localizations.dart';
import '../../services/taglib_service.dart';
import '../../services/ffmpeg_service.dart';
import '../../services/cover_download_service.dart';

class DesktopCoverEditorScreen extends StatefulWidget {
  final VoidCallback onBack;

  const DesktopCoverEditorScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<DesktopCoverEditorScreen> createState() =>
      _DesktopCoverEditorScreenState();
}

class _DesktopCoverEditorScreenState extends State<DesktopCoverEditorScreen> {
  String? _filePath;
  String? _fileName;
  bool _isMp4 = false;
  Uint8List? _coverBytes;
  bool _coverRemoved = false;
  bool _isCoverChanged = false;
  bool _isLoading = false;
  bool _isSaving = false;

  int? _coverWidth;
  int? _coverHeight;
  BoxFit _coverFit = BoxFit.contain;

  double _videoScrubSeconds = 0.0;
  double _videoDurationSeconds = 0.0;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _albumController = TextEditingController();
  Duration _duration = Duration.zero;
  int _bitrate = 0;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _decodeCoverDimensions(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _coverWidth = frame.image.width;
          _coverHeight = frame.image.height;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _coverWidth = null;
          _coverHeight = null;
        });
      }
    }
  }

  Future<void> _pickMp3File() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final path = files.first.path!;
      await _loadMp3(path);
    }
  }

  Future<void> _pickMp4File() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'm4v', 'mov', 'mkv'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final path = files.first.path!;
      await _loadMp4(path);
    }
  }

  Future<void> _loadMp3(String path) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isMp4 = false;
      _filePath = path;
      _fileName = p.basename(path);
      _coverRemoved = false;
      _coverWidth = null;
      _coverHeight = null;
      _videoScrubSeconds = 0.0;
      _videoDurationSeconds = 0.0;
    });
    WidgetsBinding.instance.scheduleFrame();

    final meta = await TagLibService.readMetadata(path);
    if (!mounted) return;

    final bytes = meta.coverBytes;

    setState(() {
      _isLoading = false;
      _coverBytes = bytes;
      _titleController.text = meta.title.isNotEmpty ? meta.title : p.basenameWithoutExtension(path);
      _artistController.text = meta.artist;
      _albumController.text = meta.album;
      _duration = meta.duration;
      _bitrate = meta.bitrate;
    });
    WidgetsBinding.instance.scheduleFrame();

    if (bytes != null && bytes.isNotEmpty) {
      await _decodeCoverDimensions(bytes);
    }
  }

  Future<void> _loadMp4(String path) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isMp4 = true;
      _filePath = path;
      _fileName = p.basename(path);
      _coverRemoved = false;
      _isCoverChanged = false;
      _coverWidth = null;
      _coverHeight = null;
      _videoScrubSeconds = 0.0;
    });
    WidgetsBinding.instance.scheduleFrame();

    final dur = await FFmpegService.getMediaDuration(path) ?? 0.0;
    _videoDurationSeconds = dur;
    _duration = Duration(milliseconds: (dur * 1000).toInt());

    final tags = await FFmpegService.readMediaTags(path);
    final coverBytes = await FFmpegService.extractMp4CoverOrFrame(
      videoPath: path,
      timestampSeconds: 0.0,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _coverBytes = coverBytes;
      _titleController.text = tags['title']?.isNotEmpty == true
          ? tags['title']!
          : p.basenameWithoutExtension(path);
      _artistController.text = tags['artist'] ?? '';
      _albumController.text = tags['album'] ?? '';
      _bitrate = 0;
    });
    WidgetsBinding.instance.scheduleFrame();

    if (coverBytes != null && coverBytes.isNotEmpty) {
      await _decodeCoverDimensions(coverBytes);
    }
  }

  Future<void> _scrubFrame(double seconds) async {
    if (_filePath == null || !_isMp4) return;
    setState(() {
      _videoScrubSeconds = seconds;
    });

    final frame = await FFmpegService.extractVideoFrame(
      videoPath: _filePath!,
      timestampSeconds: seconds,
    );

    if (frame != null && mounted) {
      setState(() {
        _coverBytes = frame;
        _coverRemoved = false;
        _isCoverChanged = true;
      });
      await _decodeCoverDimensions(frame);
    }
  }

  Future<void> _pickNewCover() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
    );

    if (files.isNotEmpty && files.first.path != null) {
      final imgBytes = await File(files.first.path!).readAsBytes();
      if (!mounted) return;
      setState(() {
        _coverBytes = imgBytes;
        _coverRemoved = false;
        _isCoverChanged = true;
      });
      WidgetsBinding.instance.scheduleFrame();
      await _decodeCoverDimensions(imgBytes);
    }
  }

  void _removeCover() {
    setState(() {
      _coverBytes = null;
      _coverRemoved = true;
      _isCoverChanged = true;
      _coverWidth = null;
      _coverHeight = null;
    });
  }

  Future<void> _downloadCover() async {
    if (_coverBytes == null || _coverBytes!.isEmpty) return;
    await CoverDownloadService.downloadCoverWithFeedback(
      context: context,
      coverBytes: _coverBytes!,
      mp3FileName: _fileName,
    );
  }

  void _openFullImageViewer() {
    if (_coverBytes == null || _coverBytes!.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 850, maxHeight: 850),
              decoration: BoxDecoration(
                color: const Color(0xFF181A1D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3F444D)),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 4),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Image.memory(
                    _coverBytes!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black87,
                    child: IconButton(
                      tooltip: l10n.tr('downloadCover'),
                      icon: const Icon(Icons.file_download_outlined, color: Colors.white),
                      onPressed: _downloadCover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.black87,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_filePath == null) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _isSaving = true);

    bool success = false;
    if (_isMp4) {
      success = await FFmpegService.updateMp4CoverAndMetadata(
        filePath: _filePath!,
        newCoverBytes: _coverBytes,
        removeCover: _coverRemoved,
        replaceVideoFrames: _isCoverChanged && !_coverRemoved && _coverBytes != null,
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        album: _albumController.text.trim(),
      );
      if (success) {
        _isCoverChanged = false;
      }
    } else {
      success = await TagLibService.updateCoverAndMetadata(
        filePath: _filePath!,
        newCoverBytes: _coverBytes,
        removeCover: _coverRemoved,
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        album: _albumController.text.trim(),
      );
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (_isMp4 ? l10n.tr('mp4CoverSaved') : l10n.tr('saved'))
                : l10n.tr('error'),
          ),
          backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('coverEditorTitle')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
        actions: [
          if (_filePath != null) ...[
            PopupMenuButton<String>(
              tooltip: l10n.tr('switchFile'),
              icon: const Icon(Icons.folder_open_rounded),
              onSelected: (val) {
                if (val == 'mp3') {
                  _pickMp3File();
                } else if (val == 'mp4') {
                  _pickMp4File();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'mp3',
                  child: Row(
                    children: [
                      const Icon(Icons.music_note_rounded, color: Color(0xFF38BDF8), size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.tr('pickMp3')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'mp4',
                  child: Row(
                    children: [
                      const Icon(Icons.movie_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.tr('pickMp4')),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(l10n.tr('saveChanges')),
              ),
            ),
          ],
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: _filePath == null
              ? _buildEmptyState(l10n, theme, isDark)
              : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildEditorContent(l10n, theme, isDark),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, ThemeData theme, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 48.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.tr('coverEditorTitle'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tr('selectMediaTypePrompt'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 36),

                // Choice Cards: MP3 or MP4
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 550;
                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(
                            child: _buildChoiceCard(
                              title: l10n.tr('pickMp3'),
                              subtitle: l10n.tr('mp3Description'),
                              icon: Icons.music_note_rounded,
                              color: const Color(0xFF38BDF8),
                              onTap: _pickMp3File,
                              isDark: isDark,
                              theme: theme,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildChoiceCard(
                              title: l10n.tr('pickMp4'),
                              subtitle: l10n.tr('mp4Description'),
                              icon: Icons.movie_rounded,
                              color: const Color(0xFF10B981),
                              onTap: _pickMp4File,
                              isDark: isDark,
                              theme: theme,
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildChoiceCard(
                            title: l10n.tr('pickMp3'),
                            subtitle: l10n.tr('mp3Description'),
                            icon: Icons.music_note_rounded,
                            color: const Color(0xFF38BDF8),
                            onTap: _pickMp3File,
                            isDark: isDark,
                            theme: theme,
                          ),
                          const SizedBox(height: 16),
                          _buildChoiceCard(
                            title: l10n.tr('pickMp4'),
                            subtitle: l10n.tr('mp4Description'),
                            icon: Icons.movie_rounded,
                            color: const Color(0xFF10B981),
                            onTap: _pickMp4File,
                            isDark: isDark,
                            theme: theme,
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282B30) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF3F444D) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.file_open_outlined, size: 16),
              label: Text(title),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorContent(
    AppLocalizations l10n,
    ThemeData theme,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 750;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Cover Preview and Image controls
                Expanded(
                  flex: 4,
                  child: _buildCoverArtCard(l10n, theme, isDark),
                ),
                const SizedBox(width: 32),
                // Right: Metadata tags
                Expanded(
                  flex: 5,
                  child: _buildMetadataCard(l10n, theme, isDark),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                _buildCoverArtCard(l10n, theme, isDark),
                const SizedBox(height: 24),
                _buildMetadataCard(l10n, theme, isDark),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildCoverArtCard(
    AppLocalizations l10n,
    ThemeData theme,
    bool isDark,
  ) {
    final hasCover = _coverBytes != null && _coverBytes!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.tr('currentCover'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasCover)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.tr('downloadCoverTooltip'),
                        icon: const Icon(Icons.file_download_outlined, size: 22),
                        onPressed: _downloadCover,
                      ),
                      IconButton(
                        tooltip: l10n.tr('viewFullImage'),
                        icon: const Icon(Icons.fullscreen_rounded, size: 22),
                        onPressed: _openFullImageViewer,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Image Container
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2024) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF3F444D) : const Color(0xFFD1D5DB),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: hasCover
                    ? InkWell(
                        onTap: _openFullImageViewer,
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.memory(
                                _coverBytes!,
                                fit: _coverFit,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.zoom_in_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.image_not_supported_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.tr('noCoverInFile'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Dimensions & Fit Controls
            if (hasCover) ...[
              if (_coverWidth != null && _coverHeight != null)
                Text(
                  l10n.tr('imageDimensions', {
                    'width': '$_coverWidth',
                    'height': '$_coverHeight',
                    'size': _formatBytes(_coverBytes!.length),
                  }),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: Text(l10n.tr('coverFitContain'), style: const TextStyle(fontSize: 11)),
                    selected: _coverFit == BoxFit.contain,
                    onSelected: (selected) {
                      if (selected) setState(() => _coverFit = BoxFit.contain);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(l10n.tr('coverFitCover'), style: const TextStyle(fontSize: 11)),
                    selected: _coverFit == BoxFit.cover,
                    onSelected: (selected) {
                      if (selected) setState(() => _coverFit = BoxFit.cover);
                    },
                  ),
                ],
              ),
            ],

            // Video Scrub Controls (Only for MP4)
            if (_isMp4 && _videoDurationSeconds > 0) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.tr('captureFrameFromVideo'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${_videoScrubSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: _videoScrubSeconds.clamp(0.0, _videoDurationSeconds),
                min: 0.0,
                max: _videoDurationSeconds > 0 ? _videoDurationSeconds : 60.0,
                onChanged: (val) {
                  setState(() => _videoScrubSeconds = val);
                },
                onChangeEnd: (val) {
                  _scrubFrame(val);
                },
              ),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 12),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickNewCover,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: Text(l10n.tr('uploadNewCover')),
              ),
            ),
            if (hasCover) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _downloadCover,
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: Text(l10n.tr('downloadCover')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _removeCover,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    label: Text(
                      l10n.tr('removeCover'),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(
    AppLocalizations l10n,
    ThemeData theme,
    bool isDark,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isMp4
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : const Color(0xFF38BDF8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isMp4 ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                    ),
                  ),
                  child: Text(
                    _isMp4 ? 'MP4 فيديو' : 'MP3 صوت',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isMp4 ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _fileName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.tr('switchFile'),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  onSelected: (val) {
                    if (val == 'mp3') {
                      _pickMp3File();
                    } else if (val == 'mp4') {
                      _pickMp4File();
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'mp3',
                      child: Row(
                        children: [
                          const Icon(Icons.music_note_rounded, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 8),
                          Text(l10n.tr('pickMp3')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'mp4',
                      child: Row(
                        children: [
                          const Icon(Icons.movie_rounded, color: Color(0xFF10B981), size: 18),
                          const SizedBox(width: 8),
                          Text(l10n.tr('pickMp4')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // File properties chips
            Row(
              children: [
                if (_duration > Duration.zero)
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 14),
                    label: Text(
                      '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                const SizedBox(width: 8),
                if (!_isMp4 && _bitrate > 0)
                  Chip(
                    avatar: const Icon(Icons.speed_rounded, size: 14),
                    label: Text(
                      '$_bitrate kbps',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
            const Divider(height: 32),

            Text(
              l10n.tr('editMetadata'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.tr('title'),
                prefixIcon: const Icon(Icons.title_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _artistController,
              decoration: InputDecoration(
                labelText: l10n.tr('artist'),
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _albumController,
              decoration: InputDecoration(
                labelText: l10n.tr('album'),
                prefixIcon: const Icon(Icons.album_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                icon: const Icon(Icons.save_rounded),
                label: Text(l10n.tr('saveChanges')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
