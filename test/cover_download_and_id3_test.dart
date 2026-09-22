import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hawwil/l10n/app_localizations.dart';
import 'package:hawwil/services/cover_download_service.dart';
import 'package:hawwil/services/id3_parser.dart';

void main() {
  group('CoverDownloadService MIME and Extension Detection', () {
    test('detects PNG image bytes and extension', () {
      final pngHeader = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00,
      ]);
      expect(CoverDownloadService.detectMimeType(pngHeader), 'image/png');
      expect(CoverDownloadService.detectExtension(pngHeader), '.png');
    });

    test('detects JPEG image bytes and extension', () {
      final jpegHeader = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46,
      ]);
      expect(CoverDownloadService.detectMimeType(jpegHeader), 'image/jpeg');
      expect(CoverDownloadService.detectExtension(jpegHeader), '.jpg');
    });

    test('detects WebP image bytes and extension', () {
      final webpHeader = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x20, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
      ]);
      expect(CoverDownloadService.detectMimeType(webpHeader), 'image/webp');
      expect(CoverDownloadService.detectExtension(webpHeader), '.webp');
    });

    test('falls back to default JPEG for unknown image signatures', () {
      final unknown = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04]);
      expect(CoverDownloadService.detectMimeType(unknown), 'image/jpeg');
      expect(CoverDownloadService.detectExtension(unknown), '.jpg');
    });
  });

  group('AppLocalizations Download Keys', () {
    test('contains Arabic cover download translations', () {
      final l10n = AppLocalizations(const Locale('ar'));
      expect(l10n.tr('downloadCover'), 'تنزيل الغلاف');
      expect(l10n.tr('coverDownloaded'), 'تم تنزيل صورة الغلاف بنجاح');
      expect(l10n.tr('coverDownloadFailed'), 'تعذر تنزيل صورة الغلاف');
      expect(l10n.tr('downloadCoverTooltip'), 'تنزيل صورة الغلاف الحالية');
    });

    test('contains English cover download translations', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.tr('downloadCover'), 'Download Cover');
      expect(l10n.tr('coverDownloaded'), 'Cover art downloaded successfully');
      expect(l10n.tr('coverDownloadFailed'), 'Failed to download cover art');
      expect(l10n.tr('downloadCoverTooltip'), 'Download current cover art');
    });
  });

  group('Id3Parser APIC extraction', () {
    test('extracts APIC cover art and text metadata from synthesized ID3v2.3 bytes', () {
      // Create simulated JPEG image bytes
      final dummyJpeg = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46,
        0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
        0xFF, 0xD9,
      ]);

      // Build APIC frame payload
      // Byte 0: text encoding (0 = ISO-8859-1)
      // MIME: "image/jpeg\0"
      // Picture type: 0x03 (Front cover)
      // Description: "Cover\0"
      // Image data
      final apicPayload = <int>[
        0, // encoding
        ...ascii.encode('image/jpeg'), 0, // mime
        3, // front cover
        ...ascii.encode('Cover'), 0, // description
        ...dummyJpeg,
      ];

      // APIC frame header: 'APIC' (4 bytes), size (4 bytes), flags (2 bytes)
      final apicHeader = <int>[
        ...ascii.encode('APIC'),
        (apicPayload.length >> 24) & 0xFF,
        (apicPayload.length >> 16) & 0xFF,
        (apicPayload.length >> 8) & 0xFF,
        apicPayload.length & 0xFF,
        0, 0, // flags
      ];

      // TIT2 frame (Title): 'Hawwil Song'
      final titleText = utf8.encode('Hawwil Song');
      final tit2Payload = [3, ...titleText]; // 3 = UTF-8
      final tit2Header = <int>[
        ...ascii.encode('TIT2'),
        (tit2Payload.length >> 24) & 0xFF,
        (tit2Payload.length >> 16) & 0xFF,
        (tit2Payload.length >> 8) & 0xFF,
        tit2Payload.length & 0xFF,
        0, 0,
      ];

      final frames = <int>[
        ...apicHeader,
        ...apicPayload,
        ...tit2Header,
        ...tit2Payload,
      ];

      // ID3v2 header: 'ID3', version 3, 0, flags 0, synchsafe size
      final tagLen = frames.length;
      final synchsafe = [
        (tagLen >> 21) & 0x7F,
        (tagLen >> 14) & 0x7F,
        (tagLen >> 7) & 0x7F,
        tagLen & 0x7F,
      ];

      final mp3Bytes = Uint8List.fromList([
        0x49, 0x44, 0x33, // 'ID3'
        3, 0, // version 2.3
        0, // flags
        ...synchsafe,
        ...frames,
        0xFF, 0xFB, 0x90, 0x64, // MPEG audio sync frame
      ]);

      final result = Id3Parser.parse(mp3Bytes);

      expect(result.success, isTrue);
      expect(result.hasCover, isTrue);
      expect(result.coverBytes, isNotNull);
      expect(result.coverBytes!.length, dummyJpeg.length);
      expect(result.coverBytes!, dummyJpeg);
      expect(result.coverMimeType, 'image/jpeg');
      expect(result.title, 'Hawwil Song');
    });
  });
}
