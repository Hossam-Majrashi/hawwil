import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hawwil/models/conversion_item.dart';
import 'package:hawwil/models/conversion_settings.dart';
import 'package:hawwil/services/batch_conversion_service.dart';
import 'package:hawwil/services/ffmpeg_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Flexible Video Formats Model & Batch Tests', () {
    test('ConversionItem format and type detection', () {
      final mkvItem = ConversionItem(
        id: '1',
        sourcePath: '/path/to/movie.mkv',
        fileName: 'movie.mkv',
      );
      expect(mkvItem.isVideoInput, isTrue);
      expect(mkvItem.isAudioInput, isFalse);
      expect(mkvItem.fileExtension, equals('mkv'));
      expect(mkvItem.targetFormat, equals('mp4')); // Default for non-MP4 video is MP4
      expect(mkvItem.direction, equals(ConversionDirection.videoToVideo));

      final webmItem = ConversionItem(
        id: '2',
        sourcePath: '/path/to/clip.webm',
        fileName: 'clip.webm',
      );
      expect(webmItem.isVideoInput, isTrue);
      expect(webmItem.fileExtension, equals('webm'));
      expect(webmItem.targetFormat, equals('mp4'));

      final mp4Item = ConversionItem(
        id: '3',
        sourcePath: '/path/to/video.mp4',
        fileName: 'video.mp4',
      );
      expect(mp4Item.isVideoInput, isTrue);
      expect(mp4Item.fileExtension, equals('mp4'));
      expect(mp4Item.targetFormat, equals('mp3')); // Default for MP4 video is MP3 audio extraction
      expect(mp4Item.direction, equals(ConversionDirection.mp4ToMp3));

      final mp3Item = ConversionItem(
        id: '4',
        sourcePath: '/path/to/audio.mp3',
        fileName: 'audio.mp3',
      );
      expect(mp3Item.isAudioInput, isTrue);
      expect(mp3Item.isVideoInput, isFalse);
      expect(mp3Item.fileExtension, equals('mp3'));
      expect(mp3Item.targetFormat, equals('mp4'));
      expect(mp3Item.direction, equals(ConversionDirection.mp3ToMp4));
    });

    test('RealMedia (RM / RAM) input format support and input-only constraints', () {
      // 1. Verify extensions are recognized as accepted inputs
      expect(ConversionItem.allAllowedInputExtensions, contains('rm'));
      expect(ConversionItem.allAllowedInputExtensions, contains('ram'));
      expect(ConversionItem.supportedInputVideoExtensions, contains('rm'));
      expect(ConversionItem.supportedInputVideoExtensions, contains('ram'));

      // 2. Verify RealMedia is NEVER offered as an output choice
      expect(ConversionItem.supportedVideoFormats, isNot(contains('rm')));
      expect(ConversionItem.supportedVideoFormats, isNot(contains('ram')));
      expect(ConversionSettings.availableVideoFormats, isNot(contains('rm')));
      expect(ConversionSettings.availableVideoFormats, isNot(contains('ram')));
      expect(ConversionSettings.allOutputFormatsForVideos, isNot(contains('rm')));
      expect(ConversionSettings.allOutputFormatsForVideos, isNot(contains('ram')));

      // 3. RM Item instantiation
      final rmItem = ConversionItem(
        id: 'rm_1',
        sourcePath: '/path/to/media.rm',
        fileName: 'media.rm',
      );
      expect(rmItem.isRealMedia, isTrue);
      expect(rmItem.isVideoInput, isTrue);
      expect(rmItem.isAudioInput, isFalse);
      expect(rmItem.fileExtension, equals('rm'));
      expect(rmItem.targetFormat, equals('mp4')); // Default for non-MP4 input is MP4
      expect(rmItem.direction, equals(ConversionDirection.videoToVideo));

      // 4. RAM Item instantiation
      final ramItem = ConversionItem(
        id: 'ram_1',
        sourcePath: '/path/to/audio.ram',
        fileName: 'audio.ram',
      );
      expect(ramItem.isRealMedia, isTrue);
      expect(ramItem.isVideoInput, isTrue);
      expect(ramItem.isAudioInput, isFalse);
      expect(ramItem.fileExtension, equals('ram'));
      expect(ramItem.targetFormat, equals('mp4'));

      // 5. Batch service support for RM and RAM
      final batch = BatchConversionService();
      batch.addFiles(['/path/classic.rm', '/path/stream.ram']);
      expect(batch.items.length, equals(2));
      final item0 = batch.items[0];
      final item1 = batch.items[1];

      // Convert to MP3
      batch.setTargetFormat(item0, 'mp3');
      expect(item0.targetFormat, equals('mp3'));
      expect(item0.isTargetAudio, isTrue);
      expect(item0.direction, equals(ConversionDirection.mp4ToMp3));

      // Convert to other existing output targets (MKV, WebM, AVI, etc.)
      for (final fmt in ['mkv', 'mov', 'webm', 'avi', 'flv', 'wmv']) {
        batch.setTargetFormat(item1, fmt);
        expect(item1.targetFormat, equals(fmt));
      }
    });

    test('BatchConversionService allows changing format per item and for entire batch', () {
      final batch = BatchConversionService();
      batch.addFiles([
        '/path/video1.mkv',
        '/path/video2.webm',
        '/path/audio1.mp3',
      ]);

      expect(batch.items.length, equals(3));
      final mkv = batch.items[0];
      final webm = batch.items[1];
      final mp3 = batch.items[2];

      expect(mkv.targetFormat, equals('mp4'));
      expect(webm.targetFormat, equals('mp4'));
      expect(mp3.targetFormat, equals('mp4'));

      // Change per item
      batch.setTargetFormat(mkv, 'webm');
      expect(mkv.targetFormat, equals('webm'));
      expect(mkv.direction, equals(ConversionDirection.videoToVideo));

      batch.setTargetFormat(webm, 'mp3');
      expect(webm.targetFormat, equals('mp3'));
      expect(webm.isTargetAudio, isTrue);
      expect(webm.direction, equals(ConversionDirection.mp4ToMp3));

      // Batch change all video files to 'avi'
      batch.setBatchTargetFormat('avi');
      expect(mkv.targetFormat, equals('avi'));
      expect(webm.targetFormat, equals('avi'));
      expect(mp3.targetFormat, equals('mp4')); // Audio input untouched
    });

    test('FFmpegService getCodecConfigForFormat produces sensible codecs', () async {
      final webmConfig = await FFmpegService.getCodecConfigForFormat(
        targetFormat: 'webm',
        videoBitrate: '2000k',
        audioBitrate: '192k',
        hardwareAcceleration: 'cpu_ultrafast',
      );
      expect(webmConfig.containerFormat, equals('webm'));
      expect(webmConfig.videoEncoderArgs, contains('libvpx-vp9'));
      expect(webmConfig.audioEncoderArgs, contains('libopus'));

      final aviConfig = await FFmpegService.getCodecConfigForFormat(
        targetFormat: 'avi',
        videoBitrate: '2000k',
        audioBitrate: '192k',
        hardwareAcceleration: 'cpu_ultrafast',
      );
      expect(aviConfig.containerFormat, equals('avi'));
      expect(aviConfig.videoEncoderArgs, contains('mpeg4'));
      expect(aviConfig.audioEncoderArgs, contains('libmp3lame'));

      final wmvConfig = await FFmpegService.getCodecConfigForFormat(
        targetFormat: 'wmv',
        videoBitrate: '2000k',
        audioBitrate: '192k',
        hardwareAcceleration: 'cpu_ultrafast',
      );
      expect(wmvConfig.containerFormat, equals('asf'));
      expect(wmvConfig.videoEncoderArgs, contains('wmv2'));
      expect(wmvConfig.audioEncoderArgs, contains('wmav2'));

      final mp4Config = await FFmpegService.getCodecConfigForFormat(
        targetFormat: 'mp4',
        videoBitrate: '2000k',
        audioBitrate: '192k',
        hardwareAcceleration: 'cpu_ultrafast',
      );
      expect(mp4Config.containerFormat, equals('mp4'));
      expect(mp4Config.videoEncoderArgs, contains('libx264'));
      expect(mp4Config.audioEncoderArgs, contains('aac'));

      final ogvConfig = await FFmpegService.getCodecConfigForFormat(
        targetFormat: 'ogv',
        videoBitrate: '2000k',
        audioBitrate: '192k',
        hardwareAcceleration: 'cpu_ultrafast',
      );
      expect(ogvConfig.containerFormat, equals('ogg'));
      expect(ogvConfig.videoEncoderArgs, contains('libtheora'));
      expect(ogvConfig.audioEncoderArgs, contains('libvorbis'));

      final mpegConfig = await FFmpegService.getCodecConfigForFormat(
        targetFormat: 'mpeg',
        videoBitrate: '2000k',
        audioBitrate: '192k',
        hardwareAcceleration: 'cpu_ultrafast',
      );
      expect(mpegConfig.containerFormat, equals('mpeg'));
      expect(mpegConfig.videoEncoderArgs, contains('mpeg2video'));
      expect(mpegConfig.audioEncoderArgs, contains('mp2'));
    });

    test('New video and audio format support in ConversionItem', () {
      // 1. supportedVideoFormats: mpg, mpeg, ogv
      for (final ext in ['mpg', 'mpeg', 'ogv']) {
        expect(ConversionItem.supportedVideoFormats, contains(ext));
      }

      // 2. supportedInputVideoExtensions: mpg, mpeg, vob, ogv, mts, m2ts, asf
      for (final ext in ['mpg', 'mpeg', 'vob', 'ogv', 'mts', 'm2ts', 'asf']) {
        expect(ConversionItem.supportedInputVideoExtensions, contains(ext));
      }

      // 3. supportedInputAudioExtensions: opus, aiff, aif, amr, ac3
      for (final ext in ['opus', 'aiff', 'aif', 'amr', 'ac3']) {
        expect(ConversionItem.supportedInputAudioExtensions, contains(ext));
      }

      // 4. allAllowedInputExtensions: contains every extension listed above
      for (final ext in [
        'mpg', 'mpeg', 'vob', 'ogv', 'mts', 'm2ts', 'asf',
        'opus', 'aiff', 'aif', 'amr', 'ac3',
      ]) {
        expect(ConversionItem.allAllowedInputExtensions, contains(ext));
      }

      // 5. supportedAudioOutputFormats: mp3, aac, wav, flac, ogg, opus
      expect(
        ConversionItem.supportedAudioOutputFormats,
        equals(['mp3', 'aac', 'wav', 'flac', 'ogg', 'opus']),
      );

      // 6. Test item target format for audio outputs
      final videoItem = ConversionItem(
        id: 'v1',
        sourcePath: '/path/video.mp4',
        fileName: 'video.mp4',
      );
      for (final audioFmt in ConversionItem.supportedAudioOutputFormats) {
        videoItem.targetFormat = audioFmt;
        expect(videoItem.isTargetAudio, isTrue);
        expect(videoItem.isTargetVideo, isFalse);
        expect(videoItem.direction, equals(ConversionDirection.mp4ToMp3));
      }

      // 7. Test item input detection for new audio formats
      for (final audioExt in ['opus', 'aiff', 'aif', 'amr', 'ac3']) {
        final item = ConversionItem(
          id: 'a_$audioExt',
          sourcePath: '/path/song.$audioExt',
          fileName: 'song.$audioExt',
        );
        expect(item.isAudioInput, isTrue);
        expect(item.isVideoInput, isFalse);
        expect(item.targetFormat, equals('mp4'));
      }

      // 8. Test item input detection for new video formats
      for (final vidExt in ['mpg', 'mpeg', 'vob', 'ogv', 'mts', 'm2ts', 'asf']) {
        final item = ConversionItem(
          id: 'v_$vidExt',
          sourcePath: '/path/movie.$vidExt',
          fileName: 'movie.$vidExt',
        );
        expect(item.isVideoInput, isTrue);
        expect(item.isAudioInput, isFalse);
      }
    });
  });

  group('End-to-End Transcoding Verification via FFmpeg', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hawwil_e2e_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Non-MP4 (MKV) input converting to WebM video and MP3 audio', () async {
      final isFfmpegAvailable = await FFmpegService.checkDesktopFFmpeg();
      if (!isFfmpegAvailable) return;

      // 1. Create a synthetic MKV input file
      final mkvInputPath = '${tempDir.path}/test_source.mkv';
      final createMkv = await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'testsrc=size=320x240:rate=25',
        '-f', 'lavfi', '-i', 'sine=frequency=1000:duration=1',
        '-t', '1',
        '-c:v', 'libx264', '-preset', 'ultrafast',
        '-c:a', 'aac',
        mkvInputPath,
      ]);
      expect(createMkv.exitCode, equals(0));
      expect(await File(mkvInputPath).exists(), isTrue);

      // 2. Convert MKV -> WebM (Video to Video)
      final webmOutputPath = '${tempDir.path}/output_transcoded.webm';
      final webmRes = await FFmpegService.convertVideoToVideo(
        videoPath: mkvInputPath,
        outputPath: webmOutputPath,
        targetFormat: 'webm',
        videoBitrate: '1000k',
        audioBitrate: '128k',
        hardwareAcceleration: 'cpu_ultrafast',
      );
      expect(webmRes.success, isTrue);
      expect(await File(webmOutputPath).exists(), isTrue);

      // Verify WebM output codecs using ffprobe
      final webmProbe = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'stream=codec_name',
        '-of', 'json',
        webmOutputPath,
      ]);
      expect(webmProbe.exitCode, equals(0));
      final webmJson = jsonDecode(webmProbe.stdout.toString());
      final streams = (webmJson['streams'] as List).map((s) => s['codec_name'] as String).toList();
      expect(streams, contains('vp9'));
      expect(streams, contains('opus'));

      // 3. Convert MKV -> MP3 (Video to Audio)
      final mp3OutputPath = '${tempDir.path}/output_extracted.mp3';
      final mp3Res = await FFmpegService.convertVideoToMp3(
        videoPath: mkvInputPath,
        outputPath: mp3OutputPath,
        audioBitrate: '192k',
      );
      expect(mp3Res.success, isTrue);
      expect(await File(mp3OutputPath).exists(), isTrue);

      // Verify MP3 output codecs using ffprobe
      final mp3Probe = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'stream=codec_name',
        '-of', 'json',
        mp3OutputPath,
      ]);
      expect(mp3Probe.exitCode, equals(0));
      final mp3Json = jsonDecode(mp3Probe.stdout.toString());
      final mp3Streams = (mp3Json['streams'] as List).map((s) => s['codec_name'] as String).toList();
      expect(mp3Streams, contains('mp3'));
    });

    test('Non-MP4 (WebM) input converting to MP4 video', () async {
      final isFfmpegAvailable = await FFmpegService.checkDesktopFFmpeg();
      if (!isFfmpegAvailable) return;

      // 1. Create a synthetic WebM input file
      final webmInputPath = '${tempDir.path}/test_source.webm';
      final createWebm = await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'testsrc=size=320x240:rate=25',
        '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1',
        '-t', '1',
        '-c:v', 'libvpx-vp9', '-b:v', '1000k', '-deadline', 'realtime', '-cpu-used', '8',
        '-c:a', 'libopus',
        webmInputPath,
      ]);
      expect(createWebm.exitCode, equals(0));
      expect(await File(webmInputPath).exists(), isTrue);

      // 2. Convert WebM -> MP4 (Video to Video)
      final mp4OutputPath = '${tempDir.path}/output_transcoded.mp4';
      final mp4Res = await FFmpegService.convertVideoToVideo(
        videoPath: webmInputPath,
        outputPath: mp4OutputPath,
        targetFormat: 'mp4',
        videoBitrate: '2000k',
        audioBitrate: '192k',
        hardwareAcceleration: 'cpu_ultrafast',
      );
      expect(mp4Res.success, isTrue);
      expect(await File(mp4OutputPath).exists(), isTrue);

      // Verify MP4 output codecs using ffprobe
      final mp4Probe = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'stream=codec_name',
        '-of', 'json',
        mp4OutputPath,
      ]);
      expect(mp4Probe.exitCode, equals(0));
      final mp4Json = jsonDecode(mp4Probe.stdout.toString());
      final streams = (mp4Json['streams'] as List).map((s) => s['codec_name'] as String).toList();
      expect(streams, contains('h264'));
      expect(streams, contains('aac'));
    });

    test('RealMedia (RM) conversion to MP4 and MP3 with FFmpeg', () async {
      final isFfmpegAvailable = await FFmpegService.checkDesktopFFmpeg();
      if (!isFfmpegAvailable) return;

      // 1. Create a synthetic RM input file (using rv20 video + ac3 audio)
      final rmInputPath = '${tempDir.path}/test_source.rm';
      final createRm = await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'testsrc=duration=1:size=320x240:rate=10',
        '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=mono',
        '-t', '1',
        '-c:v', 'rv20',
        '-c:a', 'ac3',
        rmInputPath,
      ]);
      expect(createRm.exitCode, equals(0));
      expect(await File(rmInputPath).exists(), isTrue);

      // 2. Convert RM -> MP4
      final mp4OutPath = '${tempDir.path}/rm_converted.mp4';
      final mp4Res = await FFmpegService.convertVideoToVideo(
        videoPath: rmInputPath,
        outputPath: mp4OutPath,
        targetFormat: 'mp4',
        videoBitrate: '1500k',
        audioBitrate: '128k',
        hardwareAcceleration: 'cpu_ultrafast',
      );
      expect(mp4Res.success, isTrue);
      expect(await File(mp4OutPath).exists(), isTrue);

      // Verify MP4 streams
      final mp4Probe = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'stream=codec_name',
        '-of', 'json',
        mp4OutPath,
      ]);
      expect(mp4Probe.exitCode, equals(0));
      final mp4Json = jsonDecode(mp4Probe.stdout.toString());
      final mp4Streams = (mp4Json['streams'] as List).map((s) => s['codec_name'] as String).toList();
      expect(mp4Streams, contains('h264'));

      // 3. Convert RM -> MP3
      final mp3OutPath = '${tempDir.path}/rm_converted.mp3';
      final mp3Res = await FFmpegService.convertVideoToMp3(
        videoPath: rmInputPath,
        outputPath: mp3OutPath,
        audioBitrate: '128k',
      );
      expect(mp3Res.success, isTrue);
      expect(await File(mp3OutPath).exists(), isTrue);

      // Verify MP3 stream
      final mp3Probe = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'stream=codec_name',
        '-of', 'json',
        mp3OutPath,
      ]);
      expect(mp3Probe.exitCode, equals(0));
      final mp3Json = jsonDecode(mp3Probe.stdout.toString());
      final mp3Streams = (mp3Json['streams'] as List).map((s) => s['codec_name'] as String).toList();
      expect(mp3Streams, contains('mp3'));
    });

    test('RealMedia decode failure shows clear per-file error without failing batch', () async {
      // 1. Test parseFfmpegErrorMessage with RealMedia stderr
      final testStderr = '''
ffmpeg version 6.1 Copyright (c) 2000-2023 the FFmpeg developers
  built with gcc 13 (GCC)
[in#0 @ 0x55d49aaf4b00] Error opening input: Invalid data found when processing input
Error opening input file corrupt.rm.
Error opening input files: Invalid data found when processing input
''';
      final cleanMsg = FFmpegService.parseFfmpegErrorMessage(
        testStderr,
        inputPath: '/path/to/corrupt.rm',
        exitCode: 183,
      );
      expect(cleanMsg, contains('RealMedia decoding failed'));
      expect(cleanMsg, contains('Invalid data found when processing input'));

      // 2. Create a corrupted .rm file
      final corruptRmPath = '${tempDir.path}/corrupt.rm';
      await File(corruptRmPath).writeAsString('.RMF corrupted realmedia content');

      // 3. Create a valid WebM file
      final validWebmPath = '${tempDir.path}/valid_clip.webm';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'testsrc=duration=1:size=160x120:rate=10',
        '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=mono',
        '-t', '1',
        '-c:v', 'libvpx-vp9', '-b:v', '500k', '-deadline', 'realtime', '-cpu-used', '8',
        '-c:a', 'libopus',
        validWebmPath,
      ]);

      // 4. Batch conversion with corrupted RM and valid WebM
      final batch = BatchConversionService();
      batch.addFiles([corruptRmPath, validWebmPath]);
      expect(batch.items.length, equals(2));

      final settings = ConversionSettings(
        outputFolder: tempDir.path,
        hardwareAcceleration: 'cpu_ultrafast',
      );

      // Run batch conversion
      await batch.startBatch(settings);

      // Corrupt RM item should be marked failed with a descriptive error message
      final corruptItem = batch.items[0];
      expect(corruptItem.status, equals(ConversionStatus.failed));
      expect(corruptItem.errorMessage, isNotNull);
      expect(corruptItem.errorMessage, contains('RealMedia decoding failed'));

      // Valid item must succeed and not be stopped by the previous failure!
      final validItem = batch.items[1];
      expect(validItem.status, equals(ConversionStatus.completed));
      expect(validItem.errorMessage, isNull);
      expect(batch.completedCount, equals(1));
      expect(batch.failedCount, equals(1));
    });
  });

  group('Output File Size Bloat & Resolution Control Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hawwil_bloat_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ConversionSettings defaults are original resolution and auto bitrates', () {
      final settings = ConversionSettings();
      expect(settings.defaultResolution, equals('original'));
      expect(settings.defaultVideoBitrate, equals('auto'));
      expect(settings.defaultAudioBitrate, equals('auto'));
      expect(ConversionSettings.availableResolutions.first, equals('original'));
      expect(ConversionSettings.availableVideoBitrates.first, equals('auto'));
      expect(ConversionSettings.availableAudioBitrates.first, equals('auto'));
    });

    test('calculateBitrateCap calculates generous resolution and framerate-based safety caps', () {
      // 1. Low-res source (e.g. 320x240 @ 30 fps)
      final lowInfo = MediaInfo(width: 320, height: 240, durationSeconds: 3900, totalBitrateKbps: 43);
      final lowCap = FFmpegService.calculateBitrateCap(info: lowInfo);
      expect(lowCap, equals(1500));

      // 2. High-res source (e.g. 1920x1080 @ 30 fps)
      final highInfo = MediaInfo(width: 1920, height: 1080, durationSeconds: 60, totalBitrateKbps: 8000);
      final highCap = FFmpegService.calculateBitrateCap(info: highInfo);
      expect(highCap, equals(20000));

      // 3. 720p source (e.g. 1280x720 @ 30 fps)
      final midInfo = MediaInfo(width: 1280, height: 720, durationSeconds: 60, totalBitrateKbps: 1500);
      final midCap = FFmpegService.calculateBitrateCap(info: midInfo);
      expect(midCap, equals(10000));

      // 4. Framerate scaling (e.g. 1920x1080 @ 60 fps)
      final highFpsInfo = MediaInfo(width: 1920, height: 1080, fps: 60.0);
      final highFpsCap = FFmpegService.calculateBitrateCap(info: highFpsInfo);
      expect(highFpsCap, equals(40000));
    });

    test('getCodecConfigForFormat uses CRF 23 or hardware CQ when videoBitrate is auto or null', () async {
      // libx264
      final x264Config = await FFmpegService.getCodecConfigForFormat(
        targetFormat: 'mp4',
        videoBitrate: 'auto',
        audioBitrate: 'auto',
        hardwareAcceleration: 'cpu_ultrafast',
        maxRateKbps: 1500,
      );
      expect(x264Config.videoEncoderArgs, contains('-crf'));
      expect(x264Config.videoEncoderArgs, contains('23'));
      expect(x264Config.videoEncoderArgs, contains('-maxrate'));
      expect(x264Config.videoEncoderArgs, contains('1500k'));
      expect(x264Config.videoEncoderArgs, contains('-bufsize'));
      expect(x264Config.videoEncoderArgs, contains('3000k'));

      // VP9
      final vp9Config = await FFmpegService.getCodecConfigForFormat(
        targetFormat: 'webm',
        videoBitrate: 'auto',
        audioBitrate: 'auto',
        hardwareAcceleration: 'cpu_ultrafast',
        maxRateKbps: 3000,
      );
      expect(vp9Config.videoEncoderArgs, contains('-crf'));
      expect(vp9Config.videoEncoderArgs, contains('31'));
      expect(vp9Config.videoEncoderArgs, contains('-b:v'));
      expect(vp9Config.videoEncoderArgs, contains('0'));
      expect(vp9Config.videoEncoderArgs, contains('-maxrate'));
      expect(vp9Config.videoEncoderArgs, contains('3000k'));
      expect(vp9Config.videoEncoderArgs, contains('-bufsize'));
      expect(vp9Config.videoEncoderArgs, contains('6000k'));

      // NVENC
      final nvencConfig = await FFmpegService.getCodecConfigForFormat(
        targetFormat: 'mp4',
        videoBitrate: 'auto',
        audioBitrate: 'auto',
        hardwareAcceleration: 'nvenc',
        maxRateKbps: 5000,
      );
      expect(nvencConfig.videoEncoderArgs, contains('-cq:v'));
      expect(nvencConfig.videoEncoderArgs, contains('23'));
      expect(nvencConfig.videoEncoderArgs, contains('-maxrate:v'));
      expect(nvencConfig.videoEncoderArgs, contains('5000k'));
      expect(nvencConfig.videoEncoderArgs, contains('-bufsize:v'));
      expect(nvencConfig.videoEncoderArgs, contains('10000k'));

      // QSV
      final qsvConfig = await FFmpegService.getCodecConfigForFormat(
        targetFormat: 'mp4',
        videoBitrate: 'auto',
        audioBitrate: 'auto',
        hardwareAcceleration: 'qsv',
        maxRateKbps: 5000,
      );
      expect(qsvConfig.videoEncoderArgs, contains('-global_quality'));
      expect(qsvConfig.videoEncoderArgs, contains('23'));
      expect(qsvConfig.videoEncoderArgs, contains('-maxrate:v'));
      expect(qsvConfig.videoEncoderArgs, contains('5000k'));

      // VideoToolbox
      final vtConfig = await FFmpegService.getCodecConfigForFormat(
        targetFormat: 'mp4',
        videoBitrate: 'auto',
        audioBitrate: 'auto',
        hardwareAcceleration: 'videotoolbox',
        maxRateKbps: 5000,
      );
      expect(vtConfig.videoEncoderArgs, contains('-q:v'));
      expect(vtConfig.videoEncoderArgs, contains('60'));
      expect(vtConfig.videoEncoderArgs, contains('-maxrate:v'));
      expect(vtConfig.videoEncoderArgs, contains('5000k'));
    });

    test('Converting low-bitrate source prevents upscaling and size bloat', () async {
      final isFfmpegAvailable = await FFmpegService.checkDesktopFFmpeg();
      if (!isFfmpegAvailable) return;

      // 1. Create a low-bitrate, low-resolution source: 320x240, 5 seconds @ ~40 kbps
      final sourceLowPath = '${tempDir.path}/source_low.mkv';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'testsrc=duration=5:size=320x240:rate=10',
        '-f', 'lavfi', '-i', 'sine=frequency=1000:duration=5',
        '-c:v', 'libx264', '-b:v', '40k', '-preset', 'ultrafast',
        '-c:a', 'aac', '-b:a', '32k',
        sourceLowPath,
      ]);
      expect(await File(sourceLowPath).exists(), isTrue);

      // 2. Convert with default settings (resolution: 'original', videoBitrate: 'auto')
      final outDefaultPath = '${tempDir.path}/out_default.mp4';
      final resDefault = await FFmpegService.convertVideoToVideo(
        videoPath: sourceLowPath,
        outputPath: outDefaultPath,
        targetFormat: 'mp4',
        videoBitrate: 'auto',
        audioBitrate: 'auto',
        resolution: 'original',
      );
      expect(resDefault.success, isTrue);
      expect(await File(outDefaultPath).exists(), isTrue);

      final outDefaultSize = await File(outDefaultPath).length();
      // Output size must be in tens-of-KB range (roughly proportional to input), NOT megabytes!
      expect(outDefaultSize, lessThan(200 * 1024)); // Less than 200 KB for 5 sec

      // Verify resolution was NOT upscaled
      final probeResult = await FFmpegService.probeMedia(outDefaultPath);
      expect(probeResult.width, equals(320));
      expect(probeResult.height, equals(240));

      // 3. Even if user requests 1920x1080, "never upscale" rule keeps it at 320x240
      final outNoUpscalePath = '${tempDir.path}/out_no_upscale.mp4';
      final resNoUpscale = await FFmpegService.convertVideoToVideo(
        videoPath: sourceLowPath,
        outputPath: outNoUpscalePath,
        targetFormat: 'mp4',
        videoBitrate: 'auto',
        audioBitrate: 'auto',
        resolution: '1920x1080',
      );
      expect(resNoUpscale.success, isTrue);
      final probeNoUpscale = await FFmpegService.probeMedia(outNoUpscalePath);
      expect(probeNoUpscale.width, equals(320));
      expect(probeNoUpscale.height, equals(240));
    });

    test('Converting higher-quality source retains resolution and quality without degrading', () async {
      final isFfmpegAvailable = await FFmpegService.checkDesktopFFmpeg();
      if (!isFfmpegAvailable) return;

      // Create a 1-second 1920x1080 source file
      final highSourcePath = '${tempDir.path}/source_high.mp4';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'testsrc=duration=1:size=1920x1080:rate=24',
        '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1',
        '-c:v', 'libx264', '-crf', '20', '-preset', 'ultrafast',
        '-c:a', 'aac', '-b:a', '192k',
        highSourcePath,
      ]);
      expect(await File(highSourcePath).exists(), isTrue);

      // Convert to MKV with default settings
      final highOutPath = '${tempDir.path}/out_high.mkv';
      final resHigh = await FFmpegService.convertVideoToVideo(
        videoPath: highSourcePath,
        outputPath: highOutPath,
        targetFormat: 'mkv',
        videoBitrate: 'auto',
        audioBitrate: 'auto',
        resolution: 'original',
      );
      expect(resHigh.success, isTrue);
      expect(await File(highOutPath).exists(), isTrue);

      final probeHigh = await FFmpegService.probeMedia(highOutPath);
      expect(probeHigh.width, equals(1920));
      expect(probeHigh.height, equals(1080));
    });

    test('Converting low-bitrate RealMedia (.rm) to MP4 with default settings produces tens-of-MB equivalent without upscaling', () async {
      final isFfmpegAvailable = await FFmpegService.checkDesktopFFmpeg();
      if (!isFfmpegAvailable) return;

      // 1. Create a synthetic low-bitrate RealMedia (.rm) file: 320x240, 5 seconds @ ~40 kbps video + 32 kbps audio
      final rmInputPath = '${tempDir.path}/clip_low.rm';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'testsrc=duration=5:size=320x240:rate=10',
        '-f', 'lavfi', '-i', 'sine=frequency=800:duration=5',
        '-c:v', 'rv20', '-b:v', '40k',
        '-c:a', 'ac3', '-b:a', '32k',
        rmInputPath,
      ]);
      expect(await File(rmInputPath).exists(), isTrue);

      // 2. Convert with default settings (auto bitrate, original resolution)
      final mp4OutPath = '${tempDir.path}/rm_default_converted.mp4';
      final res = await FFmpegService.convertVideoToVideo(
        videoPath: rmInputPath,
        outputPath: mp4OutPath,
        targetFormat: 'mp4',
        videoBitrate: 'auto',
        audioBitrate: 'auto',
        resolution: 'original',
      );
      expect(res.success, isTrue);
      expect(await File(mp4OutPath).exists(), isTrue);

      // 3. Verify size: 5 seconds should be < 120 KB, which scales to ~45 MB for 65 minutes (tens of MB, not 1.1 GB)
      final outSize = await File(mp4OutPath).length();
      expect(outSize, lessThan(120 * 1024));

      // 4. Verify resolution is maintained at 320x240
      final probe = await FFmpegService.probeMedia(mp4OutPath);
      expect(probe.width, equals(320));
      expect(probe.height, equals(240));
    });

    test('Re-converting source with high-motion middle segment produces no blocky/glitchy middle while keeping size reasonable', () async {
      final isFfmpegAvailable = await FFmpegService.checkDesktopFFmpeg();
      if (!isFfmpegAvailable) return;

      // 1. Create a source with calm start, high-motion / complex middle segment, and calm end:
      // 3s calm testsrc, 4s intense pattern/motion testsrc2, 3s calm testsrc.
      final burstSourcePath = '${tempDir.path}/burst_source.mp4';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'testsrc=duration=3:size=320x240:rate=25',
        '-f', 'lavfi', '-i', 'testsrc2=duration=4:size=320x240:rate=25',
        '-f', 'lavfi', '-i', 'testsrc=duration=3:size=320x240:rate=25',
        '-filter_complex', '[0:v]format=yuv420p[v0];[1:v]format=yuv420p[v1];[2:v]format=yuv420p[v2];[v0][v1][v2]concat=n=3:v=1:a=0[outv]',
        '-map', '[outv]',
        '-c:v', 'libx264', '-crf', '22', '-preset', 'ultrafast',
        burstSourcePath,
      ]);
      expect(await File(burstSourcePath).exists(), isTrue);

      // 2. Convert with default settings (auto bitrate, original resolution)
      final burstOutPath = '${tempDir.path}/burst_converted.mp4';
      final res = await FFmpegService.convertVideoToVideo(
        videoPath: burstSourcePath,
        outputPath: burstOutPath,
        targetFormat: 'mp4',
        videoBitrate: 'auto',
        audioBitrate: 'auto',
        resolution: 'original',
      );
      expect(res.success, isTrue);
      expect(await File(burstOutPath).exists(), isTrue);

      // 3. Step through the middle of the video (t = 4.0s, 5.0s, 6.0s) and verify visual fidelity
      for (final t in ['4.0', '5.0', '6.0']) {
        final srcFrame = '${tempDir.path}/frame_src_$t.png';
        final outFrame = '${tempDir.path}/frame_out_$t.png';
        await Process.run('ffmpeg', ['-y', '-ss', t, '-i', burstSourcePath, '-vframes', '1', srcFrame]);
        await Process.run('ffmpeg', ['-y', '-ss', t, '-i', burstOutPath, '-vframes', '1', outFrame]);
        expect(await File(srcFrame).exists(), isTrue);
        expect(await File(outFrame).exists(), isTrue);
      }

      // Check SSIM specifically across the middle complex segment (t=3s to t=7s)
      final ssimRes = await Process.run('ffmpeg', [
        '-ss', '3.0', '-t', '4.0', '-i', burstOutPath,
        '-ss', '3.0', '-t', '4.0', '-i', burstSourcePath,
        '-filter_complex', 'ssim', '-f', 'null', '-'
      ]);
      final ssimLogs = ssimRes.stderr.toString();
      final ssimMatch = RegExp(r'All:(\d+\.\d+)').firstMatch(ssimLogs);
      expect(ssimMatch, isNotNull);
      final ssimVal = double.parse(ssimMatch!.group(1)!);
      // High visual fidelity: no blocky/glitchy corruption in the middle (SSIM > 0.98)
      expect(ssimVal, greaterThan(0.98));

      // 4. Output size stays reasonable and compact (not gigabytes)
      final outSize = await File(burstOutPath).length();
      expect(outSize, lessThan(600 * 1024)); // Less than 600 KB for 10 seconds of 320x240
    });
  });

  group('Audio Quality & VBR Bitrate Control Tests', () {
    late Directory audioTempDir;

    setUp(() async {
      audioTempDir = await Directory.systemTemp.createTemp('hawwil_audio_test_');
    });

    tearDown(() async {
      if (await audioTempDir.exists()) {
        await audioTempDir.delete(recursive: true);
      }
    });

    test('buildAudioEncoderArgs uses quality-based VBR for lossy codecs and preserves lossless', () {
      // 1. MP3 auto uses libmp3lame with -q:a 2 (not fixed CBR)
      final mp3Args = FFmpegService.buildAudioEncoderArgs(targetFormat: 'mp3');
      expect(mp3Args, contains('libmp3lame'));
      expect(mp3Args, contains('-q:a'));
      expect(mp3Args, contains('2'));
      expect(mp3Args, isNot(contains('-b:a')));

      // 2. AAC auto uses -q:a 2 VBR
      final aacArgs = FFmpegService.buildAudioEncoderArgs(targetFormat: 'aac');
      expect(aacArgs, contains('aac'));
      expect(aacArgs, contains('-q:a'));
      expect(aacArgs, contains('2'));
      expect(aacArgs, isNot(contains('-b:a')));

      // 3. Opus auto uses VBR with ~128k
      final opusArgs = FFmpegService.buildAudioEncoderArgs(targetFormat: 'opus');
      expect(opusArgs, contains('libopus'));
      expect(opusArgs, contains('-vbr'));
      expect(opusArgs, contains('on'));
      expect(opusArgs, contains('128k'));

      // 4. Vorbis auto uses -q:a 5 VBR
      final oggArgs = FFmpegService.buildAudioEncoderArgs(targetFormat: 'ogg');
      expect(oggArgs, contains('libvorbis'));
      expect(oggArgs, contains('-q:a'));
      expect(oggArgs, contains('5'));

      // 5. Lossless WAV & FLAC: uncompressed/lossless without lossy VBR or CBR flags
      final wavArgs = FFmpegService.buildAudioEncoderArgs(targetFormat: 'wav');
      expect(wavArgs, equals(['-c:a', 'pcm_s16le']));

      final flacArgs = FFmpegService.buildAudioEncoderArgs(targetFormat: 'flac');
      expect(flacArgs, equals(['-c:a', 'flac']));

      // 6. Channel preservation: never upmix mono to stereo
      final monoArgs = FFmpegService.buildAudioEncoderArgs(
        targetFormat: 'mp3',
        sourceChannels: 1,
      );
      expect(monoArgs, contains('-ac'));
      expect(monoArgs, contains('1'));

      final stereoArgs = FFmpegService.buildAudioEncoderArgs(
        targetFormat: 'aac',
        sourceChannels: 2,
      );
      expect(stereoArgs, contains('-ac'));
      expect(stereoArgs, contains('2'));

      // 7. Sample rate preservation: never upsample low sample rate
      final lowRateArgs = FFmpegService.buildAudioEncoderArgs(
        targetFormat: 'mp3',
        sourceSampleRate: 22050,
      );
      expect(lowRateArgs, contains('-ar'));
      expect(lowRateArgs, contains('22050'));

      // Opus rate whitelist handling: 22050 is not in Opus whitelist [8000, 12000, 16000, 24000, 48000]
      // so -ar should not be passed for 22050 to prevent libopus encoder exit error
      final opusLowRateArgs = FFmpegService.buildAudioEncoderArgs(
        targetFormat: 'opus',
        sourceSampleRate: 22050,
      );
      expect(opusLowRateArgs, isNot(contains('-ar')));

      final opusValidRateArgs = FFmpegService.buildAudioEncoderArgs(
        targetFormat: 'opus',
        sourceSampleRate: 16000,
      );
      expect(opusValidRateArgs, contains('-ar'));
      expect(opusValidRateArgs, contains('16000'));

      // 8. Explicit bitrate override respected if user asks for it
      final explicitArgs = FFmpegService.buildAudioEncoderArgs(
        targetFormat: 'mp3',
        audioBitrate: '64k',
      );
      expect(explicitArgs, contains('-b:a'));
      expect(explicitArgs, contains('64k'));
      expect(explicitArgs, isNot(contains('-q:a')));
    });

    test('Converting low-quality audio source scales output size with real quality without upsampling', () async {
      final isFfmpegAvailable = await FFmpegService.checkDesktopFFmpeg();
      if (!isFfmpegAvailable) return;

      // Create a 3-second low-quality mono source: 22050 Hz @ 32 kbps
      final lowAudioSource = '${audioTempDir.path}/low_quality_source.mp3';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'sine=frequency=440:duration=3',
        '-c:a', 'libmp3lame',
        '-ar', '22050',
        '-ac', '1',
        '-b:a', '32k',
        lowAudioSource,
      ]);
      expect(await File(lowAudioSource).exists(), isTrue);

      // Verify source probe: mono (1 channel), 22050 Hz
      final srcProbe = await FFmpegService.probeMedia(lowAudioSource);
      expect(srcProbe.audioChannels, equals(1));
      expect(srcProbe.audioSampleRate, equals(22050));

      // 1. Convert to MP3 with default auto settings
      final mp3Out = '${audioTempDir.path}/out_low.mp3';
      final resMp3 = await FFmpegService.convertVideoToAudio(
        videoPath: lowAudioSource,
        outputPath: mp3Out,
        targetFormat: 'mp3',
        audioBitrate: 'auto',
      );
      expect(resMp3.success, isTrue);
      expect(await File(mp3Out).exists(), isTrue);

      final outProbeMp3 = await FFmpegService.probeMedia(mp3Out);
      // Preserved mono and 22050 Hz without upsampling!
      expect(outProbeMp3.audioChannels, equals(1));
      expect(outProbeMp3.audioSampleRate, equals(22050));

      // File size scales with low quality (3s at ~25-35 kbps is < 20 KB; 320 kbps CBR would be ~120 KB!)
      final mp3Size = await File(mp3Out).length();
      expect(mp3Size, lessThan(30 * 1024));

      // 2. Convert to AAC with default auto settings
      final aacOut = '${audioTempDir.path}/out_low.aac';
      final resAac = await FFmpegService.convertVideoToAudio(
        videoPath: lowAudioSource,
        outputPath: aacOut,
        targetFormat: 'aac',
        audioBitrate: 'auto',
      );
      expect(resAac.success, isTrue);
      expect(await File(aacOut).exists(), isTrue);

      final outProbeAac = await FFmpegService.probeMedia(aacOut);
      expect(outProbeAac.audioChannels, equals(1));
      expect(outProbeAac.audioSampleRate, equals(22050));
      final aacSize = await File(aacOut).length();
      expect(aacSize, lessThan(45 * 1024)); // < 45 KB vs 120 KB for fixed 320k CBR
    });

    test('Converting normal quality audio source retains fidelity and correct parameters', () async {
      final isFfmpegAvailable = await FFmpegService.checkDesktopFFmpeg();
      if (!isFfmpegAvailable) return;

      // Create a 3-second normal quality stereo source: 44100 Hz
      final normalAudioSource = '${audioTempDir.path}/normal_quality_source.wav';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'sine=frequency=1000:duration=3',
        '-c:a', 'pcm_s16le',
        '-ar', '44100',
        '-ac', '2',
        normalAudioSource,
      ]);
      expect(await File(normalAudioSource).exists(), isTrue);

      // 1. Convert to MP3
      final mp3Out = '${audioTempDir.path}/normal_out.mp3';
      final resMp3 = await FFmpegService.convertVideoToAudio(
        videoPath: normalAudioSource,
        outputPath: mp3Out,
        targetFormat: 'mp3',
        audioBitrate: 'auto',
      );
      expect(resMp3.success, isTrue);
      expect(await File(mp3Out).exists(), isTrue);

      final probeMp3 = await FFmpegService.probeMedia(mp3Out);
      expect(probeMp3.audioChannels, equals(2));
      expect(probeMp3.audioSampleRate, equals(44100));
      expect(probeMp3.durationSeconds, closeTo(3.0, 0.5));

      // 2. Convert to AAC
      final aacOut = '${audioTempDir.path}/normal_out.aac';
      final resAac = await FFmpegService.convertVideoToAudio(
        videoPath: normalAudioSource,
        outputPath: aacOut,
        targetFormat: 'aac',
        audioBitrate: 'auto',
      );
      expect(resAac.success, isTrue);
      expect(await File(aacOut).exists(), isTrue);

      final probeAac = await FFmpegService.probeMedia(aacOut);
      expect(probeAac.audioChannels, equals(2));
      expect(probeAac.audioSampleRate, equals(44100));

      // 3. Convert to Opus
      final opusOut = '${audioTempDir.path}/normal_out.opus';
      final resOpus = await FFmpegService.convertVideoToAudio(
        videoPath: normalAudioSource,
        outputPath: opusOut,
        targetFormat: 'opus',
        audioBitrate: 'auto',
      );
      expect(resOpus.success, isTrue);
      expect(await File(opusOut).exists(), isTrue);

      final probeOpus = await FFmpegService.probeMedia(opusOut);
      expect(probeOpus.audioChannels, equals(2));
      // Opus natively encodes at 48000 Hz internal rate
      expect(probeOpus.audioSampleRate, equals(48000));
    });

    test('Video container embedding audio track uses VBR and preserves source audio specs', () async {
      final isFfmpegAvailable = await FFmpegService.checkDesktopFFmpeg();
      if (!isFfmpegAvailable) return;

      // Create a 3-second mono 22050 Hz audio file
      final monoAudio = '${audioTempDir.path}/mono_speech.mp3';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'sine=frequency=600:duration=3',
        '-c:a', 'libmp3lame',
        '-ar', '22050',
        '-ac', '1',
        '-b:a', '32k',
        monoAudio,
      ]);

      // Create a 320x240 image
      final imgPath = '${audioTempDir.path}/cover.png';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'color=c=blue:s=320x240:d=1',
        '-vframes', '1',
        imgPath,
      ]);

      // Cover-to-video (convertMp3ToVideo) into MP4
      final mp4Out = '${audioTempDir.path}/cover_video.mp4';
      final res = await FFmpegService.convertMp3ToVideo(
        audioPath: monoAudio,
        imagePath: imgPath,
        outputPath: mp4Out,
        targetFormat: 'mp4',
        audioBitrate: 'auto',
      );
      expect(res.success, isTrue);
      expect(await File(mp4Out).exists(), isTrue);

      // Probe output MP4 audio stream
      final probe = await FFmpegService.probeMedia(mp4Out);
      expect(probe.audioChannels, equals(1)); // Preserved mono (no upmixing)
      expect(probe.audioSampleRate, equals(22050)); // Preserved 22050 Hz (no upsampling)

      // Total size is small (not bloated with 320k audio)
      final size = await File(mp4Out).length();
      expect(size, lessThan(40 * 1024));
    });
  });
}

