import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/merge_media_item.dart';
import 'ffmpeg_service.dart';

class MergeMediaController extends ChangeNotifier {
  static final Set<Process> _allRunningProcesses = {};
  static bool _signalsHooked = false;

  static void hookExitSignals() {
    if (_signalsHooked || kIsWeb) return;
    _signalsHooked = true;
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        ProcessSignal.sigint.watch().listen((_) {
          stopAllPlayback();
          exit(0);
        });
        ProcessSignal.sigterm.watch().listen((_) {
          stopAllPlayback();
          exit(0);
        });
      }
    } catch (_) {}
  }

  static void stopAllPlayback() {
    for (final p in _allRunningProcesses) {
      try {
        p.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
    _allRunningProcesses.clear();
  }

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  MergeMediaController() {
    hookExitSignals();
  }

  final List<MergeMediaItem> mediaPool = [];
  final List<MergeMediaItem> visualTimeline = [];
  final List<MergeMediaItem> audioTimeline = [];

  bool isPlaying = false;
  double currentPositionSec = 0.0;
  Timer? _playbackTimer;
  Process? _audioProcess;
  String? _currentAudioItemId;
  int _playbackEpoch = 0;
  bool _isSpawningAudio = false;
  DateTime? _lastTickTime;

  bool isExporting = false;
  double exportProgress = 0.0;
  String? exportErrorMessage;
  String? exportedFilePath;
  Completer<void>? _cancelCompleter;

  // Total visual duration in seconds
  double get totalVisualDurationSec => visualTimeline.fold(
        0.0,
        (acc, item) => acc + item.durationInSeconds,
      );

  // Total audio duration in seconds
  double get totalAudioDurationSec => audioTimeline.fold(
        0.0,
        (acc, item) => acc + item.durationInSeconds,
      );

  // Overall timeline duration across visual and audio tracks
  double get totalDurationSec {
    final v = totalVisualDurationSec;
    final a = totalAudioDurationSec;
    if (v > 0 && a > 0) return v > a ? v : a;
    if (v > 0) return v;
    if (a > 0) return a;
    return 0.0;
  }

  bool get hasContent => visualTimeline.isNotEmpty || audioTimeline.isNotEmpty;
  bool get isAudioOnly => visualTimeline.isEmpty && audioTimeline.isNotEmpty;

  // Timeline scale in pixels-per-second (single source of truth for the entire timeline)
  static const double defaultPixelsPerSecond = 50.0;
  static const double minPixelsPerSecond = 10.0;
  static const double maxPixelsPerSecond = 500.0;

  double _pixelsPerSecond = defaultPixelsPerSecond;
  double get pixelsPerSecond => _pixelsPerSecond;
  double get timelineScale => _pixelsPerSecond;

  double get zoomLevel => _pixelsPerSecond / defaultPixelsPerSecond;

  void setPixelsPerSecond(double pps) {
    final clamped = pps.clamp(minPixelsPerSecond, maxPixelsPerSecond);
    if ((_pixelsPerSecond - clamped).abs() > 0.001) {
      _pixelsPerSecond = clamped;
      notifyListeners();
    }
  }

  void setZoomLevel(double zoom) {
    setPixelsPerSecond(defaultPixelsPerSecond * zoom);
  }

  void zoomByFactor(double factor) {
    setPixelsPerSecond(_pixelsPerSecond * factor);
  }

  // Exact start time in seconds for items on visual timeline
  double getVisualItemStartSec(int index) {
    double start = 0.0;
    for (int i = 0; i < index && i < visualTimeline.length; i++) {
      start += visualTimeline[i].durationInSeconds;
    }
    return start;
  }

  // Exact start time in seconds for items on audio timeline
  double getAudioItemStartSec(int index) {
    double start = 0.0;
    for (int i = 0; i < index && i < audioTimeline.length; i++) {
      start += audioTimeline[i].durationInSeconds;
    }
    return start;
  }

  double _outputFps = 30.0;
  double get outputFps => _outputFps;
  set outputFps(double value) {
    if (value > 0) {
      _outputFps = value;
      notifyListeners();
    }
  }

  // Active / project frame rate.
  // For audio-only timelines (or empty visual timeline), returns 0.0 (no meaningful frame rate).
  // Otherwise returns actual detected video fps or output frame rate.
  double get projectFps {
    if (isAudioOnly || visualTimeline.isEmpty) return 0.0;
    for (final item in visualTimeline) {
      if (item.isVideo && item.fps != null && item.fps! > 0) {
        return item.fps!;
      }
    }
    return _outputFps;
  }

  static String formatTimecodeStatic(double seconds, {double? fps}) {
    if (seconds.isNaN || seconds.isInfinite || seconds < 0) {
      return '00:00:00:00';
    }
    final totalSec = seconds.floor();
    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    final secs = totalSec % 60;

    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');

    String ff = '00';
    final effectiveFps = fps ?? 0.0;
    if (effectiveFps > 0) {
      final fracSec = seconds - totalSec;
      final maxFrame = (effectiveFps - 1).round();
      final frameIndex = (fracSec * effectiveFps).floor().clamp(0, maxFrame);
      ff = frameIndex.toString().padLeft(2, '0');
    }

    return '$hh:$mm:$ss:$ff';
  }

  String formatTimecode(double seconds) {
    return formatTimecodeStatic(seconds, fps: projectFps);
  }

  // Active visual item at current playhead position
  MergeMediaItem? get activeVisualItem {
    if (visualTimeline.isEmpty) return null;
    double accumulated = 0.0;
    for (final item in visualTimeline) {
      final end = accumulated + item.durationInSeconds;
      if (currentPositionSec >= accumulated && currentPositionSec < end) {
        return item;
      }
      accumulated = end;
    }
    // If audio is longer and visual sequence already finished
    if (currentPositionSec >= accumulated && totalAudioDurationSec > totalVisualDurationSec) {
      return null;
    }
    return visualTimeline.last;
  }

  double get activeVisualItemStartSec {
    double accumulated = 0.0;
    for (final item in visualTimeline) {
      final end = accumulated + item.durationInSeconds;
      if (currentPositionSec >= accumulated && currentPositionSec < end) {
        return accumulated;
      }
      accumulated = end;
    }
    return accumulated;
  }

  double get activeVisualItemOffsetSec {
    final item = activeVisualItem;
    if (item == null) return 0.0;
    return (currentPositionSec - activeVisualItemStartSec).clamp(0.0, item.durationInSeconds);
  }

  // Active audio item at current playhead position
  MergeMediaItem? get activeAudioItem {
    if (audioTimeline.isEmpty) return null;
    double accumulated = 0.0;
    for (final item in audioTimeline) {
      final end = accumulated + item.durationInSeconds;
      if (currentPositionSec >= accumulated && currentPositionSec < end) {
        return item;
      }
      accumulated = end;
    }
    return null;
  }

  double get activeAudioItemStartSec {
    double accumulated = 0.0;
    for (final item in audioTimeline) {
      final end = accumulated + item.durationInSeconds;
      if (currentPositionSec >= accumulated && currentPositionSec < end) {
        return accumulated;
      }
      accumulated = end;
    }
    return accumulated;
  }

  double get activeAudioItemOffsetSec {
    final item = activeAudioItem;
    if (item == null) return 0.0;
    return (currentPositionSec - activeAudioItemStartSec).clamp(0.0, item.durationInSeconds);
  }

  String? get activeAudioFilePath {
    final audioItem = activeAudioItem;
    if (audioItem != null) {
      return audioItem.path;
    }
    final visualItem = activeVisualItem;
    if (visualItem != null && visualItem.isVideo) {
      return visualItem.path;
    }
    return null;
  }

  String? get activeAudioItemId {
    final audioItem = activeAudioItem;
    if (audioItem != null) {
      return audioItem.id;
    }
    final visualItem = activeVisualItem;
    if (visualItem != null && visualItem.isVideo) {
      return visualItem.id;
    }
    return null;
  }

  void _stopAudioPlaybackSync() {
    _currentAudioItemId = null;
    _playbackEpoch++;
    if (_audioProcess != null) {
      try {
        _allRunningProcesses.remove(_audioProcess);
        _audioProcess?.kill(ProcessSignal.sigkill);
      } catch (_) {}
      _audioProcess = null;
    }
  }

  Future<void> _syncAudioPlayback() async {
    if (kIsWeb) return;
    if (!isPlaying) {
      _stopAudioPlaybackSync();
      return;
    }

    final targetId = activeAudioItemId;
    final targetPath = activeAudioFilePath;
    final targetOffset = activeAudioItem != null
        ? activeAudioItemOffsetSec
        : (activeVisualItem?.isVideo == true ? activeVisualItemOffsetSec : 0.0);

    // If no clip should be playing at current playhead position
    if (targetId == null || targetPath == null || targetPath.isEmpty) {
      _stopAudioPlaybackSync();
      return;
    }

    // If the active clip is already playing or currently being spawned, don't duplicate
    if (_currentAudioItemId == targetId && (_audioProcess != null || _isSpawningAudio)) {
      return;
    }

    // Stop previous clip immediately before launching the next one
    _stopAudioPlaybackSync();

    final myEpoch = ++_playbackEpoch;
    _currentAudioItemId = targetId;
    _isSpawningAudio = true;

    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final proc = await Process.start('ffplay', [
          '-nodisp',
          '-autoexit',
          '-loglevel',
          'quiet',
          '-ss',
          targetOffset.toStringAsFixed(3),
          targetPath,
        ]);
        _allRunningProcesses.add(proc);

        // If user sought, paused, or playhead crossed during the async start, kill immediately
        if (myEpoch != _playbackEpoch || !isPlaying || _currentAudioItemId != targetId) {
          try {
            _allRunningProcesses.remove(proc);
            proc.kill(ProcessSignal.sigkill);
          } catch (_) {}
          return;
        }

        _audioProcess = proc;
        _isSpawningAudio = false;

        proc.exitCode.then((_) {
          _allRunningProcesses.remove(proc);
          if (_audioProcess == proc) {
            _audioProcess = null;
            if (_currentAudioItemId == targetId) {
              _currentAudioItemId = null;
            }
          }
        });
      }
    } catch (e) {
      _isSpawningAudio = false;
      debugPrint('Audio playback error: $e');
    }
  }

  void togglePlay() {
    if (isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    if (totalDurationSec <= 0) return;
    if (currentPositionSec >= totalDurationSec - 0.05) {
      currentPositionSec = 0.0;
    }
    isPlaying = true;
    _lastTickTime = DateTime.now();
    notifyListeners();

    _syncAudioPlayback();

    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (!isPlaying) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      final dt = _lastTickTime != null
          ? (now.difference(_lastTickTime!).inMicroseconds / 1000000.0)
          : 0.025;
      _lastTickTime = now;

      final nextPos = currentPositionSec + dt;
      if (nextPos >= totalDurationSec) {
        currentPositionSec = totalDurationSec;
        isPlaying = false;
        timer.cancel();
        _stopAudioPlaybackSync();
        notifyListeners();
        return;
      }

      currentPositionSec = nextPos;
      _syncAudioPlayback();
      notifyListeners();
    });
  }

  void pause() {
    isPlaying = false;
    _playbackTimer?.cancel();
    _lastTickTime = null;
    _stopAudioPlaybackSync();
    notifyListeners();
  }

  void stop() {
    isPlaying = false;
    _playbackTimer?.cancel();
    _lastTickTime = null;
    _stopAudioPlaybackSync();
    currentPositionSec = 0.0;
    notifyListeners();
  }

  void seekTo(double seconds) {
    final maxDur = totalDurationSec > 0 ? totalDurationSec : 0.0;
    currentPositionSec = seconds.clamp(0.0, maxDur);
    _lastTickTime = DateTime.now();
    if (isPlaying) {
      _stopAudioPlaybackSync();
      _syncAudioPlayback();
    } else {
      _stopAudioPlaybackSync();
    }
    notifyListeners();
  }

  Future<void> pickMediaFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          // Images
          'jpg', 'jpeg', 'png', 'webp', 'bmp',
          // Videos
          'mp4', 'mkv', 'mov', 'webm', 'avi', 'flv', 'wmv', 'm4v', 'ts', 'mpg', 'mpeg', 'ogv',
          // Audio
          'mp3', 'wav', 'aac', 'flac', 'm4a', 'ogg', 'opus', 'wma',
        ],
      );

      if (files.isEmpty) return;

      for (final file in files) {
        final path = file.path;
        if (path == null) continue;
        final name = file.name;
        final ext = p.extension(path).toLowerCase().replaceAll('.', '');

        MergeMediaType type;
        Duration duration = const Duration(seconds: 3);
        Uint8List? thumb;
        double? fps;
        int? width;
        int? height;

        if (['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext)) {
          type = MergeMediaType.image;
          duration = const Duration(seconds: 3);
          if (!kIsWeb) {
            try {
              thumb = await File(path).readAsBytes();
            } catch (_) {}
          }
        } else if (['mp3', 'wav', 'aac', 'flac', 'm4a', 'ogg', 'opus', 'wma'].contains(ext)) {
          type = MergeMediaType.audio;
          if (!kIsWeb) {
            final durSec = await FFmpegService.getMediaDuration(path);
            if (durSec != null && durSec > 0) {
              duration = Duration(milliseconds: (durSec * 1000).round());
            }
          }
        } else {
          type = MergeMediaType.video;
          if (!kIsWeb) {
            try {
              final info = await FFmpegService.probeMedia(path);
              fps = info.fps;
              width = info.width;
              height = info.height;
            } catch (_) {}
            final durSec = await FFmpegService.getMediaDuration(path);
            if (durSec != null && durSec > 0) {
              duration = Duration(milliseconds: (durSec * 1000).round());
            }
            try {
              final targetTs = (durSec != null && durSec > 1.0) ? 1.0 : 0.0;
              thumb = await FFmpegService.extractVideoFrame(videoPath: path, timestampSeconds: targetTs);
              thumb ??= await FFmpegService.extractVideoFrame(videoPath: path, timestampSeconds: 0.0);
            } catch (_) {}
          }
        }

        final item = MergeMediaItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${mediaPool.length}',
          path: path,
          name: name,
          type: type,
          duration: duration,
          thumbnailBytes: thumb,
          width: width,
          height: height,
          fps: fps,
        );

        mediaPool.add(item);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error picking media files: $e');
    }
  }

  void addToTrack(MergeMediaItem item, int trackIndex, [int? insertIndex]) {
    final copy = item.copyWith(
      id: '${DateTime.now().microsecondsSinceEpoch}_track$trackIndex',
    );

    if (trackIndex == 1 && item.isImage) {
      if (insertIndex != null && insertIndex >= 0 && insertIndex <= visualTimeline.length) {
        visualTimeline.insert(insertIndex, copy);
      } else {
        visualTimeline.add(copy);
      }
    } else if (trackIndex == 2 && item.isVideo) {
      if (insertIndex != null && insertIndex >= 0 && insertIndex <= visualTimeline.length) {
        visualTimeline.insert(insertIndex, copy);
      } else {
        visualTimeline.add(copy);
      }
    } else if (trackIndex == 3 && item.isAudio) {
      if (insertIndex != null && insertIndex >= 0 && insertIndex <= audioTimeline.length) {
        audioTimeline.insert(insertIndex, copy);
      } else {
        audioTimeline.add(copy);
      }
    }
    notifyListeners();
  }

  void updateImageDuration(String itemId, Duration newDuration) {
    final idx = visualTimeline.indexWhere((i) => i.id == itemId);
    if (idx != -1 && visualTimeline[idx].isImage) {
      visualTimeline[idx].duration = newDuration;
      notifyListeners();
    }
  }

  void ensureVideoThumbnail(MergeMediaItem item) {
    if (item.thumbnailBytes != null || !item.isVideo || kIsWeb) return;
    FFmpegService.extractVideoFrame(videoPath: item.path, timestampSeconds: 0.0).then((bytes) {
      if (bytes != null) {
        item.thumbnailBytes = bytes;
        notifyListeners();
      }
    });
  }

  void removeVisualItem(int index) {
    if (index >= 0 && index < visualTimeline.length) {
      visualTimeline.removeAt(index);
      if (currentPositionSec > totalDurationSec) {
        currentPositionSec = totalDurationSec;
      }
      if (isPlaying) {
        _syncAudioPlayback();
      }
      notifyListeners();
    }
  }

  void removeAudioItem(int index) {
    if (index >= 0 && index < audioTimeline.length) {
      audioTimeline.removeAt(index);
      if (currentPositionSec > totalDurationSec) {
        currentPositionSec = totalDurationSec;
      }
      if (isPlaying) {
        _syncAudioPlayback();
      }
      notifyListeners();
    }
  }

  void reorderVisualItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= visualTimeline.length) return;
    final item = visualTimeline.removeAt(oldIndex);
    var target = newIndex;
    if (target < 0) target = 0;
    if (target > visualTimeline.length) target = visualTimeline.length;
    visualTimeline.insert(target, item);
    if (isPlaying) {
      _syncAudioPlayback();
    }
    notifyListeners();
  }

  void reorderAudioItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= audioTimeline.length) return;
    final item = audioTimeline.removeAt(oldIndex);
    var target = newIndex;
    if (target < 0) target = 0;
    if (target > audioTimeline.length) target = audioTimeline.length;
    audioTimeline.insert(target, item);
    if (isPlaying) {
      _syncAudioPlayback();
    }
    notifyListeners();
  }

  void moveVisualItem(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex >= 0 && newIndex < visualTimeline.length) {
      final item = visualTimeline.removeAt(index);
      visualTimeline.insert(newIndex, item);
      notifyListeners();
    }
  }

  void moveAudioItem(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex >= 0 && newIndex < audioTimeline.length) {
      final item = audioTimeline.removeAt(index);
      audioTimeline.insert(newIndex, item);
      notifyListeners();
    }
  }

  void clearAll() {
    stop();
    visualTimeline.clear();
    audioTimeline.clear();
    notifyListeners();
  }

  Future<bool> exportMergedMedia({
    required String targetFormat,
    required String resolution,
    String? customOutputPath,
  }) async {
    if (visualTimeline.isEmpty && audioTimeline.isEmpty) {
      exportErrorMessage = 'No media items in timeline';
      notifyListeners();
      return false;
    }

    isExporting = true;
    exportProgress = 0.0;
    exportErrorMessage = null;
    exportedFilePath = null;
    _cancelCompleter = Completer<void>();
    notifyListeners();

    try {
      String outPath = customOutputPath ?? '';
      if (outPath.isEmpty) {
        Directory dir;
        try {
          dir = (await getDownloadsDirectory()) ?? (await getApplicationDocumentsDirectory());
        } catch (_) {
          dir = await getTemporaryDirectory();
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        outPath = p.join(dir.path, 'hawwil_merged_$timestamp.$targetFormat');
      }

      final res = await FFmpegService.mergeMedia(
        visualItems: visualTimeline,
        audioItems: audioTimeline,
        outputPath: outPath,
        targetFormat: targetFormat,
        resolution: resolution,
        hardwareAcceleration: 'auto',
        onProgress: (prog) {
          if (!_isDisposed) {
            exportProgress = prog;
            notifyListeners();
          }
        },
        cancelCompleter: _cancelCompleter,
      );

      if (_isDisposed) return false;

      isExporting = false;
      if (res.success) {
        exportProgress = 1.0;
        exportedFilePath = outPath;
        notifyListeners();
        return true;
      } else {
        exportErrorMessage = res.errorMessage ?? 'Merge failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (!_isDisposed) {
        isExporting = false;
        exportErrorMessage = e.toString();
        notifyListeners();
      }
      return false;
    }
  }

  void cancelExport() {
    if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
      _cancelCompleter!.complete();
    }
    isExporting = false;
    exportErrorMessage = 'Cancelled by user';
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
      _cancelCompleter!.complete();
    }
    _stopAudioPlaybackSync();
    _playbackTimer?.cancel();
    stopAllPlayback();
    super.dispose();
  }
}
