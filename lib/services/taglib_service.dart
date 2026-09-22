import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_taglib/flutter_taglib.dart';
import 'id3_parser.dart';

class AudioMetadataResult {
  final String title;
  final String artist;
  final String album;
  final int year;
  final String genre;
  final Duration duration;
  final int bitrate;
  final bool hasCover;
  final Uint8List? coverBytes;
  final String? coverMimeType;
  final bool success;
  final String? error;

  AudioMetadataResult({
    this.title = '',
    this.artist = '',
    this.album = '',
    this.year = 0,
    this.genre = '',
    this.duration = Duration.zero,
    this.bitrate = 0,
    this.hasCover = false,
    this.coverBytes,
    this.coverMimeType,
    this.success = true,
    this.error,
  });
}

class TagLibService {
  static bool get isSupported {
    if (kIsWeb) return false;
    try {
      return TagLibFile.isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Read metadata and embedded cover art from an MP3 file
  static Future<AudioMetadataResult> readMetadata(String filePath) async {
    if (kIsWeb) {
      return AudioMetadataResult(
        title: filePath.split('/').last.split('\\').last,
        success: true,
      );
    }

    try {
      final file = TagLibFile.open(filePath);
      if (file == null) {
        // Fallback to pure Dart Id3Parser
        try {
          final rawBytes = await File(filePath).readAsBytes();
          final parsed = Id3Parser.parse(rawBytes);
          if (parsed.hasCover || parsed.title.isNotEmpty) {
            return parsed;
          }
        } catch (_) {}

        return AudioMetadataResult(
          success: false,
          error: TagLibFile.lastError ?? 'Could not open file with TagLib',
        );
      }

      final title = file.title;
      final artist = file.artist;
      final album = file.album;
      final year = file.year;
      final genre = file.genre;
      final duration = file.duration;
      final bitrate = file.bitrate;

      Uint8List? coverBytes;
      String? mimeType;
      bool hasCover = false;

      final pictures = file.pictures;
      if (pictures.isNotEmpty) {
        final pic = pictures.first;
        if (pic.bytes.isNotEmpty) {
          coverBytes = Uint8List.fromList(pic.bytes);
          mimeType = pic.mimeType;
          hasCover = true;
        }
      }

      file.close();

      if (!hasCover) {
        try {
          final rawBytes = await File(filePath).readAsBytes();
          final parsed = Id3Parser.parse(rawBytes);
          if (parsed.hasCover && parsed.coverBytes != null) {
            coverBytes = parsed.coverBytes;
            mimeType = parsed.coverMimeType;
            hasCover = true;
          }
        } catch (_) {}
      }

      return AudioMetadataResult(
        title: title,
        artist: artist,
        album: album,
        year: year,
        genre: genre,
        duration: duration,
        bitrate: bitrate,
        hasCover: hasCover,
        coverBytes: coverBytes,
        coverMimeType: mimeType,
        success: true,
      );
    } catch (e) {
      debugPrint('TagLibService.readMetadata error: $e');
      return AudioMetadataResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Parse metadata and cover art directly from raw bytes (universal / Web)
  static AudioMetadataResult readMetadataFromBytes(Uint8List bytes) {
    return Id3Parser.parse(bytes);
  }

  /// Update cover art and/or metadata tags in an MP3 file in-place
  static Future<bool> updateCoverAndMetadata({
    required String filePath,
    Uint8List? newCoverBytes,
    String? mimeType,
    bool removeCover = false,
    String? title,
    String? artist,
    String? album,
  }) async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        await TagLibFile.requestWritePermission(filePath);
      }

      final file = TagLibFile.open(filePath);
      if (file == null) {
        debugPrint('TagLibService.update: open failed: ${TagLibFile.lastError}');
        return false;
      }

      if (title != null) file.title = title;
      if (artist != null) file.artist = artist;
      if (album != null) file.album = album;

      if (removeCover) {
        file.setPictures([]);
      } else if (newCoverBytes != null && newCoverBytes.isNotEmpty) {
        final detectedMime = mimeType ?? _detectMimeType(newCoverBytes);
        file.setPictures([
          Picture(
            bytes: newCoverBytes,
            mimeType: detectedMime,
            pictureType: 'Front Cover',
            description: 'Cover',
          ),
        ]);
      }

      final saved = file.save();
      file.close();
      return saved;
    } catch (e) {
      debugPrint('TagLibService.updateCoverAndMetadata error: $e');
      return false;
    }
  }

  static String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 8) {
      // PNG signature: 89 50 4E 47 0D 0A 1A 0A
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
      // JPEG signature: FF D8 FF
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'image/jpeg';
      }
      // WEBP signature: RIFF....WEBP
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46) {
        return 'image/webp';
      }
    }
    return 'image/jpeg';
  }
}
