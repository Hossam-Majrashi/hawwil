import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../services/id3_parser.dart';
import '../../services/cover_download_service.dart';

class WebCoverEditorScreen extends StatefulWidget {
  final VoidCallback onBack;

  const WebCoverEditorScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<WebCoverEditorScreen> createState() => _WebCoverEditorScreenState();
}

class _WebCoverEditorScreenState extends State<WebCoverEditorScreen> {
  String? _fileName;
  Uint8List? _coverBytes;
  int? _coverWidth;
  int? _coverHeight;
  BoxFit _coverFit = BoxFit.contain;

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

    if (files.isNotEmpty) {
      final f = files.first;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _fileName = f.name;
        _titleController.text = f.name.replaceAll('.mp3', '');
        _coverBytes = null;
        _coverWidth = null;
        _coverHeight = null;
      });

      if (bytes.isNotEmpty) {
        final meta = Id3Parser.parse(bytes);
        if (!mounted) return;
        setState(() {
          if (meta.title.isNotEmpty) _titleController.text = meta.title;
          if (meta.artist.isNotEmpty) _artistController.text = meta.artist;
          if (meta.album.isNotEmpty) _albumController.text = meta.album;
          if (meta.hasCover && meta.coverBytes != null && meta.coverBytes!.isNotEmpty) {
            _coverBytes = meta.coverBytes;
          }
        });
        if (_coverBytes != null) {
          await _decodeCoverDimensions(_coverBytes!);
        }
      }
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  Future<void> _pickImage() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
    );

    if (files.isNotEmpty) {
      final bytes = await files.first.readAsBytes();
      if (!mounted) return;
      setState(() {
        _coverBytes = bytes;
      });
      WidgetsBinding.instance.scheduleFrame();
      await _decodeCoverDimensions(bytes);
    }
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
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('screenCoverEditor')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: _fileName == null
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_filter_rounded, size: 64, color: Color(0xFF10B981)),
                          const SizedBox(height: 16),
                          Text(
                            l10n.tr('coverEditorTitle'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _pickMp3File,
                            icon: const Icon(Icons.folder_open_rounded),
                            label: Text(l10n.tr('pickMp3File')),
                          ),
                        ],
                      ),
                    ),
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cover preview
                          Column(
                            children: [
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E2024) : const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF3F444D) : const Color(0xFFD1D5DB),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: _coverBytes != null
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
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_coverBytes != null) ...[
                                if (_coverWidth != null && _coverHeight != null)
                                  Text(
                                    l10n.tr('imageDimensions', {
                                      'width': '$_coverWidth',
                                      'height': '$_coverHeight',
                                      'size': _formatBytes(_coverBytes!.length),
                                    }),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ChoiceChip(
                                      label: Text(l10n.tr('coverFitContain'), style: const TextStyle(fontSize: 10)),
                                      selected: _coverFit == BoxFit.contain,
                                      onSelected: (sel) {
                                        if (sel) setState(() => _coverFit = BoxFit.contain);
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    ChoiceChip(
                                      label: Text(l10n.tr('coverFitCover'), style: const TextStyle(fontSize: 10)),
                                      selected: _coverFit == BoxFit.cover,
                                      onSelected: (sel) {
                                        if (sel) setState(() => _coverFit = BoxFit.cover);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                              SizedBox(
                                width: 220,
                                child: OutlinedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.image_outlined, size: 16),
                                  label: Text(l10n.tr('uploadNewCover'), style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                              if (_coverBytes != null) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 220,
                                  child: FilledButton.tonalIcon(
                                    onPressed: _downloadCover,
                                    icon: const Icon(Icons.file_download_outlined, size: 16),
                                    label: Text(l10n.tr('downloadCover'), style: const TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(width: 28),
                          // Metadata fields
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _fileName!,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _titleController,
                                  decoration: InputDecoration(labelText: l10n.tr('title')),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _artistController,
                                  decoration: InputDecoration(labelText: l10n.tr('artist')),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _albumController,
                                  decoration: InputDecoration(labelText: l10n.tr('album')),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l10n.tr('saved'))),
                                    );
                                  },
                                  icon: const Icon(Icons.save_rounded),
                                  label: Text(l10n.tr('saveChanges')),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
