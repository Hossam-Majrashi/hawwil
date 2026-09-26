import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hawwil/services/ffmpeg_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hawwil_cover_video_test_');

    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Video with no embedded cover extracts its first frame, not black', () async {
    // Generate a test video that has visible content (red frame) and audio
    final videoPath = p.join(tempDir.path, 'source_motion.mp4');
    final genRes = await Process.run('ffmpeg', [
      '-y',
      '-f', 'lavfi',
      '-i', 'color=c=red:s=320x240:d=3:r=25',
      '-f', 'lavfi',
      '-i', 'sine=frequency=1000:duration=3',
      '-c:v', 'libx264',
      '-preset', 'ultrafast',
      '-c:a', 'aac',
      videoPath,
    ]);
    expect(genRes.exitCode, 0, reason: 'Failed to create test video: ${genRes.stderr}');
    expect(await File(videoPath).exists(), true);

    // Call extractMp4CoverOrFrame
    final frameBytes = await FFmpegService.extractMp4CoverOrFrame(
      videoPath: videoPath,
      timestampSeconds: 0.0,
    );

    expect(frameBytes, isNotNull);
    expect(frameBytes!.isNotEmpty, true);

    // Assert that the extracted frame is visually non-black
    final isBlack = await FFmpegService.isImageVisuallyBlack(frameBytes);
    expect(isBlack, false, reason: 'Extracted first frame should not be black');
  });

  test('Replacing video frames with chosen image replaces visual frames and preserves audio', () async {
    // 1. Create a 3-second source video (blue canvas with 440Hz sine wave audio)
    final sourceVideoPath = p.join(tempDir.path, 'source_to_replace.mp4');
    final genVideo = await Process.run('ffmpeg', [
      '-y',
      '-f', 'lavfi',
      '-i', 'color=c=blue:s=320x240:d=3:r=25',
      '-f', 'lavfi',
      '-i', 'sine=frequency=440:duration=3',
      '-c:v', 'libx264',
      '-preset', 'ultrafast',
      '-c:a', 'aac',
      sourceVideoPath,
    ]);
    expect(genVideo.exitCode, 0);

    // 2. Create a chosen image (green image)
    final chosenImagePath = p.join(tempDir.path, 'new_cover.jpg');
    final genImg = await Process.run('ffmpeg', [
      '-y',
      '-f', 'lavfi',
      '-i', 'color=c=green:s=320x240:d=1',
      '-frames:v', '1',
      chosenImagePath,
    ]);
    expect(genImg.exitCode, 0);
    final chosenImageBytes = await File(chosenImagePath).readAsBytes();

    // 3. Update cover with replaceVideoFrames: true
    final success = await FFmpegService.updateMp4CoverAndMetadata(
      filePath: sourceVideoPath,
      newCoverBytes: chosenImageBytes,
      replaceVideoFrames: true,
      title: 'Static Frame Video',
      artist: 'Hawwil Artist',
      album: 'Hawwil Album',
    );
    expect(success, true, reason: 'updateMp4CoverAndMetadata should succeed');

    // 4. Verify media attributes
    final mediaInfo = await FFmpegService.probeMedia(sourceVideoPath);
    expect(mediaInfo.width, isNotNull);
    expect(mediaInfo.height, isNotNull);
    expect(mediaInfo.audioChannels, isNotNull);
    expect(mediaInfo.audioChannels! > 0, true);
    // Duration should be preserved (~3s)
    final duration = await FFmpegService.getMediaDuration(sourceVideoPath);
    expect(duration, isNotNull);
    expect(duration!, closeTo(3.0, 0.5));

    // 5. Verify tags
    final tags = await FFmpegService.readMediaTags(sourceVideoPath);
    expect(tags['title'], 'Static Frame Video');
    expect(tags['artist'], 'Hawwil Artist');
    expect(tags['album'], 'Hawwil Album');

    // 6. Verify frames at beginning, middle, and near end
    for (final scrubSec in [0.0, 1.0, 2.0]) {
      final frame = await FFmpegService.extractVideoFrame(
        videoPath: sourceVideoPath,
        timestampSeconds: scrubSec,
      );
      expect(frame, isNotNull);
      expect(frame!.isNotEmpty, true);
      // Ensure the frame is not black
      final isBlack = await FFmpegService.isImageVisuallyBlack(frame);
      expect(isBlack, false, reason: 'Frame at ${scrubSec}s should be visible green, not black');
    }

    // 7. Verify output size is lightweight (2 fps static image is typically < 200KB for 3s)
    final fileLen = await File(sourceVideoPath).length();
    expect(fileLen, lessThan(300 * 1024), reason: 'Static-image video should be compact in size');
  });

  test('Video starting with black fade-in probes forward to find first visible frame', () async {
    // Generate a 3-second video where the first 0.2s is black and the rest is bright yellow
    final fadeVideoPath = p.join(tempDir.path, 'fade_in_video.mp4');
    final genRes = await Process.run('ffmpeg', [
      '-y',
      '-f', 'lavfi',
      '-i', 'color=c=black:s=320x240:d=0.2',
      '-f', 'lavfi',
      '-i', 'color=c=yellow:s=320x240:d=2.8',
      '-filter_complex', '[0:v][1:v]concat=n=2:v=1:a=0[outv]',
      '-map', '[outv]',
      '-c:v', 'libx264',
      '-preset', 'ultrafast',
      fadeVideoPath,
    ]);
    expect(genRes.exitCode, 0, reason: 'Failed to create fade video: ${genRes.stderr}');

    // Extract cover with extractMp4CoverOrFrame at 0.0s
    final coverBytes = await FFmpegService.extractMp4CoverOrFrame(
      videoPath: fadeVideoPath,
      timestampSeconds: 0.0,
    );

    expect(coverBytes, isNotNull);
    final isBlack = await FFmpegService.isImageVisuallyBlack(coverBytes!);
    expect(isBlack, false, reason: 'Cover preview should probe forward and find the visible yellow frame instead of rendering black');
  });

  test('Replacing video frames in MKV container works seamlessly', () async {
    final mkvPath = p.join(tempDir.path, 'source_mkv.mkv');
    final genMkv = await Process.run('ffmpeg', [
      '-y',
      '-f', 'lavfi',
      '-i', 'color=c=purple:s=320x240:d=2:r=25',
      '-f', 'lavfi',
      '-i', 'sine=frequency=500:duration=2',
      '-c:v', 'libx264',
      '-preset', 'ultrafast',
      '-c:a', 'aac',
      mkvPath,
    ]);
    expect(genMkv.exitCode, 0);

    final imgPath = p.join(tempDir.path, 'mkv_cover.jpg');
    final genImg = await Process.run('ffmpeg', [
      '-y',
      '-f', 'lavfi',
      '-i', 'color=c=orange:s=320x240:d=1',
      '-frames:v', '1',
      imgPath,
    ]);
    expect(genImg.exitCode, 0);
    final imgBytes = await File(imgPath).readAsBytes();

    final success = await FFmpegService.updateMp4CoverAndMetadata(
      filePath: mkvPath,
      newCoverBytes: imgBytes,
      replaceVideoFrames: true,
      title: 'MKV Replaced Title',
    );
    expect(success, true);

    final tags = await FFmpegService.readMediaTags(mkvPath);
    expect(tags['title'], 'MKV Replaced Title');

    final frame = await FFmpegService.extractVideoFrame(
      videoPath: mkvPath,
      timestampSeconds: 1.0,
    );
    expect(frame, isNotNull);
    final isBlack = await FFmpegService.isImageVisuallyBlack(frame!);
    expect(isBlack, false);
  });
}
