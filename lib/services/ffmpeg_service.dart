import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/merge_media_item.dart';
import '../models/conversion_item.dart';

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

class VideoCodecConfig {
  final List<String> videoEncoderArgs;
  final List<String> audioEncoderArgs;
  final List<String> extraArgs;
  final String containerFormat;

  VideoCodecConfig({
    required this.videoEncoderArgs,
    required this.audioEncoderArgs,
    this.extraArgs = const [],
    required this.containerFormat,
  });
}

class MediaInfo {
  final int? width;
  final int? height;
  final double? fps;
  final int? videoBitrateKbps;
  final int? audioBitrateKbps;
  final int? audioSampleRate;
  final int? audioChannels;
  final int? totalBitrateKbps;
  final double? durationSeconds;

  const MediaInfo({
    this.width,
    this.height,
    this.fps,
    this.videoBitrateKbps,
    this.audioBitrateKbps,
    this.audioSampleRate,
    this.audioChannels,
    this.totalBitrateKbps,
    this.durationSeconds,
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

  /// Checks whether an image is completely or virtually pitch black (e.g. uninitialized frame or fade-in)
  static Future<bool> isImageVisuallyBlack(Uint8List bytes) async {
    if (bytes.length < 50) return true;
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 32, targetHeight: 32);
      final frame = await codec.getNextFrame();
      final bd = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bd == null) return false;
      final rgba = bd.buffer.asUint8List();
      int totalLuma = 0;
      final pixelCount = rgba.length ~/ 4;
      if (pixelCount == 0) return true;
      for (int i = 0; i < rgba.length; i += 4) {
        final r = rgba[i];
        final g = rgba[i + 1];
        final b = rgba[i + 2];
        totalLuma += (r * 299 + g * 587 + b * 114) ~/ 1000;
      }
      final avgLuma = totalLuma / pixelCount;
      return avgLuma < 8.0;
    } catch (_) {
      return false;
    }
  }

  /// Extract a single frame from video at the given scrub timestamp (in seconds).
  /// When timestampSeconds <= 0.0, sequentially decodes the first frame without fast-seek before -i.
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

      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final List<String> args;
        if (timestampSeconds <= 0.0) {
          args = [
            '-y',
            '-i',
            videoPath,
            '-frames:v',
            '1',
            '-q:v',
            '2',
            outImagePath,
          ];
        } else {
          final formattedTime = _formatSecondsToTimestamp(timestampSeconds);
          args = [
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
        }

        final process = await Process.run('ffmpeg', args);
        if (process.exitCode == 0 && await File(outImagePath).exists()) {
          final bytes = await File(outImagePath).readAsBytes();
          try {
            await File(outImagePath).delete();
          } catch (_) {}
          return bytes;
        } else if (timestampSeconds > 0) {
          return await extractVideoFrame(videoPath: videoPath, timestampSeconds: 0.0);
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        final String cmd;
        if (timestampSeconds <= 0.0) {
          cmd = '-y -i "$videoPath" -frames:v 1 -q:v 2 "$outImagePath"';
        } else {
          final formattedTime = _formatSecondsToTimestamp(timestampSeconds);
          cmd = '-y -ss $formattedTime -i "$videoPath" -frames:v 1 -q:v 2 "$outImagePath"';
        }
        final session = await FFmpegKit.execute(cmd);
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode) &&
            await File(outImagePath).exists()) {
          final bytes = await File(outImagePath).readAsBytes();
          try {
            await File(outImagePath).delete();
          } catch (_) {}
          return bytes;
        } else if (timestampSeconds > 0) {
          return await extractVideoFrame(videoPath: videoPath, timestampSeconds: 0.0);
        }
      }
    } catch (e) {
      debugPrint('extractVideoFrame error: $e');
    }
    return null;
  }

  /// Extract cover art from MP4 (first checking embedded attached_pic, fallback to video's first non-black frame)
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

      // 1. Check if MP4 has an attached_pic stream
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
                  if (bytes.isNotEmpty && !(await isImageVisuallyBlack(bytes))) {
                    return bytes;
                  }
                }
              }
            }
          }
        } catch (_) {}
      } else if (Platform.isAndroid || Platform.isIOS) {
        try {
          final cmd = '-y -i "$videoPath" -map 0:v:attached_pic? -c copy "$outImagePath"';
          final session = await FFmpegKit.execute(cmd);
          if (ReturnCode.isSuccess(await session.getReturnCode()) &&
              await File(outImagePath).exists() &&
              (await File(outImagePath).length()) > 0) {
            final bytes = await File(outImagePath).readAsBytes();
            try { await File(outImagePath).delete(); } catch (_) {}
            if (bytes.isNotEmpty && !(await isImageVisuallyBlack(bytes))) {
              return bytes;
            }
          }
        } catch (_) {}
      }

      // 2. Fallback: extract frame from video (defaults to video's own first frame)
      var frame = await extractVideoFrame(
        videoPath: videoPath,
        timestampSeconds: timestampSeconds,
      );

      // If the extracted frame is visually black and we requested default/start,
      // search slightly forward to get the first visible frame instead of a black screen
      if (frame != null && timestampSeconds <= 0.0 && (await isImageVisuallyBlack(frame))) {
        final dur = await getMediaDuration(videoPath) ?? 1.0;
        final probeSeconds = [0.1, 0.5, 1.0, 2.0];
        for (final sec in probeSeconds) {
          if (sec < dur) {
            final nextFrame = await extractVideoFrame(
              videoPath: videoPath,
              timestampSeconds: sec,
            );
            if (nextFrame != null && !(await isImageVisuallyBlack(nextFrame))) {
              frame = nextFrame;
              break;
            }
          }
        }
      }

      return frame;
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

  /// Update cover art and metadata tags in a video file.
  /// When [newCoverBytes] is provided and [replaceVideoFrames] is true (e.g. user picked an image in Cover Editor),
  /// the image becomes both the video's cover/thumbnail AND its entire visual content throughout its duration
  /// by reusing the static-image video pipeline (`convertMp3ToVideo`), preserving the original audio track.
  /// When [replaceVideoFrames] is false or [newCoverBytes] is null, updates tags and/or removes cover in-place via `-c copy`.
  static Future<bool> updateMp4CoverAndMetadata({
    required String filePath,
    Uint8List? newCoverBytes,
    bool removeCover = false,
    bool replaceVideoFrames = true,
    String? title,
    String? artist,
    String? album,
  }) async {
    if (kIsWeb) return false;

    File? tempImageFile;
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    final targetFmt = ext.isNotEmpty ? ext : 'mp4';
    final tempOutPath = '$filePath.tmp_hawwil_${DateTime.now().millisecondsSinceEpoch}.${targetFmt == 'matroska' ? 'mkv' : targetFmt}';

    try {
      if (!removeCover && newCoverBytes != null && newCoverBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        tempImageFile = File(
          p.join(tempDir.path, 'temp_cover_${DateTime.now().millisecondsSinceEpoch}.jpg'),
        );
        await tempImageFile.writeAsBytes(newCoverBytes);

        if (replaceVideoFrames) {
          final res = await convertMp3ToVideo(
            audioPath: filePath,
            imagePath: tempImageFile.path,
            outputPath: tempOutPath,
            targetFormat: targetFmt,
            title: title,
            artist: artist,
            album: album,
          );

          if (res.success && await File(tempOutPath).exists()) {
            await File(tempOutPath).rename(filePath);
            return true;
          } else {
            debugPrint('updateMp4CoverAndMetadata replaceVideoFrames failed: ${res.errorMessage}');
            return false;
          }
        }
      }

      final List<String> args = ['-y'];
      args.addAll(['-i', filePath]);

      if (!removeCover && tempImageFile != null) {
        args.addAll(['-i', tempImageFile.path]);
        args.addAll([
          '-map', '0:v:0',
          '-map', '0:a?',
          '-map', '1:v',
          '-c', 'copy',
          '-disposition:v:1', 'attached_pic',
          '-movflags', '+faststart',
        ]);
      } else if (removeCover) {
        args.addAll([
          '-map', '0:v:0',
          '-map', '0:a?',
          '-c', 'copy',
          '-movflags', '+faststart',
        ]);
      } else {
        args.addAll([
          '-c', 'copy',
          '-movflags', '+faststart',
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

  /// Check if the media file contains a video stream
  static Future<bool> hasVideoStream(String filePath) async {
    if (kIsWeb) return false;

    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final res = await Process.run('ffprobe', [
          '-v',
          'error',
          '-select_streams',
          'v:0',
          '-show_entries',
          'stream=codec_type',
          '-of',
          'default=noprint_wrappers=1:nokey=1',
          filePath,
        ]);
        if (res.exitCode == 0 && res.stdout.toString().trim() == 'video') {
          return true;
        }

        final p = await Process.run('ffmpeg', ['-i', filePath]);
        final stderrStr = p.stderr.toString();
        return RegExp(r'Stream #\d+:\d+.*Video:').hasMatch(stderrStr);
      } else if (Platform.isAndroid || Platform.isIOS) {
        final session = await FFmpegKit.execute('-i "$filePath"');
        final logs = await session.getAllLogsAsString();
        if (logs != null && RegExp(r'Stream #\d+:\d+.*Video:').hasMatch(logs)) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('hasVideoStream error: $e');
    }
    return false;
  }

  /// Probe media streams for resolution, bitrates, and duration
  static Future<MediaInfo> probeMedia(String filePath) async {
    if (kIsWeb) return const MediaInfo();

    try {
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final probe = await Process.run('ffprobe', [
          '-v', 'error',
          '-show_entries', 'stream=index,codec_type,width,height,bit_rate,r_frame_rate,avg_frame_rate,sample_rate,channels',
          '-show_entries', 'format=bit_rate,duration,size',
          '-of', 'json',
          filePath,
        ]);

        if (probe.exitCode == 0) {
          final parsed = jsonDecode(probe.stdout.toString());
          if (parsed is Map) {
            int? width;
            int? height;
            double? fps;
            int? videoBitrate;
            int? audioBitrate;
            int? audioSampleRate;
            int? audioChannels;
            int? totalBitrate;
            double? duration;

            if (parsed['format'] is Map) {
              final fmt = parsed['format'] as Map;
              final fmtBr = int.tryParse(fmt['bit_rate']?.toString() ?? '');
              if (fmtBr != null && fmtBr > 0) {
                totalBitrate = (fmtBr / 1000).round();
              }
              final dur = double.tryParse(fmt['duration']?.toString() ?? '');
              if (dur != null && dur > 0) {
                duration = dur;
              }
              final size = int.tryParse(fmt['size']?.toString() ?? '');
              if (totalBitrate == null && size != null && duration != null && duration > 0) {
                totalBitrate = ((size * 8) / (duration * 1000)).round();
              }
            }

            if (parsed['streams'] is List) {
              for (final s in parsed['streams'] as List) {
                if (s is Map) {
                  final cType = s['codec_type']?.toString();
                  if (cType == 'video' && width == null) {
                    width = int.tryParse(s['width']?.toString() ?? '');
                    height = int.tryParse(s['height']?.toString() ?? '');
                    final vBr = int.tryParse(s['bit_rate']?.toString() ?? '');
                    if (vBr != null && vBr > 0) {
                      videoBitrate = (vBr / 1000).round();
                    }
                    final rFps = s['r_frame_rate']?.toString();
                    final aFps = s['avg_frame_rate']?.toString();
                    fps = _parseFpsString(rFps) ?? _parseFpsString(aFps);
                  } else if (cType == 'audio') {
                    if (audioBitrate == null) {
                      final aBr = int.tryParse(s['bit_rate']?.toString() ?? '');
                      if (aBr != null && aBr > 0) {
                        audioBitrate = (aBr / 1000).round();
                      }
                    }
                    audioSampleRate ??= int.tryParse(s['sample_rate']?.toString() ?? '');
                    audioChannels ??= int.tryParse(s['channels']?.toString() ?? '');
                  }
                }
              }
            }

            if (videoBitrate == null && totalBitrate != null) {
              final aBr = audioBitrate ?? 64;
              videoBitrate = totalBitrate > aBr ? totalBitrate - aBr : totalBitrate;
            }

            if ((totalBitrate == null || totalBitrate <= 0) && duration != null && duration > 0) {
              try {
                final file = File(filePath);
                if (await file.exists()) {
                  final size = await file.length();
                  totalBitrate = ((size * 8) / (duration * 1000)).round();
                  videoBitrate ??= totalBitrate > 64 ? totalBitrate - 64 : totalBitrate;
                }
              } catch (_) {}
            }

            return MediaInfo(
              width: width,
              height: height,
              fps: fps,
              videoBitrateKbps: videoBitrate,
              audioBitrateKbps: audioBitrate,
              audioSampleRate: audioSampleRate,
              audioChannels: audioChannels,
              totalBitrateKbps: totalBitrate,
              durationSeconds: duration,
            );
          }
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        final session = await FFmpegKit.execute('-i "$filePath"');
        final logs = await session.getAllLogsAsString() ?? '';
        return _parseMediaInfoFromLogs(logs, filePath);
      }
    } catch (e) {
      debugPrint('probeMedia error: $e');
    }
    return const MediaInfo();
  }

  static double? _parseFpsString(String? str) {
    if (str == null || str.isEmpty) return null;
    final parts = str.split('/');
    if (parts.length == 2) {
      final num = double.tryParse(parts[0]);
      final den = double.tryParse(parts[1]);
      if (num != null && den != null && den > 0 && num > 0) {
        final val = num / den;
        if (!val.isNaN && !val.isInfinite && val > 0) return val;
      }
    } else {
      final val = double.tryParse(str);
      if (val != null && !val.isNaN && !val.isInfinite && val > 0) return val;
    }
    return null;
  }

  static MediaInfo _parseMediaInfoFromLogs(String logs, String filePath) {
    int? width;
    int? height;
    double? fps;
    int? videoBitrate;
    int? audioBitrate;
    int? audioSampleRate;
    int? audioChannels;
    int? totalBitrate;
    double? duration;

    final durMatch = RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.\d+)').firstMatch(logs);
    if (durMatch != null) {
      final hours = int.tryParse(durMatch.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(durMatch.group(2) ?? '0') ?? 0;
      final seconds = double.tryParse(durMatch.group(3) ?? '0') ?? 0.0;
      duration = (hours * 3600) + (minutes * 60) + seconds;
    }

    final brMatch = RegExp(r'bitrate:\s*(\d+)\s*kb/s').firstMatch(logs);
    if (brMatch != null) {
      totalBitrate = int.tryParse(brMatch.group(1) ?? '');
    }

    final vidMatch = RegExp(r'Stream #\d+:\d+.*Video:.*?(\d{2,5})x(\d{2,5})').firstMatch(logs);
    if (vidMatch != null) {
      width = int.tryParse(vidMatch.group(1) ?? '');
      height = int.tryParse(vidMatch.group(2) ?? '');
    }

    final fpsMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:fps|tbr)').firstMatch(logs);
    if (fpsMatch != null) {
      fps = double.tryParse(fpsMatch.group(1) ?? '');
    }

    final vidBrMatch = RegExp(r'Stream #\d+:\d+.*Video:.*?(\d+)\s*kb/s').firstMatch(logs);
    if (vidBrMatch != null) {
      videoBitrate = int.tryParse(vidBrMatch.group(1) ?? '');
    }

    final audBrMatch = RegExp(r'Stream #\d+:\d+.*Audio:.*?(\d+)\s*kb/s').firstMatch(logs);
    if (audBrMatch != null) {
      audioBitrate = int.tryParse(audBrMatch.group(1) ?? '');
    }

    final srMatch = RegExp(r'Audio:.*?(\d{4,6})\s*Hz').firstMatch(logs);
    if (srMatch != null) {
      audioSampleRate = int.tryParse(srMatch.group(1) ?? '');
    }

    final chMatch = RegExp(r'Audio:.*?(mono|stereo|\d+(?:\.\d+)?\s*channels?)').firstMatch(logs);
    if (chMatch != null) {
      final chStr = chMatch.group(1)!.toLowerCase();
      if (chStr.contains('mono')) {
        audioChannels = 1;
      } else if (chStr.contains('stereo')) {
        audioChannels = 2;
      } else {
        audioChannels = int.tryParse(RegExp(r'\d+').firstMatch(chStr)?.group(0) ?? '');
      }
    }

    if (totalBitrate == null && duration != null && duration > 0) {
      try {
        final f = File(filePath);
        if (f.existsSync()) {
          final size = f.lengthSync();
          totalBitrate = ((size * 8) / (duration * 1000)).round();
        }
      } catch (_) {}
    }

    if (videoBitrate == null && totalBitrate != null) {
      final aBr = audioBitrate ?? 64;
      videoBitrate = totalBitrate > aBr ? totalBitrate - aBr : totalBitrate;
    }

    return MediaInfo(
      width: width,
      height: height,
      fps: fps,
      videoBitrateKbps: videoBitrate,
      audioBitrateKbps: audioBitrate,
      audioSampleRate: audioSampleRate,
      audioChannels: audioChannels,
      totalBitrateKbps: totalBitrate,
      durationSeconds: duration,
    );
  }

  /// Calculates a generous safety cap sized to the source's resolution and framerate
  /// so complex scenes are never starved below CRF 23, while preventing runaway file size
  /// on extreme high-motion/high-resolution sources.
  static int calculateBitrateCap({
    required MediaInfo info,
    int? targetWidth,
    int? targetHeight,
    double? targetFps,
  }) {
    final w = targetWidth ?? info.width ?? 1280;
    final h = targetHeight ?? info.height ?? 720;
    final pixels = w * h;

    final fps = (targetFps ?? info.fps ?? 30.0).clamp(15.0, 120.0);
    final fpsFactor = fps / 30.0;

    int baseCapAt30fps;
    if (pixels <= 320 * 240) {
      baseCapAt30fps = 1500;
    } else if (pixels <= 640 * 360) {
      baseCapAt30fps = 3000;
    } else if (pixels <= 854 * 480) {
      baseCapAt30fps = 5000;
    } else if (pixels <= 1280 * 720) {
      baseCapAt30fps = 10000;
    } else if (pixels <= 1920 * 1080) {
      baseCapAt30fps = 20000;
    } else {
      // 4K and above
      baseCapAt30fps = 50000;
    }

    return (baseCapAt30fps * fpsFactor).round();
  }

  /// Builds quality-based (VBR) audio arguments avoiding fixed CBR bitrates,
  /// preserving source sample rate and channel count without wasteful upsampling.
  static List<String> buildAudioEncoderArgs({
    required String targetFormat,
    String? audioBitrate,
    int? sourceSampleRate,
    int? sourceChannels,
  }) {
    final fmt = targetFormat.toLowerCase().replaceAll('.', '');
    final isAuto = audioBitrate == null || audioBitrate == 'auto' || audioBitrate.isEmpty;
    final explicitKbps = !isAuto ? audioBitrate : null;

    final List<String> aArgs = [];

    switch (fmt) {
      case 'wav':
        aArgs.addAll(['-c:a', 'pcm_s16le']);
        break;

      case 'flac':
        aArgs.addAll(['-c:a', 'flac']);
        break;

      case 'ogg':
      case 'vorbis':
        if (isAuto) {
          aArgs.addAll(['-c:a', 'libvorbis', '-q:a', '5']);
        } else {
          aArgs.addAll(['-c:a', 'libvorbis', '-b:a', explicitKbps!]);
        }
        break;

      case 'opus':
        if (isAuto) {
          aArgs.addAll(['-c:a', 'libopus', '-b:a', '128k', '-vbr', 'on']);
        } else {
          aArgs.addAll(['-c:a', 'libopus', '-b:a', explicitKbps!, '-vbr', 'on']);
        }
        break;

      case 'wmv':
      case 'asf':
      case 'wma':
      case 'wmav2':
        if (isAuto) {
          aArgs.addAll(['-c:a', 'wmav2', '-b:a', '160k']);
        } else {
          aArgs.addAll(['-c:a', 'wmav2', '-b:a', explicitKbps!]);
        }
        break;

      case 'mpg':
      case 'mpeg':
      case 'mp2':
        if (isAuto) {
          aArgs.addAll(['-c:a', 'mp2', '-b:a', '192k']);
        } else {
          aArgs.addAll(['-c:a', 'mp2', '-b:a', explicitKbps!]);
        }
        break;

      case 'aac':
      case 'm4a':
      case 'flv':
      case 'mp4':
      case 'mkv':
      case 'mov':
        if (isAuto) {
          aArgs.addAll(['-c:a', 'aac', '-q:a', '2']);
        } else {
          aArgs.addAll(['-c:a', 'aac', '-b:a', explicitKbps!]);
        }
        break;

      case 'mp3':
      case 'avi':
      default:
        if (isAuto) {
          aArgs.addAll(['-c:a', 'libmp3lame', '-q:a', '2']);
        } else {
          aArgs.addAll(['-c:a', 'libmp3lame', '-b:a', explicitKbps!]);
        }
        break;
    }

    // Never upsample channels: if source is mono, keep mono; if stereo, keep stereo.
    if (sourceChannels != null && sourceChannels > 0) {
      aArgs.addAll(['-ac', '$sourceChannels']);
    }

    // Never upsample sample rate beyond what source actually has.
    if (sourceSampleRate != null && sourceSampleRate > 0) {
      if (fmt == 'opus') {
        const supportedOpusRates = [8000, 12000, 16000, 24000, 48000];
        if (supportedOpusRates.contains(sourceSampleRate)) {
          aArgs.addAll(['-ar', '$sourceSampleRate']);
        }
      } else {
        aArgs.addAll(['-ar', '$sourceSampleRate']);
      }
    }

    return aArgs;
  }

  /// Unified codec and container configuration builder sitting in one place for
  /// both static-image cover-to-video and video-to-video conversions.
  static Future<VideoCodecConfig> getCodecConfigForFormat({
    required String targetFormat,
    String? videoBitrate,
    String? audioBitrate,
    required String hardwareAcceleration,
    bool isStaticImage = false,
    int? maxRateKbps,
    int? audioSampleRate,
    int? audioChannels,
    double? fps,
  }) async {
    final fmt = targetFormat.toLowerCase().replaceAll('.', '');
    final hw = await detectHardwareAcceleration();
    final useNvenc = (hardwareAcceleration == 'auto' && hw.hasNvenc) || hardwareAcceleration == 'nvenc';
    final useVaapi = (hardwareAcceleration == 'auto' && !hw.hasNvenc && hw.hasVaapi) || hardwareAcceleration == 'vaapi';
    final useQsv = (hardwareAcceleration == 'auto' && !hw.hasNvenc && !hw.hasVaapi && hw.hasQsv) || hardwareAcceleration == 'qsv';
    final useVideoToolbox = (hardwareAcceleration == 'auto' && !hw.hasNvenc && !hw.hasVaapi && !hw.hasQsv && hw.hasVideoToolbox && Platform.isMacOS) || hardwareAcceleration == 'videotoolbox';

    final effectiveFps = (fps != null && fps > 0)
        ? fps
        : (isStaticImage ? 2.0 : 30.0);
    final gopSize = (effectiveFps * 2).round().clamp(1, 600);
    final gopStr = '$gopSize';

    int? requestedKbps;
    if (videoBitrate != null && videoBitrate != 'auto' && videoBitrate.isNotEmpty) {
      requestedKbps = int.tryParse(videoBitrate.replaceAll(RegExp(r'[^0-9]'), ''));
    }

    final capStr = maxRateKbps != null ? '${maxRateKbps}k' : null;
    final bufStr = maxRateKbps != null ? '${maxRateKbps * 2}k' : null;

    switch (fmt) {
      case 'webm':
        final List<String> vArgs = [
          '-c:v', 'libvpx-vp9',
          '-g', gopStr,
          '-keyint_min', gopStr,
          '-deadline', 'realtime',
          '-cpu-used', '8',
        ];
        if (requestedKbps != null) {
          vArgs.addAll(['-b:v', '${requestedKbps}k']);
        } else {
          vArgs.addAll(['-b:v', '0', '-crf', '31']);
          if (capStr != null) {
            vArgs.addAll(['-maxrate', capStr, '-bufsize', bufStr!]);
          }
        }
        return VideoCodecConfig(
          containerFormat: 'webm',
          videoEncoderArgs: vArgs,
          audioEncoderArgs: buildAudioEncoderArgs(
            targetFormat: 'opus',
            audioBitrate: audioBitrate,
            sourceSampleRate: audioSampleRate,
            sourceChannels: audioChannels,
          ),
          extraArgs: ['-pix_fmt', 'yuv420p'],
        );

      case 'avi':
        final List<String> vArgs = [
          '-c:v', 'mpeg4',
          '-vtag', 'XVID',
          '-g', gopStr,
          '-keyint_min', gopStr,
        ];
        if (requestedKbps != null) {
          vArgs.addAll(['-b:v', '${requestedKbps}k']);
        } else {
          vArgs.addAll(['-q:v', '4']);
          if (capStr != null) {
            vArgs.addAll(['-maxrate', capStr, '-bufsize', bufStr!]);
          }
        }
        return VideoCodecConfig(
          containerFormat: 'avi',
          videoEncoderArgs: vArgs,
          audioEncoderArgs: buildAudioEncoderArgs(
            targetFormat: 'mp3',
            audioBitrate: audioBitrate,
            sourceSampleRate: audioSampleRate,
            sourceChannels: audioChannels,
          ),
          extraArgs: ['-pix_fmt', 'yuv420p'],
        );

      case 'wmv':
        final List<String> vArgs = [
          '-c:v', 'wmv2',
          '-g', gopStr,
          '-keyint_min', gopStr,
        ];
        if (requestedKbps != null) {
          vArgs.addAll(['-b:v', '${requestedKbps}k']);
        } else {
          vArgs.addAll(['-q:v', '4']);
          if (capStr != null) {
            vArgs.addAll(['-maxrate', capStr, '-bufsize', bufStr!]);
          }
        }
        return VideoCodecConfig(
          containerFormat: 'asf',
          videoEncoderArgs: vArgs,
          audioEncoderArgs: buildAudioEncoderArgs(
            targetFormat: 'wmv',
            audioBitrate: audioBitrate,
            sourceSampleRate: audioSampleRate,
            sourceChannels: audioChannels,
          ),
          extraArgs: ['-pix_fmt', 'yuv420p'],
        );

      case 'flv':
        final List<String> vArgs = [
          '-c:v', 'libx264',
          '-preset', 'ultrafast',
          if (isStaticImage) ...['-tune', 'stillimage'],
          '-threads', '0',
          '-g', gopStr,
          '-keyint_min', gopStr,
        ];
        if (requestedKbps != null) {
          vArgs.addAll(['-b:v', '${requestedKbps}k']);
        } else {
          vArgs.addAll(['-crf', '23']);
          if (capStr != null) {
            vArgs.addAll(['-maxrate', capStr, '-bufsize', bufStr!]);
          }
        }
        return VideoCodecConfig(
          containerFormat: 'flv',
          videoEncoderArgs: vArgs,
          audioEncoderArgs: buildAudioEncoderArgs(
            targetFormat: 'aac',
            audioBitrate: audioBitrate,
            sourceSampleRate: audioSampleRate,
            sourceChannels: audioChannels,
          ),
          extraArgs: ['-pix_fmt', 'yuv420p'],
        );

      case 'ogv':
        final List<String> vArgs = [
          '-c:v', 'libtheora',
          '-g', gopStr,
          '-keyint_min', gopStr,
        ];
        if (requestedKbps != null) {
          vArgs.addAll(['-b:v', '${requestedKbps}k']);
        } else {
          vArgs.addAll(['-q:v', '6']);
        }
        return VideoCodecConfig(
          containerFormat: 'ogg',
          videoEncoderArgs: vArgs,
          audioEncoderArgs: buildAudioEncoderArgs(
            targetFormat: 'ogg',
            audioBitrate: audioBitrate,
            sourceSampleRate: audioSampleRate,
            sourceChannels: audioChannels,
          ),
          extraArgs: ['-pix_fmt', 'yuv420p'],
        );

      case 'mpg':
      case 'mpeg':
        final List<String> vArgs = [
          '-c:v', 'mpeg2video',
          '-g', gopStr,
          '-keyint_min', gopStr,
        ];
        if (requestedKbps != null) {
          vArgs.addAll(['-b:v', '${requestedKbps}k']);
        } else {
          vArgs.addAll(['-q:v', '4']);
          if (capStr != null) {
            vArgs.addAll(['-maxrate', capStr, '-bufsize', bufStr!]);
          }
        }
        return VideoCodecConfig(
          containerFormat: 'mpeg',
          videoEncoderArgs: vArgs,
          audioEncoderArgs: buildAudioEncoderArgs(
            targetFormat: 'mpg',
            audioBitrate: audioBitrate,
            sourceSampleRate: audioSampleRate,
            sourceChannels: audioChannels,
          ),
          extraArgs: ['-pix_fmt', 'yuv420p'],
        );

      case 'mkv':
      case 'mov':
      case 'mp4':
      default:
        final List<String> vArgs = [];
        final bool isFastStartContainer = fmt == 'mp4' || fmt == 'mov' || fmt == 'm4v' || (fmt != 'mkv');
        final List<String> extras = [
          '-pix_fmt', 'yuv420p',
          if (isFastStartContainer) ...['-movflags', '+faststart'],
        ];

        if (useNvenc) {
          vArgs.addAll([
            '-c:v', 'h264_nvenc',
            '-preset', 'p1',
            '-tune', 'ull',
            '-g', gopStr,
            '-keyint_min', gopStr,
            '-forced-idr', '1',
          ]);
          if (requestedKbps != null) {
            vArgs.addAll(['-b:v', '${requestedKbps}k']);
          } else {
            vArgs.addAll([
              '-rc:v', 'vbr',
              '-cq:v', '23',
              '-b:v', '0',
            ]);
            if (capStr != null) {
              vArgs.addAll(['-maxrate:v', capStr, '-bufsize:v', bufStr!]);
            }
          }
        } else if (useQsv) {
          vArgs.addAll([
            '-c:v', 'h264_qsv',
            '-g', gopStr,
            '-keyint_min', gopStr,
          ]);
          if (requestedKbps != null) {
            vArgs.addAll(['-b:v', '${requestedKbps}k']);
          } else {
            vArgs.addAll([
              '-global_quality', '23',
            ]);
            if (capStr != null) {
              vArgs.addAll(['-maxrate:v', capStr, '-bufsize:v', bufStr!]);
            }
          }
        } else if (useVideoToolbox) {
          vArgs.addAll([
            '-c:v', 'h264_videotoolbox',
            '-g', gopStr,
            '-keyint_min', gopStr,
          ]);
          if (requestedKbps != null) {
            vArgs.addAll(['-b:v', '${requestedKbps}k']);
          } else {
            vArgs.addAll([
              '-q:v', '60',
              '-b:v', '0',
            ]);
            if (capStr != null) {
              vArgs.addAll(['-maxrate:v', capStr, '-bufsize:v', bufStr!]);
            }
          }
        } else if (useVaapi) {
          extras.addAll(['-vaapi_device', '/dev/dri/renderD128']);
          vArgs.addAll([
            '-vf', 'format=nv12,hwupload',
            '-c:v', 'h264_vaapi',
            '-g', gopStr,
            '-idr_interval', '1',
          ]);
          if (requestedKbps != null) {
            vArgs.addAll(['-b:v', '${requestedKbps}k']);
          } else {
            vArgs.addAll([
              '-rc_mode', 'CQP',
              '-qp', '23',
            ]);
            if (capStr != null) {
              vArgs.addAll(['-maxrate', capStr]);
            }
          }
        } else {
          vArgs.addAll([
            '-c:v', 'libx264',
            '-preset', 'ultrafast',
            if (isStaticImage) ...['-tune', 'stillimage'],
            '-threads', '0',
            '-g', gopStr,
            '-keyint_min', gopStr,
          ]);
          if (requestedKbps != null) {
            vArgs.addAll(['-b:v', '${requestedKbps}k']);
          } else {
            vArgs.addAll(['-crf', '23']);
            if (capStr != null) {
              vArgs.addAll(['-maxrate', capStr, '-bufsize', bufStr!]);
            }
          }
        }

        String container = fmt;
        if (fmt == 'mkv') container = 'matroska';

        return VideoCodecConfig(
          containerFormat: container,
          videoEncoderArgs: vArgs,
          audioEncoderArgs: buildAudioEncoderArgs(
            targetFormat: 'aac',
            audioBitrate: audioBitrate,
            sourceSampleRate: audioSampleRate,
            sourceChannels: audioChannels,
          ),
          extraArgs: extras,
        );
    }
  }

  /// Convert Audio -> Video (Cover-to-video)
  /// Works with any target video format (MP4, MKV, WebM, MOV, AVI, FLV, WMV)
  static Future<FFmpegResult> convertMp3ToVideo({
    required String audioPath,
    required String imagePath,
    required String outputPath,
    String targetFormat = 'mp4',
    String? resolution,
    String? videoBitrate,
    String? audioBitrate,
    String hardwareAcceleration = 'auto',
    String? title,
    String? artist,
    String? album,
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
    final audioInfo = await probeMedia(audioPath);

    // If resolution is not explicitly given, cap to source dimensions if available, otherwise default to 1920x1080
    final String finalRes;
    if (resolution == null || resolution == 'original' || resolution.isEmpty) {
      if (audioInfo.width != null && audioInfo.height != null) {
        final w = audioInfo.width!;
        final h = audioInfo.height!;
        final evenW = w.isEven ? w : w - 1;
        final evenH = h.isEven ? h : h - 1;
        finalRes = '${evenW}x$evenH';
      } else {
        finalRes = '1920x1080';
      }
    } else {
      finalRes = resolution;
    }

    String? explicitAudioBitrate;
    if (audioBitrate != null && audioBitrate != 'auto' && audioBitrate.isNotEmpty) {
      explicitAudioBitrate = audioBitrate;
    }

    final codecConfig = await getCodecConfigForFormat(
      targetFormat: targetFormat,
      videoBitrate: videoBitrate,
      audioBitrate: explicitAudioBitrate,
      audioSampleRate: audioInfo.audioSampleRate,
      audioChannels: audioInfo.audioChannels,
      hardwareAcceleration: hardwareAcceleration,
      isStaticImage: true,
      fps: 2.0,
      maxRateKbps: null,
    );

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      final desktopArgs = [
        '-y',
        '-threads', '0',
        '-loop', '1',
        '-framerate', '2', // Smart low framerate for static cover image: 1000x faster!
        '-i', imagePath,
        '-i', audioPath,
        '-map', '0:v:0',
        '-map', '1:a:0?',
        ...codecConfig.extraArgs,
        ...codecConfig.videoEncoderArgs,
        ...codecConfig.audioEncoderArgs,
        if (title != null && title.isNotEmpty) ...['-metadata', 'title=$title'],
        if (artist != null && artist.isNotEmpty) ...['-metadata', 'artist=$artist'],
        if (album != null && album.isNotEmpty) ...['-metadata', 'album=$album'],
        '-s', finalRes,
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
      final cmd = [
        '-y',
        '-threads', '0',
        '-loop', '1',
        '-framerate', '2',
        '-i', '"$imagePath"',
        '-i', '"$audioPath"',
        '-map', '0:v:0',
        '-map', '1:a:0?',
        ...codecConfig.extraArgs,
        ...codecConfig.videoEncoderArgs,
        ...codecConfig.audioEncoderArgs,
        if (title != null && title.isNotEmpty) '-metadata "title=$title"',
        if (artist != null && artist.isNotEmpty) '-metadata "artist=$artist"',
        if (album != null && album.isNotEmpty) '-metadata "album=$album"',
        '-s', finalRes,
        '-r', '2',
        '-shortest',
        '"$outputPath"',
      ].join(' ');

      return _runMobileConversion(
        command: cmd,
        totalDurationSeconds: durationSec,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    }
  }

  /// Backward-compatible alias for convertMp3ToVideo defaulting to 'mp4'
  static Future<FFmpegResult> convertMp3ToMp4({
    required String audioPath,
    required String imagePath,
    required String outputPath,
    String? resolution,
    String? videoBitrate,
    String? audioBitrate,
    String hardwareAcceleration = 'auto',
    void Function(double progress)? onProgress,
    Completer<void>? cancelCompleter,
  }) {
    return convertMp3ToVideo(
      audioPath: audioPath,
      imagePath: imagePath,
      outputPath: outputPath,
      targetFormat: 'mp4',
      resolution: resolution,
      videoBitrate: videoBitrate,
      audioBitrate: audioBitrate,
      hardwareAcceleration: hardwareAcceleration,
      onProgress: onProgress,
      cancelCompleter: cancelCompleter,
    );
  }

  /// Convert any input video (MP4, MKV, WebM, AVI, MOV, FLV, WMV) to any target video format
  static Future<FFmpegResult> convertVideoToVideo({
    required String videoPath,
    required String outputPath,
    required String targetFormat,
    String? resolution,
    String? videoBitrate,
    String? audioBitrate,
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

    final durationSec = await getMediaDuration(videoPath) ?? 180.0;
    final sourceInfo = await probeMedia(videoPath);

    // Never upscale resolution: encode at source's own resolution unless user explicitly picks a lower one
    String? scaleResolution;
    int? targetW;
    int? targetH;
    if (resolution != null && resolution != 'original' && resolution != 'auto' && resolution.isNotEmpty) {
      final parts = resolution.split('x');
      if (parts.length == 2) {
        final tw = int.tryParse(parts[0]);
        final th = int.tryParse(parts[1]);
        if (tw != null && th != null) {
          if (sourceInfo.width != null && sourceInfo.height != null) {
            if (tw >= sourceInfo.width! && th >= sourceInfo.height!) {
              // Target is equal or larger -> would be upscaling!
              scaleResolution = null;
            } else {
              scaleResolution = resolution;
              targetW = tw;
              targetH = th;
            }
          } else {
            scaleResolution = resolution;
            targetW = tw;
            targetH = th;
          }
        }
      }
    }

    final maxRateKbps = calculateBitrateCap(
      info: sourceInfo,
      targetWidth: targetW,
      targetHeight: targetH,
    );

    String? effectiveAudioBitrate;
    if (audioBitrate != null && audioBitrate != 'auto' && audioBitrate.isNotEmpty) {
      final reqKbps = int.tryParse(audioBitrate.replaceAll(RegExp(r'[^0-9]'), ''));
      if (reqKbps != null && sourceInfo.audioBitrateKbps != null && sourceInfo.audioBitrateKbps! > 0) {
        final capA = (sourceInfo.audioBitrateKbps! * 1.5).round().clamp(64, 320);
        if (reqKbps > capA) {
          effectiveAudioBitrate = '${capA}k';
        } else {
          effectiveAudioBitrate = audioBitrate;
        }
      } else {
        effectiveAudioBitrate = audioBitrate;
      }
    }

    final codecConfig = await getCodecConfigForFormat(
      targetFormat: targetFormat,
      videoBitrate: videoBitrate,
      audioBitrate: effectiveAudioBitrate,
      audioSampleRate: sourceInfo.audioSampleRate,
      audioChannels: sourceInfo.audioChannels,
      hardwareAcceleration: hardwareAcceleration,
      isStaticImage: false,
      fps: sourceInfo.fps,
      maxRateKbps: maxRateKbps,
    );

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      final desktopArgs = [
        '-y',
        '-threads', '0',
        '-i', videoPath,
        '-map', '0:v:0',
        '-map', '0:a?',
        ...codecConfig.extraArgs,
        ...codecConfig.videoEncoderArgs,
        ...codecConfig.audioEncoderArgs,
        if (scaleResolution != null) ...['-s', scaleResolution],
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
      final cmd = [
        '-y',
        '-threads', '0',
        '-i', '"$videoPath"',
        '-map', '0:v:0',
        '-map', '0:a?',
        ...codecConfig.extraArgs,
        ...codecConfig.videoEncoderArgs,
        ...codecConfig.audioEncoderArgs,
        if (scaleResolution != null) '-s $scaleResolution',
        '"$outputPath"',
      ].join(' ');

      return _runMobileConversion(
        command: cmd,
        totalDurationSeconds: durationSec,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    }
  }

  /// Merges multiple visual items (images and videos in sequence) with optional soundtrack audio clips
  static Future<FFmpegResult> mergeMedia({
    required List<MergeMediaItem> visualItems,
    List<MergeMediaItem> audioItems = const [],
    required String outputPath,
    String targetFormat = 'mp4',
    String? resolution,
    String? videoBitrate,
    String? audioBitrate,
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

    if (visualItems.isEmpty && audioItems.isEmpty) {
      return FFmpegResult(
        success: false,
        errorMessage: 'No media items provided for merge.',
      );
    }

    // Try with requested hardware acceleration, falling back to CPU if it fails
    final res = await _executeMergeMedia(
      visualItems: visualItems,
      audioItems: audioItems,
      outputPath: outputPath,
      targetFormat: targetFormat,
      resolution: resolution,
      videoBitrate: videoBitrate,
      audioBitrate: audioBitrate,
      hardwareAcceleration: hardwareAcceleration,
      onProgress: onProgress,
      cancelCompleter: cancelCompleter,
    );

    if (!res.success &&
        hardwareAcceleration != 'cpu' &&
        (cancelCompleter == null || !cancelCompleter.isCompleted)) {
      return await _executeMergeMedia(
        visualItems: visualItems,
        audioItems: audioItems,
        outputPath: outputPath,
        targetFormat: targetFormat,
        resolution: resolution,
        videoBitrate: videoBitrate,
        audioBitrate: audioBitrate,
        hardwareAcceleration: 'cpu',
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    }

    return res;
  }

  static Future<FFmpegResult> _executeMergeMedia({
    required List<MergeMediaItem> visualItems,
    required List<MergeMediaItem> audioItems,
    required String outputPath,
    required String targetFormat,
    String? resolution,
    String? videoBitrate,
    String? audioBitrate,
    required String hardwareAcceleration,
    void Function(double progress)? onProgress,
    Completer<void>? cancelCompleter,
  }) async {
    final cleanFormat = targetFormat.toLowerCase().replaceAll('.', '');
    final isAudioOutput = ConversionItem.supportedAudioOutputFormats.contains(cleanFormat);

    // 1. Audio-only output format (e.g. mp3, aac, wav, flac, ogg, opus)
    if (isAudioOutput) {
      final audioSources = <MergeMediaItem>[];
      if (audioItems.isNotEmpty) {
        audioSources.addAll(audioItems);
      } else if (visualItems.isNotEmpty) {
        for (final item in visualItems) {
          if (item.isVideo) {
            final info = await probeMedia(item.path);
            if (info.audioChannels != null && info.audioChannels! > 0) {
              audioSources.add(item);
            }
          }
        }
      }

      if (audioSources.isEmpty) {
        return FFmpegResult(
          success: false,
          errorMessage: 'No audio streams found in timeline to export.',
        );
      }

      final nSources = audioSources.length;
      final filterParts = <String>[];
      for (int j = 0; j < nSources; j++) {
        filterParts.add('[$j:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[a$j]');
      }
      final audioConcatStreams = List.generate(nSources, (j) => '[a$j]').join('');
      filterParts.add('${audioConcatStreams}concat=n=$nSources:v=0:a=1[aout]');
      final filterComplex = filterParts.join(';');

      final audioEncoderArgs = buildAudioEncoderArgs(
        targetFormat: cleanFormat,
        audioBitrate: audioBitrate,
      );

      final totalDuration = audioSources.fold<double>(
        0.0,
        (acc, item) => acc + item.durationInSeconds,
      );

      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final List<String> inputs = [];
        for (final item in audioSources) {
          inputs.addAll(['-i', item.path]);
        }
        final desktopArgs = [
          '-y',
          '-threads', '0',
          ...inputs,
          '-filter_complex', filterComplex,
          '-map', '[aout]',
          ...audioEncoderArgs,
          outputPath,
        ];
        return _runDesktopConversion(
          args: desktopArgs,
          totalDurationSeconds: totalDuration,
          outputPath: outputPath,
          onProgress: onProgress,
          cancelCompleter: cancelCompleter,
        );
      } else {
        final mobileInputs = <String>[];
        for (final item in audioSources) {
          mobileInputs.add('-i "${item.path}"');
        }
        final cmd = [
          '-y',
          '-threads 0',
          ...mobileInputs,
          '-filter_complex "$filterComplex"',
          '-map "[aout]"',
          ...audioEncoderArgs,
          '"$outputPath"',
        ].join(' ');
        return _runMobileConversion(
          command: cmd,
          totalDurationSeconds: totalDuration,
          outputPath: outputPath,
          onProgress: onProgress,
          cancelCompleter: cancelCompleter,
        );
      }
    }

    // 2. Video output format (mp4, mkv, mov, webm, avi, flv, wmv, mpg, mpeg, ogv)
    int targetW = 1920;
    int targetH = 1080;
    if (resolution != null && resolution.contains('x')) {
      final parts = resolution.split('x');
      final w = int.tryParse(parts[0]);
      final h = int.tryParse(parts[1]);
      if (w != null && h != null && w > 0 && h > 0) {
        targetW = w;
        targetH = h;
      }
    }

    final codecConfig = await getCodecConfigForFormat(
      targetFormat: cleanFormat,
      videoBitrate: videoBitrate,
      audioBitrate: audioBitrate,
      hardwareAcceleration: hardwareAcceleration,
      isStaticImage: false,
      fps: 30.0,
    );

    // 2A. Audio-only project exported to video format (render black visual canvas)
    if (visualItems.isEmpty && audioItems.isNotEmpty) {
      final totalAudioDuration = audioItems.fold<double>(
        0.0,
        (acc, item) => acc + item.durationInSeconds,
      );
      final nAudio = audioItems.length;
      final filterParts = <String>[];
      filterParts.add('color=c=black:s=${targetW}x$targetH:d=${totalAudioDuration.toStringAsFixed(3)}:r=30[vout]');
      for (int j = 0; j < nAudio; j++) {
        filterParts.add('[$j:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[a$j]');
      }
      final audioConcatStreams = List.generate(nAudio, (j) => '[a$j]').join('');
      filterParts.add('${audioConcatStreams}concat=n=$nAudio:v=0:a=1[aout]');
      final filterComplex = filterParts.join(';');

      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        final List<String> inputs = [];
        for (final item in audioItems) {
          inputs.addAll(['-i', item.path]);
        }
        final desktopArgs = [
          '-y',
          '-threads', '0',
          ...inputs,
          '-filter_complex', filterComplex,
          '-map', '[vout]',
          '-map', '[aout]',
          ...codecConfig.extraArgs,
          ...codecConfig.videoEncoderArgs,
          ...codecConfig.audioEncoderArgs,
          '-shortest',
          outputPath,
        ];
        return _runDesktopConversion(
          args: desktopArgs,
          totalDurationSeconds: totalAudioDuration,
          outputPath: outputPath,
          onProgress: onProgress,
          cancelCompleter: cancelCompleter,
        );
      } else {
        final mobileInputs = <String>[];
        for (final item in audioItems) {
          mobileInputs.add('-i "${item.path}"');
        }
        final cmd = [
          '-y',
          '-threads 0',
          ...mobileInputs,
          '-filter_complex "$filterComplex"',
          '-map "[vout]"',
          '-map "[aout]"',
          ...codecConfig.extraArgs,
          ...codecConfig.videoEncoderArgs,
          ...codecConfig.audioEncoderArgs,
          '-shortest',
          '"$outputPath"',
        ].join(' ');
        return _runMobileConversion(
          command: cmd,
          totalDurationSeconds: totalAudioDuration,
          outputPath: outputPath,
          onProgress: onProgress,
          cancelCompleter: cancelCompleter,
        );
      }
    }

    // 2B. Visual items are present (videos, images, or both)
    final totalVisualDuration = visualItems.fold<double>(
      0.0,
      (acc, item) => acc + item.durationInSeconds,
    );

    final nVisual = visualItems.length;
    final nAudio = audioItems.length;

    final filterParts = <String>[];
    for (int i = 0; i < nVisual; i++) {
      filterParts.add('[$i:v]scale=$targetW:$targetH:force_original_aspect_ratio=decrease,pad=$targetW:$targetH:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p[v$i]');
    }

    final visualConcatStreams = List.generate(nVisual, (i) => '[v$i]').join('');
    filterParts.add('${visualConcatStreams}concat=n=$nVisual:v=1:a=0[vout]');

    if (nAudio > 0) {
      for (int j = 0; j < nAudio; j++) {
        final idx = nVisual + j;
        filterParts.add('[$idx:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[a$j]');
      }
      final audioConcatStreams = List.generate(nAudio, (j) => '[a$j]').join('');
      filterParts.add('${audioConcatStreams}concat=n=$nAudio:v=0:a=1,apad[aout]');
    } else {
      // Check if visual items have audio streams (e.g. video files without separate audio track)
      final hasAnyVideoWithAudio = <int, bool>{};
      for (int i = 0; i < nVisual; i++) {
        if (visualItems[i].isVideo) {
          final info = await probeMedia(visualItems[i].path);
          if (info.audioChannels != null && info.audioChannels! > 0) {
            hasAnyVideoWithAudio[i] = true;
          }
        }
      }

      if (hasAnyVideoWithAudio.isNotEmpty) {
        for (int i = 0; i < nVisual; i++) {
          if (hasAnyVideoWithAudio[i] == true) {
            filterParts.add('[$i:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[va$i]');
          } else {
            filterParts.add('anullsrc=r=44100:cl=stereo:d=${visualItems[i].durationInSeconds.toStringAsFixed(3)}[va$i]');
          }
        }
        final vAudioConcatStreams = List.generate(nVisual, (i) => '[va$i]').join('');
        filterParts.add('${vAudioConcatStreams}concat=n=$nVisual:v=0:a=1[aout]');
      } else {
        filterParts.add('anullsrc=r=44100:cl=stereo:d=${totalVisualDuration.toStringAsFixed(3)}[aout]');
      }
    }

    final filterComplex = filterParts.join(';');

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      final List<String> inputs = [];
      for (final item in visualItems) {
        if (item.isImage) {
          inputs.addAll([
            '-loop', '1',
            '-t', item.durationInSeconds.toStringAsFixed(3),
            '-i', item.path,
          ]);
        } else {
          inputs.addAll([
            '-i', item.path,
          ]);
        }
      }
      for (final item in audioItems) {
        inputs.addAll([
          '-i', item.path,
        ]);
      }

      final desktopArgs = [
        '-y',
        '-threads', '0',
        ...inputs,
        '-filter_complex', filterComplex,
        '-map', '[vout]',
        '-map', '[aout]',
        ...codecConfig.extraArgs,
        ...codecConfig.videoEncoderArgs,
        ...codecConfig.audioEncoderArgs,
        '-shortest',
        outputPath,
      ];

      return _runDesktopConversion(
        args: desktopArgs,
        totalDurationSeconds: totalVisualDuration,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    } else {
      final mobileInputs = <String>[];
      for (final item in visualItems) {
        if (item.isImage) {
          mobileInputs.add('-loop 1 -t ${item.durationInSeconds.toStringAsFixed(3)} -i "${item.path}"');
        } else {
          mobileInputs.add('-i "${item.path}"');
        }
      }
      for (final item in audioItems) {
        mobileInputs.add('-i "${item.path}"');
      }

      final cmd = [
        '-y',
        '-threads 0',
        ...mobileInputs,
        '-filter_complex "$filterComplex"',
        '-map "[vout]"',
        '-map "[aout]"',
        ...codecConfig.extraArgs,
        ...codecConfig.videoEncoderArgs,
        ...codecConfig.audioEncoderArgs,
        '-shortest',
        '"$outputPath"',
      ].join(' ');

      return _runMobileConversion(
        command: cmd,
        totalDurationSeconds: totalVisualDuration,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    }
  }

  /// Convert any input video (MP4, MKV, WebM, AVI, MOV, FLV, WMV, MPG, MPEG, OGV, etc.) to target audio format (MP3, AAC, WAV, FLAC, OGG, OPUS)
  static Future<FFmpegResult> convertVideoToAudio({
    required String videoPath,
    required String outputPath,
    String targetFormat = 'mp3',
    String? audioBitrate,
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
    final sourceInfo = await probeMedia(videoPath);
    final fmt = targetFormat.toLowerCase().replaceAll('.', '');

    String? explicitAudioBitrate;
    if (audioBitrate != null && audioBitrate != 'auto' && audioBitrate.isNotEmpty) {
      final reqKbps = int.tryParse(audioBitrate.replaceAll(RegExp(r'[^0-9]'), ''));
      if (reqKbps != null && sourceInfo.audioBitrateKbps != null && sourceInfo.audioBitrateKbps! > 0) {
        final capA = (sourceInfo.audioBitrateKbps! * 1.5).round().clamp(64, 320);
        if (reqKbps > capA) {
          explicitAudioBitrate = '${capA}k';
        } else {
          explicitAudioBitrate = audioBitrate;
        }
      } else {
        explicitAudioBitrate = audioBitrate;
      }
    }

    final audioEncoderArgs = buildAudioEncoderArgs(
      targetFormat: fmt,
      audioBitrate: explicitAudioBitrate,
      sourceSampleRate: sourceInfo.audioSampleRate,
      sourceChannels: sourceInfo.audioChannels,
    );

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      bool isAudioAlreadyMatching = false;
      try {
        final probe = await Process.run('ffprobe', [
          '-v', 'error',
          '-select_streams', 'a:0',
          '-show_entries', 'stream=codec_name',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          videoPath,
        ]);
        final streamCodec = probe.stdout.toString().trim().toLowerCase();
        if (probe.exitCode == 0 &&
            (streamCodec == fmt ||
                (fmt == 'ogg' && streamCodec == 'vorbis') ||
                (fmt == 'wav' && streamCodec.startsWith('pcm')))) {
          isAudioAlreadyMatching = true;
        }
      } catch (_) {}

      final List<String> args = [
        '-y',
        '-threads', '0',
        '-i', videoPath,
        '-vn',
        '-map', '0:a:0?',
      ];

      if (isAudioAlreadyMatching) {
        args.addAll(['-c:a', 'copy']);
      } else {
        args.addAll(audioEncoderArgs);
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
      final encoderFlags = audioEncoderArgs.join(' ');
      return _runMobileConversion(
        command:
            '-y -threads 0 -i "$videoPath" -vn -map 0:a:0? $encoderFlags "$outputPath"',
        totalDurationSeconds: durationSec,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelCompleter: cancelCompleter,
      );
    }
  }

  /// Backward-compatible alias for convertVideoToAudio targeting MP3
  static Future<FFmpegResult> convertVideoToMp3({
    required String videoPath,
    required String outputPath,
    String? audioBitrate,
    void Function(double progress)? onProgress,
    Completer<void>? cancelCompleter,
  }) {
    return convertVideoToAudio(
      videoPath: videoPath,
      outputPath: outputPath,
      targetFormat: 'mp3',
      audioBitrate: audioBitrate,
      onProgress: onProgress,
      cancelCompleter: cancelCompleter,
    );
  }

  /// Backward-compatible alias for convertVideoToMp3
  static Future<FFmpegResult> convertMp4ToMp3({
    required String videoPath,
    required String outputPath,
    String? audioBitrate,
    void Function(double progress)? onProgress,
    Completer<void>? cancelCompleter,
  }) {
    return convertVideoToMp3(
      videoPath: videoPath,
      outputPath: outputPath,
      audioBitrate: audioBitrate,
      onProgress: onProgress,
      cancelCompleter: cancelCompleter,
    );
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
        String? inputPath;
        for (int i = 0; i < args.length - 1; i++) {
          if (args[i] == '-i') {
            final p = args[i + 1];
            if (p.toLowerCase().endsWith('.rm') || p.toLowerCase().endsWith('.ram')) {
              inputPath = p;
              break;
            }
            inputPath ??= p;
          }
        }
        final errorMsg = parseFfmpegErrorMessage(
          stderrBuffer.toString(),
          inputPath: inputPath,
          exitCode: exitCode,
        );
        return FFmpegResult(
          success: false,
          errorMessage: errorMsg,
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
            final allLogs = await completedSession.getAllLogsAsString();
            String? inputPath;
            final matches = RegExp(r'-i\s+["\x27]?([^"\x27]+)["\x27]?').allMatches(command);
            for (final m in matches) {
              final p = m.group(1);
              if (p != null && (p.toLowerCase().endsWith('.rm') || p.toLowerCase().endsWith('.ram'))) {
                inputPath = p;
                break;
              }
              inputPath ??= p;
            }
            final errorMsg = parseFfmpegErrorMessage(
              allLogs ?? failLogs ?? 'Mobile FFmpeg session failed',
              inputPath: inputPath,
              exitCode: returnCode?.getValue(),
            );
            if (!sessionCompleter.isCompleted) {
              sessionCompleter.complete(
                FFmpegResult(
                  success: false,
                  errorMessage: errorMsg,
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

  /// Extracts clean and descriptive error messages from FFmpeg stderr logs,
  /// specifically providing helpful per-file details when RealMedia codecs fail to decode.
  static String parseFfmpegErrorMessage(
    String stderr, {
    String? inputPath,
    int? exitCode,
  }) {
    final isRealMedia = inputPath != null &&
        (inputPath.toLowerCase().endsWith('.rm') ||
         inputPath.toLowerCase().endsWith('.ram'));

    final lines = stderr
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .where((l) =>
            !l.startsWith('ffmpeg version') &&
            !l.startsWith('built with') &&
            !l.startsWith('configuration:') &&
            !l.startsWith('libavutil') &&
            !l.startsWith('libavcodec') &&
            !l.startsWith('libavformat') &&
            !l.startsWith('libavdevice') &&
            !l.startsWith('libavfilter') &&
            !l.startsWith('libswscale') &&
            !l.startsWith('libswresample') &&
            !l.startsWith('Press [q] to stop') &&
            !l.startsWith('Last message repeated'))
        .toList();

    final errorKeywords = [
      'Error',
      'error',
      'Invalid data',
      'Decoder not found',
      'could not find codec',
      'Could not find codec',
      'Unsupported codec',
      'unsupported',
      'matches no streams',
      'Conversion failed',
      'failed',
      'Invalid argument',
    ];

    final errorLines = lines.where((l) => errorKeywords.any((kw) => l.contains(kw))).toList();

    String detailedReason = '';
    if (errorLines.isNotEmpty) {
      final cleanLines = errorLines
          .map((l) => l.replaceFirst(RegExp(r'^\[.*?\]\s*'), '').trim())
          .where((l) => l.isNotEmpty)
          .toList();
      detailedReason = cleanLines.isNotEmpty ? cleanLines.last : '';
    } else if (lines.isNotEmpty) {
      detailedReason = lines.last.replaceFirst(RegExp(r'^\[.*?\]\s*'), '').trim();
    }

    if (isRealMedia) {
      if (detailedReason.isNotEmpty) {
        return 'RealMedia decoding failed: $detailedReason';
      }
      return 'RealMedia decoding failed: Unsupported or corrupted RealMedia codec (exit code ${exitCode ?? 1})';
    }

    if (detailedReason.isNotEmpty) {
      return detailedReason;
    }
    return 'FFmpeg failed${exitCode != null ? ' (exit code $exitCode)' : ''}';
  }
}
