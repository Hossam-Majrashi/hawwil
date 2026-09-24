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
}
