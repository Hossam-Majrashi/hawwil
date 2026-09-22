import 'dart:convert';
import 'dart:typed_data';
import 'taglib_service.dart';

/// Pure Dart ID3v2 parser for extracting metadata tags and embedded APIC cover art
/// from raw MP3 bytes. Works universally on Web, Mobile, and Desktop without native dependencies.
class Id3Parser {
  /// Parses ID3v2.2, ID3v2.3, and ID3v2.4 tags directly from raw MP3 bytes.
  static AudioMetadataResult parse(Uint8List bytes) {
    if (bytes.length < 10) {
      return AudioMetadataResult(success: false, error: 'File too small');
    }

    // Check "ID3" identifier at offset 0
    if (bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) {
      return AudioMetadataResult(success: true, hasCover: false);
    }

    final versionMajor = bytes[3]; // 2, 3, or 4
    final flags = bytes[5];
    final tagSize = _decodeSynchsafe(bytes, 6);

    if (tagSize <= 0) {
      return AudioMetadataResult(success: true, hasCover: false);
    }

    final tagEnd = (10 + tagSize).clamp(0, bytes.length);

    int pos = 10;
    // Check extended header flag (bit 6: 0x40)
    if ((flags & 0x40) != 0 && pos + 4 <= tagEnd) {
      if (versionMajor == 3) {
        final extSize = (bytes[pos] << 24) |
            (bytes[pos + 1] << 16) |
            (bytes[pos + 2] << 8) |
            bytes[pos + 3];
        pos += 4 + extSize;
      } else if (versionMajor == 4) {
        final extSize = _decodeSynchsafe(bytes, pos);
        pos += extSize;
      }
    }

    String title = '';
    String artist = '';
    String album = '';
    Uint8List? coverBytes;
    String? coverMime;
    bool hasCover = false;

    // Parse frames
    while (pos < tagEnd) {
      // If zero padding reached, stop
      if (bytes[pos] == 0) break;

      String frameId = '';
      int frameSize = 0;
      int headerSize = 0;

      if (versionMajor == 2) {
        if (pos + 6 > tagEnd) break;
        frameId = String.fromCharCodes(bytes.sublist(pos, pos + 3));
        frameSize = (bytes[pos + 3] << 16) | (bytes[pos + 4] << 8) | bytes[pos + 5];
        headerSize = 6;
      } else {
        if (pos + 10 > tagEnd) break;
        frameId = String.fromCharCodes(bytes.sublist(pos, pos + 4));
        if (versionMajor == 4) {
          frameSize = _decodeSynchsafe(bytes, pos + 4);
        } else {
          // ID3v2.3 standard 32-bit int
          frameSize = (bytes[pos + 4] << 24) |
              (bytes[pos + 5] << 16) |
              (bytes[pos + 6] << 8) |
              bytes[pos + 7];
        }
        headerSize = 10;
      }

      if (frameSize <= 0 || pos + headerSize + frameSize > tagEnd) {
        break;
      }

      final dataStart = pos + headerSize;
      final dataEnd = dataStart + frameSize;
      final frameData = bytes.sublist(dataStart, dataEnd);

      if (frameId == 'APIC' || frameId == 'PIC') {
        final picResult = _extractPicture(frameData);
        if (picResult != null) {
          coverBytes = picResult.bytes;
          coverMime = picResult.mime;
          hasCover = true;
        }
      } else if (frameId == 'TIT2' || frameId == 'TT2') {
        title = _decodeTextFrame(frameData);
      } else if (frameId == 'TPE1' || frameId == 'TP1') {
        artist = _decodeTextFrame(frameData);
      } else if (frameId == 'TALB' || frameId == 'TAL') {
        album = _decodeTextFrame(frameData);
      }

      pos = dataEnd;
    }

    return AudioMetadataResult(
      title: title,
      artist: artist,
      album: album,
      hasCover: hasCover,
      coverBytes: coverBytes,
      coverMimeType: coverMime,
      success: true,
    );
  }

  static int _decodeSynchsafe(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return 0;
    return ((bytes[offset] & 0x7F) << 21) |
        ((bytes[offset + 1] & 0x7F) << 14) |
        ((bytes[offset + 2] & 0x7F) << 7) |
        (bytes[offset + 3] & 0x7F);
  }

  static String _decodeTextFrame(Uint8List data) {
    if (data.isEmpty) return '';
    final encoding = data[0];
    final textBytes = data.sublist(1);
    try {
      switch (encoding) {
        case 0: // ISO-8859-1
          return latin1.decode(textBytes).replaceAll('\x00', '').trim();
        case 1: // UTF-16 with BOM
        case 2: // UTF-16BE without BOM
          if (textBytes.length >= 2) {
            final isBE = (textBytes[0] == 0xFE && textBytes[1] == 0xFF);
            final isLE = (textBytes[0] == 0xFF && textBytes[1] == 0xFE);
            final start = (isBE || isLE) ? 2 : 0;
            final charCodes = <int>[];
            for (int i = start; i + 1 < textBytes.length; i += 2) {
              final code = isBE
                  ? (textBytes[i] << 8) | textBytes[i + 1]
                  : (textBytes[i + 1] << 8) | textBytes[i];
              if (code != 0) charCodes.add(code);
            }
            return String.fromCharCodes(charCodes).trim();
          }
          return '';
        case 3: // UTF-8
        default:
          return utf8.decode(textBytes, allowMalformed: true).replaceAll('\x00', '').trim();
      }
    } catch (_) {
      return '';
    }
  }

  static _PicResult? _extractPicture(Uint8List data) {
    if (data.length < 4) return null;

    int imgOffset = -1;

    // Scan for image signatures directly (JPEG, PNG, WebP)
    // This is the most reliable way across various ID3 encoders
    for (int i = 1; i + 4 < data.length; i++) {
      // JPEG: FF D8 FF
      if (data[i] == 0xFF && data[i + 1] == 0xD8 && data[i + 2] == 0xFF) {
        imgOffset = i;
        break;
      }
      // PNG: 89 50 4E 47
      if (data[i] == 0x89 &&
          data[i + 1] == 0x50 &&
          data[i + 2] == 0x4E &&
          data[i + 3] == 0x47) {
        imgOffset = i;
        break;
      }
      // WebP: RIFF ... WEBP
      if (data[i] == 0x52 &&
          data[i + 1] == 0x49 &&
          data[i + 2] == 0x46 &&
          data[i + 3] == 0x46 &&
          i + 11 < data.length &&
          data[i + 8] == 0x57 &&
          data[i + 9] == 0x45 &&
          data[i + 10] == 0x42 &&
          data[i + 11] == 0x50) {
        imgOffset = i;
        break;
      }
    }

    if (imgOffset == -1) return null;

    final imgBytes = data.sublist(imgOffset);
    if (imgBytes.isEmpty) return null;

    String mime = 'image/jpeg';
    if (imgBytes.length >= 4 &&
        imgBytes[0] == 0x89 &&
        imgBytes[1] == 0x50 &&
        imgBytes[2] == 0x4E &&
        imgBytes[3] == 0x47) {
      mime = 'image/png';
    } else if (imgBytes.length >= 12 &&
        imgBytes[0] == 0x52 &&
        imgBytes[1] == 0x49 &&
        imgBytes[2] == 0x46 &&
        imgBytes[3] == 0x46) {
      mime = 'image/webp';
    }

    return _PicResult(imgBytes, mime);
  }
}

class _PicResult {
  final Uint8List bytes;
  final String mime;
  _PicResult(this.bytes, this.mime);
}
