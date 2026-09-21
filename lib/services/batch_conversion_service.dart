import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/conversion_item.dart';
import '../models/conversion_settings.dart';
import 'ffmpeg_service.dart';
import 'taglib_service.dart';

class BatchConversionService extends ChangeNotifier {
  final List<ConversionItem> _items = [];
  bool _isProcessing = false;
  int _currentIndex = 0;
  Completer<void>? _currentCancelCompleter;

  List<ConversionItem> get items => List.unmodifiable(_items);
  bool get isProcessing => _isProcessing;
  int get totalCount => _items.length;
  int get completedCount =>
      _items.where((i) => i.status == ConversionStatus.completed).length;
  int get failedCount =>
      _items.where((i) => i.status == ConversionStatus.failed).length;

  bool get hasCompletedItems =>
      _items.any((i) => i.status == ConversionStatus.completed);

  bool get allFinished =>
      _items.isNotEmpty &&
      _items.every((i) =>
          i.status == ConversionStatus.completed ||
          i.status == ConversionStatus.failed ||
          i.status == ConversionStatus.cancelled);

  double get overallProgress {
    if (_items.isEmpty) return 0.0;
    final totalProgress = _items.fold<double>(
      0.0,
      (sum, item) =>
          sum + (item.status == ConversionStatus.completed ? 1.0 : item.progress),
    );
    return totalProgress / _items.length;
  }

  void addFiles(List<String> paths) {
    for (final path in paths) {
      final fileName = p.basename(path);
      final isMp3 = fileName.toLowerCase().endsWith('.mp3');
      final direction =
          isMp3 ? ConversionDirection.mp3ToMp4 : ConversionDirection.mp4ToMp3;

      final item = ConversionItem(
        id: '${DateTime.now().microsecondsSinceEpoch}_${_items.length}',
        sourcePath: path,
        fileName: fileName,
        direction: direction,
      );

      _items.add(item);
      _inspectItem(item);
    }
    notifyListeners();
  }

