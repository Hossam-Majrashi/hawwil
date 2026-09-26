import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hawwil/models/merge_media_item.dart';
import 'package:hawwil/services/merge_media_controller.dart';
import 'package:hawwil/services/ffmpeg_service.dart';
import 'package:hawwil/screens/desktop/desktop_home_screen.dart';
import 'package:hawwil/screens/mobile/mobile_home_screen.dart';
import 'package:hawwil/screens/web/web_home_screen.dart';
import 'package:hawwil/screens/desktop/desktop_merge_media_screen.dart';
import 'package:hawwil/screens/mobile/mobile_merge_media_screen.dart';
import 'package:hawwil/screens/web/web_merge_media_screen.dart';
import 'package:hawwil/services/settings_service.dart';
import 'package:hawwil/services/batch_conversion_service.dart';
import 'package:hawwil/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hawwil/models/conversion_item.dart';
import 'package:hawwil/widgets/image_trim_handle.dart';
import 'package:hawwil/widgets/timeline_waveform_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('ar'),
      Locale('en'),
    ],
    locale: const Locale('ar'),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settingsService;
  late BatchConversionService batchService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settingsService = SettingsService();
    await settingsService.init();
    batchService = BatchConversionService();
  });

  group('Equal-size Home Cards Tests', () {
    testWidgets('DesktopHomeScreen renders Start Project and Cover Editor with equal width and height', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            DesktopHomeScreen(
              settingsService: settingsService,
              batchService: batchService,
              onCreateProject: () {},
              onOpenCoverEditor: () {},
              onOpenMergeMedia: () {},
              onOpenSettings: () {},
              onOpenProgress: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      final projectCardFinder = find.ancestor(
        of: find.text('تحويل ملف فردي أو دفعة ملفات بين MP3 و MP4'),
        matching: find.byType(Card),
      );
      final coverCardFinder = find.ancestor(
        of: find.text('عرض واستبدال أو إزالة صورة الغلاف وتعديل الوسوم لملفات MP3 و MP4'),
        matching: find.byType(Card),
      );
      final mergeCardFinder = find.ancestor(
        of: find.text('دمج الصور والفيديوهات في مسار بصري متتابع مع مقطع صوتي مخصص'),
        matching: find.byType(Card),
      );

      expect(projectCardFinder, findsOneWidget);
      expect(coverCardFinder, findsOneWidget);
      expect(mergeCardFinder, findsOneWidget);

      final projectSize = tester.getSize(projectCardFinder);
      final coverSize = tester.getSize(coverCardFinder);

      // Width and Height must be identical
      expect(projectSize.width, equals(coverSize.width));
      expect(projectSize.height, equals(coverSize.height));
    });

    testWidgets('MobileHomeScreen renders action cards with identical heights and widths', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            MobileHomeScreen(
              settingsService: settingsService,
              batchService: batchService,
              onCreateProject: () {},
              onOpenCoverEditor: () {},
              onOpenMergeMedia: () {},
              onOpenSettings: () {},
              onOpenProgress: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      final projectCardFinder = find.ancestor(
        of: find.text('تحويل ملف فردي أو دفعة ملفات بين MP3 و MP4'),
        matching: find.byType(Card),
      );
      final coverCardFinder = find.ancestor(
        of: find.text('عرض واستبدال أو إزالة صورة الغلاف وتعديل الوسوم لملفات MP3 و MP4'),
        matching: find.byType(Card),
      );
      final mergeCardFinder = find.ancestor(
        of: find.text('دمج الصور والفيديوهات في مسار بصري متتابع مع مقطع صوتي مخصص'),
        matching: find.byType(Card),
      );

      expect(projectCardFinder, findsOneWidget);
      expect(coverCardFinder, findsOneWidget);
      expect(mergeCardFinder, findsOneWidget);

      final projectSize = tester.getSize(projectCardFinder);
      final coverSize = tester.getSize(coverCardFinder);

      // Both cards must have identical height and width on mobile
      expect(projectSize.width, equals(coverSize.width));
      expect(projectSize.height, equals(coverSize.height));
    });

    testWidgets('WebHomeScreen renders Start Project and Cover Editor with equal width and height', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            WebHomeScreen(
              settingsService: settingsService,
              batchService: batchService,
              onCreateProject: () {},
              onOpenCoverEditor: () {},
              onOpenMergeMedia: () {},
              onOpenSettings: () {},
              onOpenProgress: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      final projectCardFinder = find.ancestor(
        of: find.text('تحويل ملف فردي أو دفعة ملفات بين MP3 و MP4'),
        matching: find.byType(Card),
      );
      final coverCardFinder = find.ancestor(
        of: find.text('عرض واستبدال أو إزالة صورة الغلاف وتعديل الوسوم لملفات MP3 و MP4'),
        matching: find.byType(Card),
      );
      final mergeCardFinder = find.ancestor(
        of: find.text('دمج الصور والفيديوهات في مسار بصري متتابع مع مقطع صوتي مخصص'),
        matching: find.byType(Card),
      );

      expect(projectCardFinder, findsOneWidget);
      expect(coverCardFinder, findsOneWidget);
      expect(mergeCardFinder, findsOneWidget);

      final projectSize = tester.getSize(projectCardFinder);
      final coverSize = tester.getSize(coverCardFinder);

      // Width and Height must be identical
      expect(projectSize.width, equals(coverSize.width));
      expect(projectSize.height, equals(coverSize.height));
    });
  });

  group('MergeMediaController & Timeline Logic Tests', () {
    test('Items snap onto matching tracks with sequential alignment and default image duration', () {
      final controller = MergeMediaController();

      final img1 = MergeMediaItem(
        id: 'img1',
        path: '/tmp/photo1.jpg',
        name: 'photo1.jpg',
        type: MergeMediaType.image,
        duration: const Duration(seconds: 3),
      );

      final vid1 = MergeMediaItem(
        id: 'vid1',
        path: '/tmp/clip1.mp4',
        name: 'clip1.mp4',
        type: MergeMediaType.video,
        duration: const Duration(seconds: 10),
      );

      final audio1 = MergeMediaItem(
        id: 'aud1',
        path: '/tmp/song.mp3',
        name: 'song.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 30),
      );

      // Add to tracks
      controller.addToTrack(img1, 1);
      controller.addToTrack(vid1, 2);
      controller.addToTrack(audio1, 3);

      expect(controller.visualTimeline.length, equals(2));
      expect(controller.audioTimeline.length, equals(1));

      // Visual items form one combined sequential timeline (3s + 10s = 13s)
      expect(controller.totalVisualDurationSec, equals(13.0));
      expect(controller.totalAudioDurationSec, equals(30.0));
      expect(controller.totalDurationSec, equals(30.0));

      // Image duration adjustment
      final addedImg = controller.visualTimeline.first;
      controller.updateImageDuration(addedImg.id, const Duration(seconds: 5));
      expect(controller.totalVisualDurationSec, equals(15.0));

      // Active item tracking at different playhead positions
      controller.seekTo(2.0); // Inside image (0..5s)
      expect(controller.activeVisualItem?.name, equals('photo1.jpg'));
      expect(controller.activeAudioItem?.name, equals('song.mp3'));

      controller.seekTo(7.0); // Inside video (5..15s)
      expect(controller.activeVisualItem?.name, equals('clip1.mp4'));
      expect(controller.activeAudioItem?.name, equals('song.mp3'));

      controller.dispose();
    });

    test('Reordering visual and audio items adjusts sequence smoothly without gaps', () {
      final controller = MergeMediaController();

      final img1 = MergeMediaItem(
        id: 'img1',
        path: '/tmp/1.jpg',
        name: '1.jpg',
        type: MergeMediaType.image,
        duration: const Duration(seconds: 4),
      );
      final vid1 = MergeMediaItem(
        id: 'vid1',
        path: '/tmp/2.mp4',
        name: '2.mp4',
        type: MergeMediaType.video,
        duration: const Duration(seconds: 6),
      );
      final aud1 = MergeMediaItem(
        id: 'aud1',
        path: '/tmp/a1.mp3',
        name: 'a1.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 15),
      );
      final aud2 = MergeMediaItem(
        id: 'aud2',
        path: '/tmp/a2.mp3',
        name: 'a2.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 20),
      );

      controller.addToTrack(img1, 1);
      controller.addToTrack(vid1, 2);
      controller.addToTrack(aud1, 3);
      controller.addToTrack(aud2, 3);

      expect(controller.visualTimeline[0].name, equals('1.jpg'));
      expect(controller.visualTimeline[1].name, equals('2.mp4'));
      expect(controller.audioTimeline[0].name, equals('a1.mp3'));
      expect(controller.audioTimeline[1].name, equals('a2.mp3'));

      // Move video to index 0 via reorderVisualItem (direct drag reorder)
      controller.reorderVisualItem(1, 0);
      expect(controller.visualTimeline[0].name, equals('2.mp4'));
      expect(controller.visualTimeline[1].name, equals('1.jpg'));
      expect(controller.totalVisualDurationSec, equals(10.0));

      // Move audio 2 to index 0 via reorderAudioItem (direct drag reorder)
      controller.reorderAudioItem(1, 0);
      expect(controller.audioTimeline[0].name, equals('a2.mp3'));
      expect(controller.audioTimeline[1].name, equals('a1.mp3'));
      expect(controller.totalAudioDurationSec, equals(35.0));

      controller.dispose();
    });

    test('Audio-only timeline activates preview and duration correctly without visual clips', () {
      final controller = MergeMediaController();

      final aud1 = MergeMediaItem(
        id: 'aud1',
        path: '/tmp/song.mp3',
        name: 'song.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 42),
      );

      controller.addToTrack(aud1, 3);

      expect(controller.visualTimeline.isEmpty, isTrue);
      expect(controller.audioTimeline.length, equals(1));
      expect(controller.isAudioOnly, isTrue);
      expect(controller.hasContent, isTrue);
      expect(controller.totalDurationSec, equals(42.0));

      controller.seekTo(10.0);
      expect(controller.activeAudioItem?.name, equals('song.mp3'));
      expect(controller.activeVisualItem, isNull);

      controller.dispose();
    });

    test('Sequential clips on a track activate only one clip at a time and calculate precise local offset', () {
      final controller = MergeMediaController();

      final a1 = MergeMediaItem(
        id: 'a1',
        path: '/tmp/clip1.mp3',
        name: 'clip1.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 10),
      );
      final a2 = MergeMediaItem(
        id: 'a2',
        path: '/tmp/clip2.mp3',
        name: 'clip2.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 15),
      );
      final a3 = MergeMediaItem(
        id: 'a3',
        path: '/tmp/clip3.mp3',
        name: 'clip3.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 20),
      );

      controller.addToTrack(a1, 3);
      controller.addToTrack(a2, 3);
      controller.addToTrack(a3, 3);

      expect(controller.totalAudioDurationSec, equals(45.0));

      // At position 4.0: within clip1 (0..10)
      controller.seekTo(4.0);
      expect(controller.activeAudioItem?.name, equals('clip1.mp3'));
      expect(controller.activeAudioItemId, equals(controller.audioTimeline[0].id));
      expect(controller.activeAudioItemStartSec, equals(0.0));
      expect(controller.activeAudioItemOffsetSec, equals(4.0));

      // At position 10.0: boundary into clip2 (10..25)
      controller.seekTo(10.0);
      expect(controller.activeAudioItem?.name, equals('clip2.mp3'));
      expect(controller.activeAudioItemId, equals(controller.audioTimeline[1].id));
      expect(controller.activeAudioItemStartSec, equals(10.0));
      expect(controller.activeAudioItemOffsetSec, equals(0.0));

      // At position 18.5: within clip2 (10..25), offset is 8.5
      controller.seekTo(18.5);
      expect(controller.activeAudioItem?.name, equals('clip2.mp3'));
      expect(controller.activeAudioItemId, equals(controller.audioTimeline[1].id));
      expect(controller.activeAudioItemStartSec, equals(10.0));
      expect(controller.activeAudioItemOffsetSec, equals(8.5));

      // At position 30.0: within clip3 (25..45), offset is 5.0
      controller.seekTo(30.0);
      expect(controller.activeAudioItem?.name, equals('clip3.mp3'));
      expect(controller.activeAudioItemId, equals(controller.audioTimeline[2].id));
      expect(controller.activeAudioItemStartSec, equals(25.0));
      expect(controller.activeAudioItemOffsetSec, equals(5.0));

      controller.dispose();
    });
  });

  group('FFmpegService.mergeMedia End-to-End Test', () {
    test('mergeMedia successfully executes FFmpeg concat of image and audio soundtrack', () async {
      final tempDir = await Directory.systemTemp.createTemp('hawwil_merge_test');
      final outPath = '${tempDir.path}/merged_output.mp4';

      final imgItem = MergeMediaItem(
        id: 'test_img',
        path: 'assets/icon/app_icon.png',
        name: 'app_icon.png',
        type: MergeMediaType.image,
        duration: const Duration(seconds: 2),
      );

      final res = await FFmpegService.mergeMedia(
        visualItems: [imgItem],
        audioItems: [], // Test with silent auto-generated track
        outputPath: outPath,
        targetFormat: 'mp4',
        resolution: '1280x720',
      );

      expect(res.success, isTrue);
      expect(await File(outPath).exists(), isTrue);
      expect(await File(outPath).length(), greaterThan(0));

      await tempDir.delete(recursive: true);
    });

    test('mergeMedia exports video-only project to mp4 without requiring an image', () async {
      final tempDir = await Directory.systemTemp.createTemp('hawwil_video_only_test');
      final vidFile = '${tempDir.path}/test_video.mp4';
      await Process.run('ffmpeg', ['-y', '-f', 'lavfi', '-i', 'testsrc=duration=2:size=320x240:rate=30', vidFile]);
      final outPath = '${tempDir.path}/video_only_output.mp4';

      final vidItem = MergeMediaItem(
        id: 'test_vid_1',
        path: vidFile,
        name: 'test_video.mp4',
        type: MergeMediaType.video,
        duration: const Duration(seconds: 2),
      );

      final res = await FFmpegService.mergeMedia(
        visualItems: [vidItem],
        audioItems: [],
        outputPath: outPath,
        targetFormat: 'mp4',
        resolution: '1280x720',
      );

      expect(res.success, isTrue);
      expect(await File(outPath).exists(), isTrue);
      expect(await File(outPath).length(), greaterThan(0));

      await tempDir.delete(recursive: true);
    });

    test('mergeMedia exports audio-only project to mp3 format without requiring an image', () async {
      final tempDir = await Directory.systemTemp.createTemp('hawwil_audio_only_test');
      final audFile = '${tempDir.path}/test_audio.mp3';
      await Process.run('ffmpeg', ['-y', '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo', '-t', '2', audFile]);
      final outPath = '${tempDir.path}/audio_only_output.mp3';

      final audItem = MergeMediaItem(
        id: 'test_aud_1',
        path: audFile,
        name: 'test_audio.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 2),
      );

      final res = await FFmpegService.mergeMedia(
        visualItems: [],
        audioItems: [audItem],
        outputPath: outPath,
        targetFormat: 'mp3',
      );

      expect(res.success, isTrue);
      expect(await File(outPath).exists(), isTrue);
      expect(await File(outPath).length(), greaterThan(0));

      await tempDir.delete(recursive: true);
    });

    test('mergeMedia exports audio-only project to mp4 video format without requiring an image', () async {
      final tempDir = await Directory.systemTemp.createTemp('hawwil_audio_to_video_test');
      final audFile = '${tempDir.path}/test_audio.mp3';
      await Process.run('ffmpeg', ['-y', '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo', '-t', '2', audFile]);
      final outPath = '${tempDir.path}/audio_to_video_output.mp4';

      final audItem = MergeMediaItem(
        id: 'test_aud_2',
        path: audFile,
        name: 'test_audio.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 2),
      );

      final res = await FFmpegService.mergeMedia(
        visualItems: [],
        audioItems: [audItem],
        outputPath: outPath,
        targetFormat: 'mp4',
        resolution: '1280x720',
      );

      expect(res.success, isTrue);
      expect(await File(outPath).exists(), isTrue);
      expect(await File(outPath).length(), greaterThan(0));

      await tempDir.delete(recursive: true);
    });

    test('MergeMediaController validates audio-only and video-only project content without images', () {
      final controller = MergeMediaController();

      // Initially empty
      expect(controller.hasContent, isFalse);

      // Audio-only
      final audItem = MergeMediaItem(
        id: 'aud_ctrl',
        path: '/tmp/test.mp3',
        name: 'test.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 5),
      );
      controller.addToTrack(audItem, 3);
      expect(controller.hasContent, isTrue);
      expect(controller.isAudioOnly, isTrue);
      expect(controller.visualTimeline.isEmpty, isTrue);

      // Video-only (no images)
      controller.audioTimeline.clear();
      expect(controller.hasContent, isFalse);

      final vidItem = MergeMediaItem(
        id: 'vid_ctrl',
        path: '/tmp/test.mp4',
        name: 'test.mp4',
        type: MergeMediaType.video,
        duration: const Duration(seconds: 10),
      );
      controller.addToTrack(vidItem, 2);
      expect(controller.hasContent, isTrue);
      expect(controller.isAudioOnly, isFalse);
      expect(controller.visualTimeline.any((i) => i.isImage), isFalse);

      controller.dispose();
    });
  });

  group('Merge Media Screen UI Tests (LTR Timeline & No Arrow Buttons)', () {
    testWidgets('DesktopMergeMediaScreen forces LTR timeline and has no track arrow buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            DesktopMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      // Arrow buttons for moving items left/right MUST NOT exist
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      // Verify that LTR Directionality widgets exist for the timeline axis and preview scrubber
      final ltrWidgets = tester.widgetList<Directionality>(
        find.byWidgetPredicate(
          (widget) => widget is Directionality && widget.textDirection == TextDirection.ltr,
        ),
      );
      expect(ltrWidgets.length, greaterThanOrEqualTo(2));
    });

    testWidgets('MobileMergeMediaScreen forces LTR timeline and has no track arrow buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            MobileMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      // Arrow buttons for moving items left/right MUST NOT exist
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      // Verify that LTR Directionality widgets exist for the timeline axis and preview scrubber
      final ltrWidgets = tester.widgetList<Directionality>(
        find.byWidgetPredicate(
          (widget) => widget is Directionality && widget.textDirection == TextDirection.ltr,
        ),
      );
      expect(ltrWidgets.length, greaterThanOrEqualTo(2));
    });

    testWidgets('WebMergeMediaScreen forces LTR timeline and has no track arrow buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            WebMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      // Arrow buttons for moving items left/right MUST NOT exist
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      // Verify that LTR Directionality widgets exist for the timeline axis and preview scrubber
      final ltrWidgets = tester.widgetList<Directionality>(
        find.byWidgetPredicate(
          (widget) => widget is Directionality && widget.textDirection == TextDirection.ltr,
        ),
      );
      expect(ltrWidgets.length, greaterThanOrEqualTo(2));
    });
  });

  group('Timeline Zoom & Rescaling Tests', () {
    testWidgets('DesktopMergeMediaScreen zoom controls change zoom percentage and ruler spacing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            DesktopMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      // Default zoom is 100%
      expect(find.text('100%'), findsOneWidget);

      // Find zoom '+' icon in the timeline toolbar and tap it
      final zoomInIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.add_rounded && (w.size == 14.0 || w.size == 13.0),
      );
      await tester.tap(zoomInIcon);
      await tester.pump(const Duration(milliseconds: 100));

      // Zoom should now be 125%
      expect(find.text('125%'), findsOneWidget);

      // Tap zoom '-' button
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      // Zoom back to 100%
      expect(find.text('100%'), findsOneWidget);

      // Tap zoom '-' again to go to 80%
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('80%'), findsOneWidget);

      // Tap the percentage text to reset to 100%
      final percentResetBtn = find.text('80%');
      await tester.tap(percentResetBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('MobileMergeMediaScreen zoom controls change zoom percentage', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            MobileMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(find.text('100%'), findsOneWidget);

      final zoomInIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.add_rounded && (w.size == 14.0 || w.size == 13.0),
      );
      await tester.tap(zoomInIcon);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('125%'), findsOneWidget);
    });

    testWidgets('WebMergeMediaScreen zoom controls change zoom percentage', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            WebMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(find.text('100%'), findsOneWidget);

      final zoomInIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.add_rounded && (w.size == 14.0 || w.size == 13.0),
      );
      await tester.tap(zoomInIcon);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('125%'), findsOneWidget);
    });
  });

  group('Timecode HH:MM:SS:FF Format Tests', () {
    test('MergeMediaController formats durations into full timecode HH:MM:SS:FF', () {
      final controller = MergeMediaController();

      // 0 seconds on empty timeline (audio-only/no visual clips -> frames is 00)
      expect(controller.formatTimecode(0.0), equals('00:00:00:00'));

      // 64.02 seconds (1 minute, 4 seconds, 0 frames when audio-only)
      expect(controller.formatTimecode(64.02), equals('00:01:04:00'));

      // With video / visual clips, default output frame rate is 30 fps
      controller.visualTimeline.add(
        MergeMediaItem(
          id: 'v1',
          path: '/dummy.mp4',
          name: 'Video',
          type: MergeMediaType.video,
          duration: const Duration(seconds: 10),
          fps: 30.0,
        ),
      );
      expect(controller.projectFps, equals(30.0));

      // At 1.5 seconds: 1 sec + 0.5 * 30 = 15 frames
      expect(controller.formatTimecode(1.5), equals('00:00:01:15'));

      // At 3661 seconds: 1 hour, 1 minute, 1 second, 0 frames
      expect(controller.formatTimecode(3661.0), equals('01:01:01:00'));

      // Static method with custom fps (e.g. 24 fps)
      expect(MergeMediaController.formatTimecodeStatic(1.5, fps: 24.0), equals('00:00:01:12'));

      // Audio-only timeline has projectFps 0.0 and always renders :00 frames segment
      controller.visualTimeline.clear();
      controller.audioTimeline.add(
        MergeMediaItem(
          id: 'a1',
          path: '/dummy.mp3',
          name: 'Audio',
          type: MergeMediaType.audio,
          duration: const Duration(seconds: 60),
        ),
      );
      expect(controller.isAudioOnly, isTrue);
      expect(controller.projectFps, equals(0.0));
      expect(controller.formatTimecode(1.5), equals('00:00:01:00'));
    });

    testWidgets('DesktopMergeMediaScreen displays ruler and preview counter in HH:MM:SS:FF format', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            DesktopMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      // Ruler displays initial 00:00:00:00 tick mark
      expect(find.text('00:00:00:00'), findsWidgets);

      // Ruler displays subsequent tick marks in full HH:MM:SS:FF format
      expect(find.text('00:00:05:00'), findsWidgets);

      // Preview player counter displays in HH:MM:SS:FF / HH:MM:SS:FF format
      expect(find.text('00:00:00:00 / 00:00:00:00'), findsWidgets);
    });

    testWidgets('MobileMergeMediaScreen displays ruler and preview counter in HH:MM:SS:FF format', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            MobileMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(find.text('00:00:00:00'), findsWidgets);
      expect(find.text('00:00:00:00 / 00:00:00:00'), findsWidgets);
    });

    testWidgets('WebMergeMediaScreen displays ruler and preview counter in HH:MM:SS:FF format', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            WebMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(find.text('00:00:00:00'), findsWidgets);
      expect(find.text('00:00:05:00'), findsWidgets);
      expect(find.text('00:00:00:00 / 00:00:00:00'), findsWidgets);
    });
  });

  group('Ctrl+Scroll vs Plain Scroll Timeline Zoom Tests', () {
    testWidgets('DesktopMergeMediaScreen zooms ONLY when Ctrl is pressed during scroll', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            DesktopMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      // Default zoom is 100%
      expect(find.text('100%'), findsOneWidget);

      final trackAreaFinder = find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(trackAreaFinder, findsOneWidget);
      final trackCenter = tester.getCenter(trackAreaFinder);

      // 1. Plain scroll (without Ctrl): MUST NOT ZOOM
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: trackCenter,
          scrollDelta: const Offset(0, -100), // scroll up
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Zoom level must remain 100%
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('125%'), findsNothing);

      // 2. Ctrl + Scroll: MUST ZOOM
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: trackCenter,
          scrollDelta: const Offset(0, -100), // scroll up = zoom in
        ),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 100));

      // Zoom level should now be 125%
      expect(find.text('125%'), findsOneWidget);
    });
  });

  group('Timeline Kdenlive-style Clip Rescaling Tests', () {
    test('MergeMediaController single shared pixelsPerSecond drives scale', () {
      final controller = MergeMediaController();
      expect(controller.pixelsPerSecond, equals(50.0));
      expect(controller.zoomLevel, equals(1.0));
      expect(controller.timelineScale, equals(50.0));

      controller.setZoomLevel(1.5);
      expect(controller.pixelsPerSecond, equals(75.0));
      expect(controller.timelineScale, equals(75.0));

      controller.setPixelsPerSecond(100.0);
      expect(controller.pixelsPerSecond, equals(100.0));
      expect(controller.zoomLevel, equals(2.0));
    });

    testWidgets('DesktopMergeMediaScreen resizes clips in direct proportion to zoom', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      final controller = MergeMediaController();
      final item = MergeMediaItem(
        id: 'test_clip_1',
        path: '/dummy.jpg',
        name: 'Slide.jpg',
        type: MergeMediaType.image,
        duration: const Duration(seconds: 4),
      );
      controller.visualTimeline.add(item);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            DesktopMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
              controller: controller,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      // At 100% zoom: 4 seconds * 50 px/sec = 200px width
      final clipFinder = find.byKey(const ValueKey('timeline_clip_test_clip_1'));
      expect(clipFinder, findsOneWidget);
      final size100 = tester.getSize(clipFinder);
      expect(size100.width, equals(200.0));

      // Tap zoom in (+) button
      final zoomInBtn = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.add_rounded && (w.size == 14.0 || w.size == 13.0),
      );
      await tester.tap(zoomInBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // At 125% zoom (62.5 px/sec): 4 seconds * 62.5 = 250px width
      final size125 = tester.getSize(clipFinder);
      expect(size125.width, equals(250.0));
    });

    testWidgets('MobileMergeMediaScreen resizes clips in direct proportion to zoom', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      final controller = MergeMediaController();
      final item = MergeMediaItem(
        id: 'mobile_clip_1',
        path: '/dummy.jpg',
        name: 'Mobile.jpg',
        type: MergeMediaType.image,
        duration: const Duration(seconds: 3),
      );
      controller.visualTimeline.add(item);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            MobileMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
              controller: controller,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      // At 100% zoom: 3 seconds * 50 px/sec = 150px width
      final clipFinder = find.byKey(const ValueKey('timeline_clip_mobile_clip_1'));
      expect(clipFinder, findsOneWidget);
      final size100 = tester.getSize(clipFinder);
      expect(size100.width, equals(150.0));

      // Tap zoom in (+) button
      final zoomInBtn = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.add_rounded && (w.size == 14.0 || w.size == 13.0),
      );
      await tester.tap(zoomInBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // At 125% zoom: 3 seconds * 62.5 = 187.5px width
      final size125 = tester.getSize(clipFinder);
      expect(size125.width, equals(187.5));
    });

    testWidgets('WebMergeMediaScreen resizes clips in direct proportion to zoom', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final controller = MergeMediaController();
      final item = MergeMediaItem(
        id: 'web_clip_1',
        path: '/dummy.jpg',
        name: 'Web.jpg',
        type: MergeMediaType.image,
        duration: const Duration(seconds: 5),
      );
      controller.visualTimeline.add(item);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            WebMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
              controller: controller,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      // At 100% zoom: 5 seconds * 50 px/sec = 250px width
      final clipFinder = find.byKey(const ValueKey('timeline_clip_web_clip_1'));
      expect(clipFinder, findsOneWidget);
      final size100 = tester.getSize(clipFinder);
      expect(size100.width, equals(250.0));

      // Tap zoom in (+) button
      final zoomInBtn = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.add_rounded && (w.size == 14.0 || w.size == 13.0),
      );
      await tester.tap(zoomInBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // At 125% zoom: 5 seconds * 62.5 = 312.5px width
      final size125 = tester.getSize(clipFinder);
      expect(size125.width, equals(312.5));
    });
  });

  group('Export Format Picker Tests', () {
    testWidgets('DesktopMergeMediaScreen export format picker includes all 10 video formats and 6 audio formats', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final controller = MergeMediaController();
      controller.audioTimeline.add(
        MergeMediaItem(
          id: 'aud_item',
          path: '/dummy.mp3',
          name: 'audio.mp3',
          type: MergeMediaType.audio,
          duration: const Duration(seconds: 5),
        ),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            DesktopMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
              controller: controller,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      final exportBtn = find.byIcon(Icons.movie_creation_rounded);
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);
      final dropdownWidget = tester.widget<DropdownButton<String>>(dropdownFinder);

      final items = dropdownWidget.items ?? [];
      final formatValues = items.map((i) => i.value).toSet();
      expect(formatValues.length, equals(16));
      for (final fmt in ConversionItem.supportedVideoFormats) {
        expect(formatValues.contains(fmt), isTrue, reason: 'Missing video format $fmt');
      }
      for (final fmt in ConversionItem.supportedAudioOutputFormats) {
        expect(formatValues.contains(fmt), isTrue, reason: 'Missing audio format $fmt');
      }
    });

    testWidgets('MobileMergeMediaScreen export format picker includes all 10 video formats and 6 audio formats', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      final controller = MergeMediaController();
      controller.audioTimeline.add(
        MergeMediaItem(
          id: 'aud_mobile',
          path: '/dummy.mp3',
          name: 'audio.mp3',
          type: MergeMediaType.audio,
          duration: const Duration(seconds: 5),
        ),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            MobileMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
              controller: controller,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      final exportBtn = find.byIcon(Icons.movie_creation_rounded);
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);
      final dropdownWidget = tester.widget<DropdownButton<String>>(dropdownFinder);

      final items = dropdownWidget.items ?? [];
      final formatValues = items.map((i) => i.value).toSet();
      expect(formatValues.length, equals(16));
      for (final fmt in ConversionItem.supportedVideoFormats) {
        expect(formatValues.contains(fmt), isTrue);
      }
      for (final fmt in ConversionItem.supportedAudioOutputFormats) {
        expect(formatValues.contains(fmt), isTrue);
      }
    });

    testWidgets('WebMergeMediaScreen export format picker includes all 10 video formats and 6 audio formats', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final controller = MergeMediaController();
      controller.audioTimeline.add(
        MergeMediaItem(
          id: 'aud_web',
          path: '/dummy.mp3',
          name: 'audio.mp3',
          type: MergeMediaType.audio,
          duration: const Duration(seconds: 5),
        ),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            WebMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
              controller: controller,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      final exportBtn = find.byIcon(Icons.movie_creation_rounded);
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);
      final dropdownWidget = tester.widget<DropdownButton<String>>(dropdownFinder);

      final items = dropdownWidget.items ?? [];
      final formatValues = items.map((i) => i.value).toSet();
      expect(formatValues.length, equals(16));
      for (final fmt in ConversionItem.supportedVideoFormats) {
        expect(formatValues.contains(fmt), isTrue);
      }
      for (final fmt in ConversionItem.supportedAudioOutputFormats) {
        expect(formatValues.contains(fmt), isTrue);
      }
    });
  });

  group('Image Clip Drag Trim Tests', () {
    testWidgets('ImageTrimHandle dragging right handle extends and shortens duration', (tester) async {
      final item = MergeMediaItem(
        id: 'img1',
        path: '/tmp/test.jpg',
        name: 'test.jpg',
        type: MergeMediaType.image,
        duration: const Duration(seconds: 3),
      );

      Duration? updatedDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 60,
                child: ImageTrimHandle(
                  item: item,
                  pixelsPerSecond: 50.0,
                  isLeft: false, // Right handle
                  color: Colors.blue,
                  onDurationChanged: (dur) {
                    updatedDuration = dur;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final handleFinder = find.byType(ImageTrimHandle);
      expect(handleFinder, findsOneWidget);

      // Drag right by 50 pixels (+1 second at 50 px/s)
      await tester.drag(handleFinder, const Offset(50, 0));
      await tester.pump();
      expect(updatedDuration, isNotNull);
      expect(updatedDuration!.inSeconds, equals(4));

      // Drag left by 100 pixels (-2 seconds from 3s start = 1 second)
      await tester.drag(handleFinder, const Offset(-100, 0));
      await tester.pump();
      expect(updatedDuration!.inSeconds, equals(1));
    });

    testWidgets('ImageTrimHandle dragging left handle extends and shortens duration', (tester) async {
      final item = MergeMediaItem(
        id: 'img2',
        path: '/tmp/test.jpg',
        name: 'test.jpg',
        type: MergeMediaType.image,
        duration: const Duration(seconds: 4),
      );

      Duration? updatedDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 60,
                child: ImageTrimHandle(
                  item: item,
                  pixelsPerSecond: 50.0,
                  isLeft: true, // Left handle: dragging left (negative dx) extends duration
                  color: Colors.blue,
                  onDurationChanged: (dur) {
                    updatedDuration = dur;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final handleFinder = find.byType(ImageTrimHandle);
      expect(handleFinder, findsOneWidget);

      // Drag left by 50 pixels (delta dx = -50, so deltaSec = -(-50)/50 = +1 second => 5 seconds)
      await tester.drag(handleFinder, const Offset(-50, 0));
      await tester.pump();
      expect(updatedDuration, isNotNull);
      expect(updatedDuration!.inSeconds, equals(5));
    });

    testWidgets('DesktopMergeMediaScreen image clips have ImageTrimHandle on left and right edges', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final controller = MergeMediaController();
      final item = MergeMediaItem(
        id: 'img_handle_test',
        path: '/tmp/test.jpg',
        name: 'handle_test.jpg',
        type: MergeMediaType.image,
        duration: const Duration(seconds: 4),
      );
      controller.visualTimeline.add(item);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            DesktopMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
              controller: controller,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      // Find ImageTrimHandle widgets in the timeline
      final handles = find.byType(ImageTrimHandle);
      expect(handles, findsNWidgets(2)); // Left and Right handles

      // Drag the right handle (second handle) to extend duration
      final rightHandle = handles.last;
      await tester.drag(rightHandle, const Offset(100, 0)); // +2 seconds at 50 px/s
      await tester.pump();

      expect(controller.visualTimeline.first.durationInSeconds, greaterThan(4.0));
    });
  });

  group('Added Media Box Thumbnail & Waveform Tests', () {
    testWidgets('DesktopMergeMediaScreen displays real thumbnail for video and waveform for audio in media pool', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final controller = MergeMediaController();

      // Create a 1x1 PNG byte array for video thumbnail
      final dummyThumbnail = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      final vidItem = MergeMediaItem(
        id: 'pool_vid',
        path: '/tmp/clip.mp4',
        name: 'clip.mp4',
        type: MergeMediaType.video,
        duration: const Duration(seconds: 10),
        thumbnailBytes: dummyThumbnail,
      );

      final audItem = MergeMediaItem(
        id: 'pool_aud',
        path: '/tmp/sound.mp3',
        name: 'sound.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 30),
      );

      controller.mediaPool.addAll([vidItem, audItem]);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            DesktopMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
              controller: controller,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      // Video item displays thumbnail via Image.memory
      expect(find.byType(Image), findsWidgets);

      // Audio item displays waveform via CustomPaint with TimelineWaveformPainter
      final waveformFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TimelineWaveformPainter,
      );
      expect(waveformFinder, findsWidgets);
    });

    testWidgets('MobileMergeMediaScreen displays real thumbnail for video and waveform for audio in media pool', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      final controller = MergeMediaController();

      final dummyThumbnail = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);

      final vidItem = MergeMediaItem(
        id: 'mobile_pool_vid',
        path: '/tmp/clip.mp4',
        name: 'clip.mp4',
        type: MergeMediaType.video,
        duration: const Duration(seconds: 10),
        thumbnailBytes: dummyThumbnail,
      );

      final audItem = MergeMediaItem(
        id: 'mobile_pool_aud',
        path: '/tmp/sound.mp3',
        name: 'sound.mp3',
        type: MergeMediaType.audio,
        duration: const Duration(seconds: 30),
      );

      controller.mediaPool.addAll([vidItem, audItem]);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            MobileMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
              controller: controller,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(find.byType(Image), findsWidgets);

      final waveformFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is TimelineWaveformPainter,
      );
      expect(waveformFinder, findsWidgets);
    });

    test('MergeMediaController safe disposal prevents late callback assertions', () {
      final controller = MergeMediaController();
      expect(controller.isDisposed, isFalse);

      controller.dispose();
      expect(controller.isDisposed, isTrue);

      // Calling notifyListeners or cancelExport after dispose should be safely ignored and not throw
      expect(() => controller.notifyListeners(), returnsNormally);
      expect(() => controller.cancelExport(), returnsNormally);
    });

    testWidgets('DesktopMergeMediaScreen empty media pool does not overflow under constrained height', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 350));
      final controller = MergeMediaController();

      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            DesktopMergeMediaScreen(
              onBack: () {},
              settingsService: settingsService,
              controller: controller,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.drive_folder_upload_rounded), findsOneWidget);
    });
  });
}

