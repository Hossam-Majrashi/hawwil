import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hawwil/models/conversion_item.dart';
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
  });
}