  void removeItem(String id) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) {
      if (_isProcessing && idx == _currentIndex) {
        cancelCurrent();
      }
      _items.removeAt(idx);
      notifyListeners();
    }
  }

  void clearQueue() {
    if (_isProcessing) {
      cancelAll();
    }
    _items.clear();
    _currentIndex = 0;
    notifyListeners();
  }

  void clearCompleted() {
    if (_isProcessing) return;
    _items.removeWhere((i) => i.status == ConversionStatus.completed);
    notifyListeners();
  }

  void resetForNewProject() {
    if (_isProcessing) return;
    _items.clear();
    _currentIndex = 0;
    notifyListeners();
  }

  void toggleDirection(ConversionItem item) {
    if (item.direction == ConversionDirection.mp3ToMp4) {
      item.direction = ConversionDirection.mp4ToMp3;
    } else {
      item.direction = ConversionDirection.mp3ToMp4;
    }
    notifyListeners();
  }

  void setCustomImage(ConversionItem item, String imagePath, Uint8List bytes) {
    item.customImagePath = imagePath;
    item.thumbnailBytes = bytes;
    notifyListeners();
  }

  void setVideoScrub(ConversionItem item, double seconds) {
    item.videoScrubSeconds = seconds;
    notifyListeners();
  }

  void setMetadata(ConversionItem item, {String? title, String? artist, String? album}) {
    if (title != null) item.title = title;
    if (artist != null) item.artist = artist;
    if (album != null) item.album = album;
    notifyListeners();
  }

  Future<void> _inspectItem(ConversionItem item) async {
    item.status = ConversionStatus.extractingThumbnail;
    notifyListeners();

    try {
      if (item.direction == ConversionDirection.mp3ToMp4) {
        // Read embedded cover art
        final meta = await TagLibService.readMetadata(item.sourcePath);
        if (meta.hasCover && meta.coverBytes != null) {
          item.thumbnailBytes = meta.coverBytes;
          item.hasEmbeddedCover = true;
        }
        item.title = meta.title.isNotEmpty ? meta.title : p.basenameWithoutExtension(item.fileName);
        item.artist = meta.artist;
        item.album = meta.album;
        if (meta.duration > Duration.zero) {
          item.durationSeconds = meta.duration.inMilliseconds / 1000.0;
        }
      } else {
        // MP4: extract first frame
        final frameBytes = await FFmpegService.extractVideoFrame(
          videoPath: item.sourcePath,
          timestampSeconds: 0.0,
        );
        if (frameBytes != null) {
          item.thumbnailBytes = frameBytes;
        }
        item.title = p.basenameWithoutExtension(item.fileName);
        final dur = await FFmpegService.getMediaDuration(item.sourcePath);
        item.durationSeconds = dur;
      }
    } catch (e) {
      debugPrint('Error inspecting item ${item.fileName}: $e');
    } finally {
      item.status = ConversionStatus.queued;
      notifyListeners();
    }
  }

  /// Start or resume batch conversion
  Future<void> startBatch(ConversionSettings settings) async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.status == ConversionStatus.completed) continue;

      _currentIndex = i;
      _currentCancelCompleter = Completer<void>();

      await _convertItem(item, settings, _currentCancelCompleter!);
      notifyListeners();
    }

    _isProcessing = false;
    notifyListeners();
  }

  /// Retry a single item
  Future<void> retryItem(ConversionItem item, ConversionSettings settings) async {
    item.reset();
    notifyListeners();

    _currentCancelCompleter = Completer<void>();
    await _convertItem(item, settings, _currentCancelCompleter!);
    notifyListeners();
  }

  void cancelCurrent() {
    if (_currentCancelCompleter != null && !_currentCancelCompleter!.isCompleted) {
      _currentCancelCompleter!.complete();
    }
    if (_currentIndex < _items.length) {
      _items[_currentIndex].status = ConversionStatus.cancelled;
      notifyListeners();
    }
  }

  void cancelAll() {
    cancelCurrent();
    for (final item in _items) {
      if (item.status == ConversionStatus.queued ||
          item.status == ConversionStatus.converting) {
        item.status = ConversionStatus.cancelled;
      }
    }
    _isProcessing = false;
    notifyListeners();
  }

  Future<void> _convertItem(
    ConversionItem item,
    ConversionSettings settings,
    Completer<void> cancelCompleter,
  ) async {
    item.status = ConversionStatus.converting;
    item.progress = 0.0;
    item.errorMessage = null;
    notifyListeners();

    try {
      // Determine output directory
      String outDir = settings.outputFolder ?? p.dirname(item.sourcePath);
      final dirObj = Directory(outDir);
      if (!await dirObj.exists()) {
        await dirObj.create(recursive: true);
      }

      final baseNameWithoutExt = p.basenameWithoutExtension(item.fileName);
      final formattedName = settings.filenamePattern
          .replaceAll('{name}', baseNameWithoutExt)
          .replaceAll('{title}', item.title ?? baseNameWithoutExt);

      if (item.direction == ConversionDirection.mp3ToMp4) {
        // Output MP4
        final outPath = p.join(outDir, '$formattedName.mp4');
        item.outputPath = outPath;

        // Image to use
        String imageToUse;
        File? tempGeneratedImageFile;

        if (item.customImagePath != null &&
            await File(item.customImagePath!).exists()) {
          imageToUse = item.customImagePath!;
        } else if (item.thumbnailBytes != null &&
            item.thumbnailBytes!.isNotEmpty) {
          // Write thumbnail to temporary file
          final tempDir = await getTemporaryDirectory();
          final tempImg = File(
            p.join(
              tempDir.path,
              'hawwil_cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          );
          await tempImg.writeAsBytes(item.thumbnailBytes!);
          tempGeneratedImageFile = tempImg;
          imageToUse = tempImg.path;
        } else {
          // Fallback: create solid dark frame with Hawwil branding
          final tempDir = await getTemporaryDirectory();
          final tempImg = File(
            p.join(
              tempDir.path,
              'hawwil_solid_${DateTime.now().millisecondsSinceEpoch}.png',
            ),
          );
          await tempImg.writeAsBytes(_createFallbackImageBytes());
          tempGeneratedImageFile = tempImg;
          imageToUse = tempImg.path;
        }

        final res = await FFmpegService.convertMp3ToMp4(
          audioPath: item.sourcePath,
          imagePath: imageToUse,
          outputPath: outPath,
          resolution: item.resolutionOverride ?? settings.defaultResolution,
          videoBitrate: item.videoBitrateOverride ?? settings.defaultVideoBitrate,
          audioBitrate: item.audioBitrateOverride ?? settings.defaultAudioBitrate,
          onProgress: (prog) {
            item.progress = prog;
            notifyListeners();
          },
          cancelCompleter: cancelCompleter,
        );

        if (tempGeneratedImageFile != null &&
            await tempGeneratedImageFile.exists()) {
          try {
            await tempGeneratedImageFile.delete();
          } catch (_) {}
        }

        if (res.success) {
          item.status = ConversionStatus.completed;
          item.progress = 1.0;
        } else {
          item.status = ConversionStatus.failed;
          item.errorMessage = res.errorMessage;
        }
      } else {
        // Output MP3
        final outPath = p.join(outDir, '$formattedName.mp3');
        item.outputPath = outPath;

        final res = await FFmpegService.convertMp4ToMp3(
          videoPath: item.sourcePath,
          outputPath: outPath,
          audioBitrate: item.audioBitrateOverride ?? settings.defaultAudioBitrate,
          onProgress: (prog) {
            // Audio extraction accounts for 85% of progress
            item.progress = prog * 0.85;
            notifyListeners();
          },
          cancelCompleter: cancelCompleter,
        );

        if (res.success) {
          // Extract frame if needed and embed into MP3
          Uint8List? coverToEmbed = item.thumbnailBytes;

          if (item.videoScrubSeconds > 0 || coverToEmbed == null) {
            final scrubbedFrame = await FFmpegService.extractVideoFrame(
              videoPath: item.sourcePath,
              timestampSeconds: item.videoScrubSeconds,
            );
            if (scrubbedFrame != null) {
              coverToEmbed = scrubbedFrame;
            }
          }

          // Embed cover art and tags
          if (await File(outPath).exists()) {
            await TagLibService.updateCoverAndMetadata(
              filePath: outPath,
              newCoverBytes: coverToEmbed,
              title: item.title,
              artist: item.artist,
              album: item.album,
            );
          }

          item.status = ConversionStatus.completed;
          item.progress = 1.0;
        } else {
          item.status = ConversionStatus.failed;
          item.errorMessage = res.errorMessage;
        }
      }
    } catch (e) {
      item.status = ConversionStatus.failed;
      item.errorMessage = e.toString();
    }
  }

  Uint8List _createFallbackImageBytes() {
    // 1x1 dark pixel PNG header/data fallback (valid PNG)
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x72, 0xB6, 0x0D, 0x24, 0x00, 0x00, 0x00,
      0x15, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x30, 0x33, 0x37, 0x67,
      0x00, 0x02, 0x82, 0x00, 0x05, 0x00, 0x02, 0x09, 0x00, 0xF9, 0xE7, 0x35,
      0xFA, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
      0x82
    ]);
  }
}
