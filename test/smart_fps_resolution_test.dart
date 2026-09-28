import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hawwil/models/conversion_item.dart';
import 'package:hawwil/models/conversion_settings.dart';
import 'package:hawwil/services/batch_conversion_service.dart';
import 'package:hawwil/services/ffmpeg_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('File Type Classification & Extension Detection', () {
    test('Correctly classifies all supported video extensions', () {
      for (final ext in ConversionItem.supportedInputVideoExtensions) {
        expect(ConversionItem.isVideoExtension(ext), isTrue,
            reason: '$ext should be recognized as video');
        expect(ConversionItem.isAudioExtension(ext), isFalse,
            reason: '$ext should NOT be recognized as audio');
        expect(ConversionItem.isVideoExtension('.$ext'), isTrue,
            reason: '.$ext with dot should be recognized as video');
        expect(ConversionItem.isVideoExtension(ext.toUpperCase()), isTrue,
            reason: '${ext.toUpperCase()} uppercase should be recognized as video');

        final item = ConversionItem(
          id: 'test_$ext',
          sourcePath: '/path/to/sample.$ext',
          fileName: 'sample.$ext',
        );
        expect(item.isVideoInput, isTrue, reason: '$ext item isVideoInput');
        expect(item.isAudioInput, isFalse, reason: '$ext item isAudioInput');
      }
    });

    test('Correctly classifies all supported audio extensions', () {
      for (final ext in ConversionItem.supportedInputAudioExtensions) {
        expect(ConversionItem.isAudioExtension(ext), isTrue,
            reason: '$ext should be recognized as audio');
        expect(ConversionItem.isVideoExtension(ext), isFalse,
            reason: '$ext should NOT be recognized as video');
        expect(ConversionItem.isAudioExtension('.$ext'), isTrue,
            reason: '.$ext with dot should be recognized as audio');
        expect(ConversionItem.isAudioExtension(ext.toUpperCase()), isTrue,
            reason: '${ext.toUpperCase()} uppercase should be recognized as audio');

        final item = ConversionItem(
          id: 'test_$ext',
          sourcePath: '/path/to/sample.$ext',
          fileName: 'sample.$ext',
        );
        expect(item.isAudioInput, isTrue, reason: '$ext item isAudioInput');
        expect(item.isVideoInput, isFalse, reason: '$ext item isVideoInput');
      }
    });

    test('extractExtension handles unusual and edge case paths', () {
      expect(ConversionItem.extractExtension('/path/to/file.MP4'), equals('mp4'));
      expect(ConversionItem.extractExtension('archive.tar.gz'), equals('gz'));
      expect(ConversionItem.extractExtension('video.with.dots.in.name.mkv'), equals('mkv'));
      expect(ConversionItem.extractExtension('.hiddenfile.mp3'), equals('mp3'));
      expect(ConversionItem.extractExtension('noextension'), equals(''));
    });
  });

  group('ConversionItem Smart Suggestion & Overrides Model Tests', () {
    test('ConversionItem has fpsOverride field alongside existing overrides', () {
      final item = ConversionItem(
        id: 'item1',
        sourcePath: '/test/video.mp4',
        fileName: 'video.mp4',
        resolutionOverride: '1920x1080',
        fpsOverride: 25.0,
        videoBitrateOverride: '2000k',
        audioBitrateOverride: '192k',
      );

      expect(item.resolutionOverride, equals('1920x1080'));
      expect(item.fpsOverride, equals(25.0));
      expect(item.videoBitrateOverride, equals('2000k'));
      expect(item.audioBitrateOverride, equals('192k'));

      item.fpsOverride = 30.0;
      expect(item.fpsOverride, equals(30.0));
      item.fpsOverride = null;
      expect(item.fpsOverride, isNull);
    });

    test('ConversionSettings includes defaultFps and availableFps list', () {
      final settings = ConversionSettings();
      expect(settings.defaultFps, equals('auto'));
      expect(ConversionSettings.availableFps, containsAll(['auto', '60', '30', '25', '24', '2', '1']));

      final copied = settings.copyWith(defaultFps: '30');
      expect(copied.defaultFps, equals('30'));
    });

    test('BatchConversionService setItemFps and setBatchFps methods work correctly', () {
      final service = BatchConversionService();
      service.addFiles(['/a.mp4', '/b.mp4']);
      final item1 = service.items[0];
      final item2 = service.items[1];

      service.setItemFps(item1, 24.0);
      expect(item1.fpsOverride, equals(24.0));
      expect(item2.fpsOverride, isNull);

      service.setBatchFps(60.0);
      expect(item1.fpsOverride, equals(60.0));
      expect(item2.fpsOverride, equals(60.0));

      service.setItemResolution(item1, '1280x720');
      expect(item1.resolutionOverride, equals('1280x720'));

      service.setBatchResolution('1920x1080');
      expect(item1.resolutionOverride, equals('1920x1080'));
      expect(item2.resolutionOverride, equals('1920x1080'));

      service.dispose();
    });
  });

  group('Binary Image Dimension Header Probing', () {
    test('probeImageDimensions parses PNG headers accurately without native UI engine', () async {
      // Create a valid 1x1 PNG header with 1920x1080 dimensions
      final bb = BytesBuilder();
      // PNG Signature
      bb.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      // IHDR chunk length = 13 (big endian 0x0000000D)
      bb.add([0x00, 0x00, 0x00, 0x0D]);
      // IHDR chunk type
      bb.add(ascii.encode('IHDR'));
      // Width = 1920 (0x00000780)
      bb.add([0x00, 0x00, 0x07, 0x80]);
      // Height = 1080 (0x00000438)
      bb.add([0x00, 0x00, 0x04, 0x38]);
      // bit depth (8), color type (2 = Truecolor), compression (0), filter (0), interlace (0)
      bb.add([0x08, 0x02, 0x00, 0x00, 0x00]);
      // CRC
      bb.add([0x00, 0x00, 0x00, 0x00]);

      final bytes = bb.toBytes();
      final dims = await FFmpegService.probeImageDimensions(bytes);
      expect(dims, isNotNull);
      expect(dims!.width, equals(1920));
      expect(dims.height, equals(1080));
    });

    test('probeImageDimensions parses JPEG headers accurately', () async {
      final bb = BytesBuilder();
      // SOI marker
      bb.add([0xFF, 0xD8]);
      // APP0 marker
      bb.add([0xFF, 0xE0]);
      bb.add([0x00, 0x10]); // Length 16
      bb.add(ascii.encode('JFIF\x00')); // Identifier
      bb.add([0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]);
      // SOF0 marker (Baseline DCT)
      bb.add([0xFF, 0xC0]);
      bb.add([0x00, 0x11]); // length 17
      bb.add([0x08]); // precision
      // Height = 720 (0x02D0)
      bb.add([0x02, 0xD0]);
      // Width = 1280 (0x0500)
      bb.add([0x05, 0x00]);
      bb.add([0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01]);
      // EOI
      bb.add([0xFF, 0xD9]);

      final bytes = bb.toBytes();
      final dims = await FFmpegService.probeImageDimensions(bytes);
      expect(dims, isNotNull);
      expect(dims!.width, equals(1280));
      expect(dims.height, equals(720));
    });
  });

  group('End-to-End Smart Suggestions with Real Files & Probing', () {
    late Directory tempDir;
    late bool isFfmpegAvailable;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('hawwil_smart_fps_test_');
      try {
        final res = await Process.run('ffmpeg', ['-version']);
        isFfmpegAvailable = res.exitCode == 0;
      } catch (_) {
        isFfmpegAvailable = false;
      }
    });

    tearDownAll(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Real motion video probes to its own metadata (25 fps, 1920x1080), never audio defaults', () async {
      if (!isFfmpegAvailable) return;

      // 1. Generate real motion video: 25 fps, 1920x1080
      final motionVideoPath = '${tempDir.path}/motion_25fps_1080p.mp4';
      final genResult = await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'testsrc=size=1920x1080:rate=25',
        '-t', '1',
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        motionVideoPath,
      ]);
      expect(genResult.exitCode, equals(0), reason: 'ffmpeg testsrc generation should succeed');

      // 2. Add file to BatchConversionService
      final batchService = BatchConversionService();
      batchService.addFiles([motionVideoPath]);

      expect(batchService.items.length, equals(1));
      final item = batchService.items.first;

      // Wait for async inspection
      int attempts = 0;
      while ((item.fpsOverride == null || item.status == ConversionStatus.extractingThumbnail) && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      // 3. Verify smart suggestions:
      // Must match video's OWN metadata: 25 fps and 1920x1080
      expect(item.fpsOverride, equals(25.0),
          reason: 'Genuine motion video must suggest 25 fps, NOT 1-2 fps');
      expect(item.resolutionOverride, equals('1920x1080'),
          reason: 'Genuine motion video must suggest 1920x1080');
      expect(item.isAudioInput, isFalse);
      expect(item.isVideoInput, isTrue);

      batchService.dispose();
    });

    test('Audio file with cover suggests 2 fps and cover resolution, updates on custom cover pick', () async {
      if (!isFfmpegAvailable) return;

      // 1. Generate audio file
      final audioPath = '${tempDir.path}/test_audio.mp3';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1',
        '-c:a', 'libmp3lame', '-b:a', '128k',
        audioPath,
      ]);

      // 2. Generate cover image 800x600 (even dimensions)
      final coverPath = '${tempDir.path}/cover_800x600.png';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'color=c=navy:s=800x600:d=1',
        '-vframes', '1',
        coverPath,
      ]);
      final coverBytes = await File(coverPath).readAsBytes();

      // 3. Add to batch service
      final batchService = BatchConversionService();
      batchService.addFiles([audioPath]);
      expect(batchService.items.length, equals(1));
      final item = batchService.items.first;

      // Wait for inspection
      int attempts = 0;
      while ((item.fpsOverride == null || item.status == ConversionStatus.extractingThumbnail) && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      // Audio file smart suggestion
      expect(item.isAudioInput, isTrue);
      expect(item.fpsOverride, equals(2.0),
          reason: 'Audio input must suggest 2 fps (1-2 fps) for static image path');

      // 4. Set custom cover image
      await batchService.setCustomImage(item, coverPath, coverBytes);

      // Verify suggested resolution updated to match cover dimensions (800x600)
      expect(item.resolutionOverride, equals('800x600'),
          reason: 'Suggested resolution must match picked cover image');
      expect(item.fpsOverride, equals(2.0),
          reason: 'Fps suggestion stays 2.0 for audio cover video');

      // 5. Pick a DIFFERENT custom cover image (1280x720)
      final cover2Path = '${tempDir.path}/cover_1280x720.png';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'color=c=purple:s=1280x720:d=1',
        '-vframes', '1',
        cover2Path,
      ]);
      final cover2Bytes = await File(cover2Path).readAsBytes();

      await batchService.setCustomImage(item, cover2Path, cover2Bytes);

      // Verify suggested resolution dynamically updated to 1280x720
      expect(item.resolutionOverride, equals('1280x720'),
          reason: 'Suggested resolution must update when user picks new cover');

      batchService.dispose();
    });

    test('Video-to-video export respects fpsOverride and resolutionOverride in output file', () async {
      if (!isFfmpegAvailable) return;

      // Source video is 25 fps, 1920x1080
      final srcVideo = '${tempDir.path}/src_25fps_1080p.mp4';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'testsrc=size=1920x1080:rate=25',
        '-t', '1',
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        srcVideo,
      ]);

      final outVideo = '${tempDir.path}/out_30fps_720p.mp4';

      // Override to 30 fps and 1280x720
      final result = await FFmpegService.convertVideoToVideo(
        videoPath: srcVideo,
        outputPath: outVideo,
        targetFormat: 'mp4',
        resolution: '1280x720',
        fps: 30.0,
      );

      expect(result.success, isTrue, reason: 'convertVideoToVideo with overrides should succeed: ${result.errorMessage}');
      expect(await File(outVideo).exists(), isTrue);

      // Probe output file using ffprobe
      final probe = await Process.run('ffprobe', [
        '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,r_frame_rate',
        '-of', 'json',
        outVideo,
      ]);
      expect(probe.exitCode, equals(0));
      final info = jsonDecode(probe.stdout as String);
      final stream = info['streams'][0];

      expect(stream['width'], equals(1280));
      expect(stream['height'], equals(720));
      expect(stream['r_frame_rate'], equals('30/1'),
          reason: 'Exported video must have exactly 30 fps as overridden');
    });

    test('Audio-to-video export respects fpsOverride and resolutionOverride in output file', () async {
      if (!isFfmpegAvailable) return;

      final audioPath = '${tempDir.path}/test_audio_export.mp3';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'sine=frequency=500:duration=1',
        '-c:a', 'libmp3lame',
        audioPath,
      ]);

      final imagePath = '${tempDir.path}/test_cover_export.png';
      await Process.run('ffmpeg', [
        '-y',
        '-f', 'lavfi', '-i', 'color=c=darkgreen:s=640x480:d=1',
        '-vframes', '1',
        imagePath,
      ]);

      final outVideo = '${tempDir.path}/out_audio_1fps.mp4';

      // Convert with fps=1.0 and resolution='640x480'
      final result = await FFmpegService.convertMp3ToVideo(
        audioPath: audioPath,
        imagePath: imagePath,
        outputPath: outVideo,
        targetFormat: 'mp4',
        resolution: '640x480',
        fps: 1.0,
      );

      expect(result.success, isTrue, reason: 'convertMp3ToVideo should succeed: ${result.errorMessage}');
      expect(await File(outVideo).exists(), isTrue);

      final probe = await Process.run('ffprobe', [
        '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,r_frame_rate',
        '-of', 'json',
        outVideo,
      ]);
      expect(probe.exitCode, equals(0));
      final info = jsonDecode(probe.stdout as String);
      final stream = info['streams'][0];

      expect(stream['width'], equals(640));
      expect(stream['height'], equals(480));
      expect(stream['r_frame_rate'], equals('1/1'),
          reason: 'Exported audio-video must have exactly 1 fps as overridden');
    });
  });
}
