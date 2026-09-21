import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../l10n/app_localizations.dart';
import '../../services/taglib_service.dart';

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
  Uint8List? _coverBytes;
  bool _coverRemoved = false;
  bool _isLoading = false;
  bool _isSaving = false;

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

    if (files.isNotEmpty && files.first.path != null) {
      final path = files.first.path!;
      await _loadMp3(path);
    }
  }

  Future<void> _loadMp3(String path) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _filePath = path;
      _fileName = p.basename(path);
      _coverRemoved = false;
      _coverWidth = null;
      _coverHeight = null;
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
      });
      WidgetsBinding.instance.scheduleFrame();
      await _decodeCoverDimensions(imgBytes);
    }
  }

  void _removeCover() {
    setState(() {
      _coverBytes = null;
      _coverRemoved = true;
      _coverWidth = null;
      _coverHeight = null;
    });
  }

  void _openFullImageViewer() {
    if (_coverBytes == null || _coverBytes!.isEmpty) return;
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
              child: CircleAvatar(
                backgroundColor: Colors.black87,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
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

    final success = await TagLibService.updateCoverAndMetadata(
      filePath: _filePath!,
      newCoverBytes: _coverBytes,
      removeCover: _coverRemoved,
      title: _titleController.text.trim(),
      artist: _artistController.text.trim(),
      album: _albumController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.tr('saved') : l10n.tr('error')),
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
      ),
      body: SafeArea(
        child: _filePath == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_filter_rounded,
                        size: 64,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.tr('coverEditorTitle'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
            : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_fileName != null) ...[
                          Text(
                            _fileName!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 10),

                        // Dimensions & Fit Toggle
                        if (hasCover) ...[
                          if (_coverWidth != null && _coverHeight != null)
                            Text(
                              l10n.tr('imageDimensions', {
                                'width': '$_coverWidth',
                                'height': '$_coverHeight',
                                'size': _formatBytes(_coverBytes!.length),
                              }),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ChoiceChip(
                                label: Text(l10n.tr('coverFitContain'), style: const TextStyle(fontSize: 10)),
                                selected: _coverFit == BoxFit.contain,
                                onSelected: (sel) {
                                  if (sel) setState(() => _coverFit = BoxFit.contain);
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text(l10n.tr('coverFitCover'), style: const TextStyle(fontSize: 10)),
                                selected: _coverFit == BoxFit.cover,
                                onSelected: (sel) {
                                  if (sel) setState(() => _coverFit = BoxFit.cover);
                                },
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Image actions
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickNewCover,
                                icon: const Icon(Icons.photo_library_outlined, size: 16),
                                label: Text(l10n.tr('uploadNewCover'), style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            if (hasCover) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: _removeCover,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Tags
                        Text(
                          l10n.tr('editMetadata'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
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
                          label: Text(l10n.tr('saveChanges')),
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
