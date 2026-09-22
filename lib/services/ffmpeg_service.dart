import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class HwAccelInfo {
  final bool hasNvenc;
  final bool hasVaapi;
  final bool hasQsv;
  final bool hasVideoToolbox;
  final String recommendedType; // 'nvenc', 'vaapi', 'qsv', 'cpu_ultrafast'
  final String encoderName; // 'h264_nvenc', 'h264_vaapi', etc.
  final String description; // e.g. 'NVIDIA GeForce GTX 1650 Ti (NVENC)'

  HwAccelInfo({
    this.hasNvenc = false,
    this.hasVaapi = false,
    this.hasQsv = false,
    this.hasVideoToolbox = false,
    this.recommendedType = 'cpu_ultrafast',
    this.encoderName = 'libx264',
    this.description = 'CPU (Multi-core)',
  });
}

class FFmpegResult {
  final bool success;
  final String? errorMessage;
  final String? outputPath;

  FFmpegResult({
    required this.success,
    this.errorMessage,
    this.outputPath,
  });
}

class FFmpegProgressInfo {
  final double progress; // 0.0 to 1.0
  final Duration currentTime;
  final Duration totalDuration;

  FFmpegProgressInfo({
    required this.progress,
    required this.currentTime,
    required this.totalDuration,
  });
}

class FFmpegService {
  static bool? _isFFmpegAvailableCached;
  static HwAccelInfo? _cachedHwAccel;

  /// Check if system ffmpeg exists on Desktop
  static Future<bool> checkDesktopFFmpeg() async {
    if (kIsWeb) return false;
    if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
      return true; // Mobile uses bundled FFmpegKit
    }

    if (_isFFmpegAvailableCached != null) {
      return _isFFmpegAvailableCached!;
    }

