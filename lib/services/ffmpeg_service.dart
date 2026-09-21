import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

  /// Retrieve media duration in seconds
  static Future<double?> getMediaDuration(String filePath) async {
    if (kIsWeb) return null;

    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        // Try ffprobe
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

        // Fallback: run ffmpeg -i to read duration from stderr
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
  /// Single static image across full duration; H.264 video + AAC audio
  static Future<FFmpegResult> convertMp3ToMp4({
    required String audioPath,
    required String imagePath,
    required String outputPath,
    String resolution = '1920x1080',
    String videoBitrate = '5000k',
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

    final durationSec = await getMediaDuration(audioPath) ?? 180.0;

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return _runDesktopConversion(
        args: [
          '-y',
          '-loop',
          '1',
          '-i',
          imagePath,
          '-i',
          audioPath,
          '-c:v',
          'libx264',
          '-tune',
          'stillimage',
          '-c:a',
          'aac',
          '-b:a',
          audioBitrate,
          '-b:v',
          videoBitrate,
          '-s',
          resolution,
          '-pix_fmt',
          'yuv420p',
          '-shortest',
          outputPath,
        ],
        totalDurationSeconds: durationSec,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    } else {
      return _runMobileConversion(
        command:
            '-y -loop 1 -i "$imagePath" -i "$audioPath" -c:v libx264 -tune stillimage -c:a aac -b:a $audioBitrate -b:v $videoBitrate -s $resolution -pix_fmt yuv420p -shortest "$outputPath"',
        totalDurationSeconds: durationSec,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    }
  }

  /// Convert MP4 -> MP3
  /// Extract audio track to MP3 via libmp3lame
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
      return _runDesktopConversion(
        args: [
          '-y',
          '-i',
          videoPath,
          '-vn',
          '-c:a',
          'libmp3lame',
          '-b:a',
          audioBitrate,
          outputPath,
        ],
        totalDurationSeconds: durationSec,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    } else {
      return _runMobileConversion(
        command:
            '-y -i "$videoPath" -vn -c:a libmp3lame -b:a $audioBitrate "$outputPath"',
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
