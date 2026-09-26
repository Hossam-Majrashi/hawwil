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

class MobileCoverEditorScreen extends StatefulWidget {
  final VoidCallback onBack;

  const MobileCoverEditorScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<MobileCoverEditorScreen> createState() =>
      _MobileCoverEditorScreenState();
}

class _MobileCoverEditorScreenState extends State<MobileCoverEditorScreen> {
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
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
              decoration: BoxDecoration(
                color: const Color(0xFF181A1D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3F444D)),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 4),
                ],
              ),
              padding: const EdgeInsets.all(12),
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
              top: 6,
              right: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black87,
                    child: IconButton(
                      tooltip: l10n.tr('downloadCover'),
                      icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 20),
                      onPressed: _downloadCover,
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: Colors.black87,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
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
    final hasCover = _coverBytes != null && _coverBytes!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('screenCoverEditor')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
        actions: [
          if (_filePath != null)
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
        ],
      ),
      body: SafeArea(
        child: _filePath == null
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_library_outlined,
                          size: 48,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.tr('coverEditorTitle'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.tr('selectMediaTypePrompt'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 28),

                      // MP3 Choice
                      InkWell(
                        onTap: _pickMp3File,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF282B30) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF3F444D) : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.music_note_rounded, color: Color(0xFF38BDF8), size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.tr('pickMp3'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.tr('mp3Description'),
                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // MP4 Choice
                      InkWell(
                        onTap: _pickMp4File,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF282B30) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF3F444D) : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.movie_rounded, color: Color(0xFF10B981), size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.tr('pickMp4'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.tr('mp4Description'),
                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_fileName != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _isMp4
                                      ? const Color(0xFF10B981).withOpacity(0.15)
                                      : const Color(0xFF38BDF8).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _isMp4 ? 'MP4' : 'MP3',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _isMp4 ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _fileName!,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Cover Image Preview
                        Center(
                          child: Container(
                            width: 240,
                            height: 240,
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
                                            bottom: 6,
                                            right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.zoom_in_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        l10n.tr('noCoverInFile'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Image Dimensions & Fit
                        if (hasCover) ...[
                          if (_coverWidth != null && _coverHeight != null)
                            Text(
                              l10n.tr('imageDimensions', {
                                'width': '$_coverWidth',
                                'height': '$_coverHeight',
                                'size': _formatBytes(_coverBytes!.length),
                              }),
                              textAlign: TextAlign.center,
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

                        // Video Scrubbing (Only for MP4)
                        if (_isMp4 && _videoDurationSeconds > 0) ...[
                          const SizedBox(height: 12),
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
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                        ],

                        const SizedBox(height: 16),

                        // Action Buttons: Pick / Download / Remove
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _pickNewCover,
                                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                                label: Text(l10n.tr('uploadNewCover'), style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            if (hasCover) ...[
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: l10n.tr('downloadCover'),
                                onPressed: _downloadCover,
                                icon: const Icon(Icons.file_download_outlined, size: 18),
                              ),
                              const SizedBox(width: 4),
                              IconButton.outlined(
                                tooltip: l10n.tr('removeCover'),
                                onPressed: _removeCover,
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Metadata Editor
                        Text(
                          l10n.tr('editMetadata'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: l10n.tr('title'),
                            prefixIcon: const Icon(Icons.title_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _artistController,
                          decoration: InputDecoration(
                            labelText: l10n.tr('artist'),
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _albumController,
                          decoration: InputDecoration(
                            labelText: l10n.tr('album'),
                            prefixIcon: const Icon(Icons.album_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveChanges,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(_isSaving ? l10n.tr('saving') : l10n.tr('saveChanges')),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