    try {
      final cmd = Platform.isWindows ? 'where' : 'which';
      final res = await Process.run(cmd, ['ffmpeg']);
      final available = res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty;
      _isFFmpegAvailableCached = available;
      return available;
    } catch (e) {
      debugPrint('FFmpeg check error: $e');
      _isFFmpegAvailableCached = false;
      return false;
    }
  }

  static void resetFFmpegCache() {
    _isFFmpegAvailableCached = null;
    _cachedHwAccel = null;
  }

  /// Detect GPU Hardware Acceleration encoders (NVIDIA NVENC, VAAPI, QSV, etc.)
  static Future<HwAccelInfo> detectHardwareAcceleration() async {
    if (_cachedHwAccel != null) return _cachedHwAccel!;
    if (kIsWeb || (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows)) {
      _cachedHwAccel = HwAccelInfo();
      return _cachedHwAccel!;
    }

    try {
      final res = await Process.run('ffmpeg', ['-encoders']);
      final out = res.stdout.toString();
      final hasNvenc = out.contains('h264_nvenc');
      final hasVaapi = out.contains('h264_vaapi');
      final hasQsv = out.contains('h264_qsv');
      final hasVideoToolbox = out.contains('h264_videotoolbox');

      String gpuDesc = 'CPU (Multi-core)';
      String recType = 'cpu_ultrafast';
      String encName = 'libx264';

      if (hasNvenc) {
        try {
          final smi = await Process.run('nvidia-smi', ['--query-gpu=name', '--format=csv,noheader']);
          if (smi.exitCode == 0 && smi.stdout.toString().trim().isNotEmpty) {
            final name = smi.stdout.toString().trim().split('\n').first;
            gpuDesc = '$name (NVIDIA NVENC)';
          } else {
            gpuDesc = 'NVIDIA GPU (NVENC)';
          }
        } catch (_) {
          gpuDesc = 'NVIDIA GPU (NVENC)';
        }
        recType = 'nvenc';
        encName = 'h264_nvenc';
      } else if (hasVideoToolbox && Platform.isMacOS) {
        gpuDesc = 'Apple Silicon / Metal (VideoToolbox)';
        recType = 'videotoolbox';
        encName = 'h264_videotoolbox';
      } else if (hasVaapi && Platform.isLinux) {
        gpuDesc = 'Linux GPU (VAAPI)';
        recType = 'vaapi';
        encName = 'h264_vaapi';
      } else if (hasQsv) {
        gpuDesc = 'Intel Quick Sync (QSV)';
        recType = 'qsv';
        encName = 'h264_qsv';
      }

      _cachedHwAccel = HwAccelInfo(
        hasNvenc: hasNvenc,
        hasVaapi: hasVaapi,
        hasQsv: hasQsv,
        hasVideoToolbox: hasVideoToolbox,
        recommendedType: recType,
        encoderName: encName,
        description: gpuDesc,
      );
      return _cachedHwAccel!;
    } catch (e) {
      debugPrint('detectHardwareAcceleration error: $e');
      _cachedHwAccel = HwAccelInfo();
      return _cachedHwAccel!;
    }
  }

  /// Extract a single frame from video at the given scrub timestamp (in seconds)
  static Future<Uint8List?> extractVideoFrame({
    required String videoPath,
    double timestampSeconds = 0.0,
  }) async {
    if (kIsWeb) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final outImagePath = p.join(
        tempDir.path,
        'frame_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final formattedTime = _formatSecondsToTimestamp(timestampSeconds);

      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final args = [
          '-y',
          '-ss',
          formattedTime,
          '-i',
          videoPath,
          '-frames:v',
          '1',
          '-q:v',
          '2',
          outImagePath,
        ];

        final process = await Process.run('ffmpeg', args);
        if (process.exitCode == 0 && await File(outImagePath).exists()) {
          final bytes = await File(outImagePath).readAsBytes();
          try {
            await File(outImagePath).delete();
          } catch (_) {}
          return bytes;
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        final cmd =
            '-y -ss $formattedTime -i "$videoPath" -frames:v 1 -q:v 2 "$outImagePath"';
        final session = await FFmpegKit.execute(cmd);
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode) &&
            await File(outImagePath).exists()) {
          final bytes = await File(outImagePath).readAsBytes();
          try {
            await File(outImagePath).delete();
          } catch (_) {}
          return bytes;
        }
      }
    } catch (e) {
      debugPrint('extractVideoFrame error: $e');
    }
    return null;
  }

  /// Extract cover art from MP4 (first checking embedded attached_pic, fallback to video frame)
  static Future<Uint8List?> extractMp4CoverOrFrame({
    required String videoPath,
    double timestampSeconds = 0.0,
  }) async {
    if (kIsWeb) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final outImagePath = p.join(
        tempDir.path,
        'mp4_cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Check if MP4 has an attached_pic stream
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        try {
          final probe = await Process.run('ffprobe', [
            '-v', 'error',
            '-show_entries', 'stream_disposition=attached_pic:stream=index',
            '-of', 'json',
            videoPath,
          ]);

          if (probe.exitCode == 0) {
            final parsed = jsonDecode(probe.stdout.toString());
            if (parsed is Map && parsed['streams'] is List) {
              final streams = parsed['streams'] as List;
              int? attachedIdx;
              for (final s in streams) {
                if (s is Map) {
                  final disp = s['disposition'];
                  if (disp is Map && disp['attached_pic'] == 1) {
                    attachedIdx = s['index'] as int?;
                    break;
                  }
                }
              }

              if (attachedIdx != null) {
                final extractRes = await Process.run('ffmpeg', [
                  '-y',
                  '-i', videoPath,
                  '-map', '0:$attachedIdx',
                  '-c', 'copy',
                  outImagePath,
                ]);
                if (extractRes.exitCode == 0 && await File(outImagePath).exists()) {
                  final bytes = await File(outImagePath).readAsBytes();
                  try { await File(outImagePath).delete(); } catch (_) {}
                  return bytes;
                }
              }
            }
          }
        } catch (_) {}
      }

      // Fallback: extract frame from video
      return await extractVideoFrame(
        videoPath: videoPath,
        timestampSeconds: timestampSeconds,
      );
    } catch (e) {
      debugPrint('extractMp4CoverOrFrame error: $e');
      return null;
    }
  }

  /// Read metadata tags from video or audio file
  static Future<Map<String, String>> readMediaTags(String filePath) async {
    final result = <String, String>{'title': '', 'artist': '', 'album': ''};
    if (kIsWeb) return result;
    try {
      final probe = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'format_tags=title,artist,album',
        '-of', 'json',
        filePath,
      ]);
      if (probe.exitCode == 0) {
        final parsed = jsonDecode(probe.stdout.toString());
        if (parsed is Map && parsed['format'] is Map && parsed['format']['tags'] is Map) {
          final tags = parsed['format']['tags'] as Map;
          result['title'] = (tags['title'] ?? tags['TITLE'] ?? '').toString();
          result['artist'] = (tags['artist'] ?? tags['ARTIST'] ?? '').toString();
          result['album'] = (tags['album'] ?? tags['ALBUM'] ?? '').toString();
        }
      }
    } catch (_) {}
    return result;
  }

  /// Update cover art and metadata tags in an MP4 file in-place (Lossless & Instant via -c copy)
  static Future<bool> updateMp4CoverAndMetadata({
    required String filePath,
    Uint8List? newCoverBytes,
    bool removeCover = false,
    String? title,
    String? artist,
    String? album,
  }) async {
    if (kIsWeb) return false;

    File? tempImageFile;
    final tempOutPath = '$filePath.tmp_hawwil_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final List<String> args = ['-y'];

      if (!removeCover && newCoverBytes != null && newCoverBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        tempImageFile = File(
          p.join(tempDir.path, 'temp_cover_${DateTime.now().millisecondsSinceEpoch}.jpg'),
        );
        await tempImageFile.writeAsBytes(newCoverBytes);
      }

      args.addAll(['-i', filePath]);

      if (!removeCover && tempImageFile != null) {
        args.addAll(['-i', tempImageFile.path]);
        args.addAll([
          '-map', '0:v:0',
          '-map', '0:a?',
          '-map', '1:v',
          '-c', 'copy',
          '-disposition:v:1', 'attached_pic',
        ]);
      } else if (removeCover) {
        args.addAll([
          '-map', '0:v:0',
          '-map', '0:a?',
          '-c', 'copy',
        ]);
      } else {
        args.addAll([
          '-c', 'copy',
        ]);
      }

      if (title != null && title.isNotEmpty) {
        args.addAll(['-metadata', 'title=$title']);
      }
      if (artist != null && artist.isNotEmpty) {
        args.addAll(['-metadata', 'artist=$artist']);
      }
      if (album != null && album.isNotEmpty) {
        args.addAll(['-metadata', 'album=$album']);
      }

      args.add(tempOutPath);

      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final res = await Process.run('ffmpeg', args);
        if (res.exitCode == 0 && await File(tempOutPath).exists()) {
          await File(tempOutPath).rename(filePath);
          return true;
        } else {
          debugPrint('updateMp4CoverAndMetadata failed: ${res.stderr}');
          if (await File(tempOutPath).exists()) {
            try { await File(tempOutPath).delete(); } catch (_) {}
          }
          return false;
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        final cmd = args.map((a) => a.contains(' ') ? '"$a"' : a).join(' ');
        final session = await FFmpegKit.execute(cmd);
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode) && await File(tempOutPath).exists()) {
          await File(tempOutPath).rename(filePath);
          return true;
        }
      }
    } catch (e) {
      debugPrint('updateMp4CoverAndMetadata error: $e');
    } finally {
      if (tempImageFile != null && await tempImageFile.exists()) {
        try { await tempImageFile.delete(); } catch (_) {}
      }
      if (await File(tempOutPath).exists()) {
        try { await File(tempOutPath).delete(); } catch (_) {}
      }
    }
    return false;
  }

  /// Retrieve media duration in seconds
  static Future<double?> getMediaDuration(String filePath) async {
    if (kIsWeb) return null;

    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final res = await Process.run('ffprobe', [
          '-v',
          'error',
          '-show_entries',
          'format=duration',
          '-of',
          'default=noprint_wrappers=1:nokey=1',
          filePath,
        ]);
        if (res.exitCode == 0) {
          final seconds = double.tryParse(res.stdout.toString().trim());
          if (seconds != null && seconds > 0) return seconds;
        }

        final p = await Process.run('ffmpeg', ['-i', filePath]);
        final stderrStr = p.stderr.toString();
        return _parseDurationFromStderr(stderrStr);
      }
    } catch (e) {
      debugPrint('getMediaDuration error: $e');
    }
    return null;
  }

  /// Convert MP3 -> MP4
  /// Optimized for extreme speed with GPU hardware acceleration or CPU multi-threading
  static Future<FFmpegResult> convertMp3ToMp4({
    required String audioPath,
    required String imagePath,
    required String outputPath,
    String resolution = '1920x1080',
    String videoBitrate = '5000k',
    String audioBitrate = '320k',
    String hardwareAcceleration = 'auto',
    void Function(double progress)? onProgress,
    Completer<void>? cancelCompleter,
  }) async {
    if (kIsWeb) {
      return FFmpegResult(
        success: false,
        errorMessage: 'Web platform does not support local FFmpeg encoding.',
      );
    }

    final durationSec = await getMediaDuration(audioPath) ?? 180.0;

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      final hw = await detectHardwareAcceleration();
      final useNvenc = (hardwareAcceleration == 'auto' && hw.hasNvenc) || hardwareAcceleration == 'nvenc';
      final useVaapi = (hardwareAcceleration == 'auto' && !hw.hasNvenc && hw.hasVaapi) || hardwareAcceleration == 'vaapi';

      final List<String> encoderArgs = [];
      if (useNvenc) {
        encoderArgs.addAll([
          '-c:v', 'h264_nvenc',
          '-preset', 'p1',
          '-tune', 'ull',
          '-b:v', videoBitrate,
        ]);
      } else if (useVaapi) {
        encoderArgs.addAll([
          '-vaapi_device', '/dev/dri/renderD128',
          '-vf', 'format=nv12,hwupload',
          '-c:v', 'h264_vaapi',
          '-b:v', videoBitrate,
        ]);
      } else {
        // High-speed CPU encoding with multi-threading
        encoderArgs.addAll([
          '-c:v', 'libx264',
          '-preset', 'ultrafast',
          '-tune', 'stillimage',
          '-threads', '0',
          '-b:v', videoBitrate,
        ]);
      }

      final desktopArgs = [
        '-y',
        '-threads', '0',
        '-loop', '1',
        '-framerate', '2', // Smart low framerate for static cover image: 1000x faster!
        '-i', imagePath,
        '-i', audioPath,
        '-map', '0:v:0',
        '-map', '1:a:0',
        ...encoderArgs,
        '-c:a', 'aac',
        '-b:a', audioBitrate,
        '-s', resolution,
        '-pix_fmt', 'yuv420p',
        '-r', '2',
        '-shortest',
        outputPath,
      ];

      return _runDesktopConversion(
        args: desktopArgs,
        totalDurationSeconds: durationSec,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    } else {
      return _runMobileConversion(
        command:
            '-y -threads 0 -loop 1 -framerate 2 -i "$imagePath" -i "$audioPath" -map 0:v:0 -map 1:a:0 -c:v libx264 -preset ultrafast -tune stillimage -c:a aac -b:a $audioBitrate -b:v $videoBitrate -s $resolution -pix_fmt yuv420p -r 2 -shortest "$outputPath"',
        totalDurationSeconds: durationSec,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    }
  }

  /// Convert MP4 -> MP3
  /// Extract audio track to MP3 with multi-threading and direct stream copy if already mp3
  static Future<FFmpegResult> convertMp4ToMp3({
    required String videoPath,
    required String outputPath,
    String audioBitrate = '320k',
    void Function(double progress)? onProgress,
    Completer<void>? cancelCompleter,
  }) async {
    if (kIsWeb) {
      return FFmpegResult(
        success: false,
        errorMessage: 'Web platform does not support local FFmpeg encoding.',
      );
    }

    final durationSec = await getMediaDuration(videoPath) ?? 180.0;

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      bool isAudioAlreadyMp3 = false;
      try {
        final probe = await Process.run('ffprobe', [
          '-v', 'error',
          '-select_streams', 'a:0',
          '-show_entries', 'stream=codec_name',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          videoPath,
        ]);
        if (probe.exitCode == 0 && probe.stdout.toString().trim() == 'mp3') {
          isAudioAlreadyMp3 = true;
        }
      } catch (_) {}

      final List<String> args = [
        '-y',
        '-threads', '0',
        '-i', videoPath,
        '-vn',
        '-map', '0:a:0?',
      ];

      if (isAudioAlreadyMp3) {
        args.addAll(['-c:a', 'copy']);
      } else {
        args.addAll([
          '-c:a', 'libmp3lame',
          '-b:a', audioBitrate,
          '-qscale:a', '2',
        ]);
      }
      args.add(outputPath);

      return _runDesktopConversion(
        args: args,
        totalDurationSeconds: durationSec,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    } else {
      return _runMobileConversion(
        command:
            '-y -threads 0 -i "$videoPath" -vn -map 0:a:0? -c:a libmp3lame -b:a $audioBitrate -qscale:a 2 "$outputPath"',
        totalDurationSeconds: durationSec,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    }
  }

  /// Desktop runner streaming progress
  static Future<FFmpegResult> _runDesktopConversion({
    required List<String> args,
    required double totalDurationSeconds,
    required String outputPath,
    void Function(double progress)? onProgress,
    Completer<void>? cancelCompleter,
  }) async {
    try {
      final process = await Process.start('ffmpeg', args);

      bool isCancelled = false;
      cancelCompleter?.future.then((_) {
        isCancelled = true;
        process.kill(ProcessSignal.sigkill);
      });

      final stderrBuffer = StringBuffer();

      // Listen to stderr for progress parsing
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        stderrBuffer.writeln(line);

        // Parse time=HH:MM:SS.xx
        final match = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(line);
        if (match != null && totalDurationSeconds > 0) {
          final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
          final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
          final seconds = double.tryParse(match.group(3) ?? '0') ?? 0.0;
          final currentSec = (hours * 3600) + (minutes * 60) + seconds;

          final progress = (currentSec / totalDurationSeconds).clamp(0.0, 0.99);
          onProgress?.call(progress);
        }
      });

      final exitCode = await process.exitCode;

      if (isCancelled) {
        return FFmpegResult(
          success: false,
          errorMessage: 'Conversion cancelled by user.',
        );
      }

      if (exitCode == 0 && await File(outputPath).exists()) {
        onProgress?.call(1.0);
        return FFmpegResult(
          success: true,
          outputPath: outputPath,
        );
      } else {
        return FFmpegResult(
          success: false,
          errorMessage: 'FFmpeg failed (exit code $exitCode): ${stderrBuffer.toString().split('\n').take(5).join(' ')}',
        );
      }
    } catch (e) {
      return FFmpegResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Mobile runner using FFmpegKit
  static Future<FFmpegResult> _runMobileConversion({
    required String command,
    required double totalDurationSeconds,
    required String outputPath,
    void Function(double progress)? onProgress,
    Completer<void>? cancelCompleter,
  }) async {
    try {
      final sessionCompleter = Completer<FFmpegResult>();

      final session = await FFmpegKit.executeAsync(
        command,
        (completedSession) async {
          final returnCode = await completedSession.getReturnCode();
          if (ReturnCode.isSuccess(returnCode) &&
              await File(outputPath).exists()) {
            onProgress?.call(1.0);
            if (!sessionCompleter.isCompleted) {
              sessionCompleter.complete(
                FFmpegResult(success: true, outputPath: outputPath),
              );
            }
          } else {
            final failLogs = await completedSession.getFailStackTrace();
            if (!sessionCompleter.isCompleted) {
              sessionCompleter.complete(
                FFmpegResult(
                  success: false,
                  errorMessage: failLogs ?? 'Mobile FFmpeg session failed',
                ),
              );
            }
          }
        },
        null,
        (statistics) {
          if (totalDurationSeconds > 0) {
            final timeInMs = statistics.getTime();
            if (timeInMs > 0) {
              final progress = (timeInMs / (totalDurationSeconds * 1000))
                  .clamp(0.0, 0.99);
              onProgress?.call(progress);
            }
          }
        },
      );

      cancelCompleter?.future.then((_) async {
        await session.cancel();
        if (!sessionCompleter.isCompleted) {
          sessionCompleter.complete(
            FFmpegResult(
              success: false,
              errorMessage: 'Conversion cancelled by user.',
            ),
          );
        }
      });

      return await sessionCompleter.future;
    } catch (e) {
      return FFmpegResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  static String _formatSecondsToTimestamp(double seconds) {
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).floor();
    final s = seconds % 60;
    final hStr = h.toString().padLeft(2, '0');
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toStringAsFixed(2).padLeft(5, '0');
    return '$hStr:$mStr:$sStr';
  }

  static double? _parseDurationFromStderr(String stderr) {
    final match =
        RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.\d+)').firstMatch(stderr);
    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final seconds = double.tryParse(match.group(3) ?? '0') ?? 0.0;
      return (hours * 3600) + (minutes * 60) + seconds;
    }
    return null;
  }
}
