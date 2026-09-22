import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../l10n/app_localizations.dart';

/// Cross-platform service to download/save MP3 cover art images on Web, Desktop, and Mobile.
class CoverDownloadService {
  /// Detects image MIME type from magic numbers.
  static String detectMimeType(Uint8List bytes, [String? fallback]) {
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
      // GIF signature: GIF87a or GIF89a
      if (bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46) {
        return 'image/gif';
      }
    }
    return fallback ?? 'image/jpeg';
  }

  /// Returns file extension including dot (e.g. '.jpg', '.png', '.webp').
  static String detectExtension(Uint8List bytes, [String? fallbackMime]) {
    final mime = detectMimeType(bytes, fallbackMime);
    switch (mime) {
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/gif':
        return '.gif';
      case 'image/jpeg':
      default:
        return '.jpg';
    }
  }

  /// Downloads/saves the cover art image with native UI dialogs across all platforms.
  /// Shows localized feedback SnackBars on completion.
  static Future<bool> downloadCoverWithFeedback({
    required BuildContext context,
    required Uint8List coverBytes,
    String? mp3FileName,
    String? mimeType,
  }) async {
    if (coverBytes.isEmpty) return false;

    final l10n = AppLocalizations.of(context);
    final ext = detectExtension(coverBytes, mimeType);
    final detectedMime = detectMimeType(coverBytes, mimeType);

    // Build default filename from MP3 track name if available
    String baseName = 'cover';
    if (mp3FileName != null && mp3FileName.trim().isNotEmpty) {
      final withoutExt = p.basenameWithoutExtension(mp3FileName.trim());
      if (withoutExt.isNotEmpty) {
        baseName = '${withoutExt}_cover';
      }
    }
    final suggestedFileName = '$baseName$ext';

    bool success = false;
    bool userCancelled = false;

    try {
      final resultUri = await FilePicker.saveFile(
        dialogTitle: l10n.tr('downloadCover'),
        fileName: suggestedFileName,
        bytes: coverBytes,
        mimeType: detectedMime,
        type: FileType.custom,
        allowedExtensions: [ext.replaceAll('.', '')],
      );

      if (resultUri != null) {
        success = true;
      } else {
        userCancelled = true;
      }
    } catch (e) {
      debugPrint('CoverDownloadService: FilePicker.saveFile error: $e');

      // Fallback for non-web platforms if native picker encounters an issue
      if (!kIsWeb) {
        try {
          Directory? dir;
          try {
            dir = await getDownloadsDirectory();
          } catch (_) {}
          dir ??= await getApplicationDocumentsDirectory();

          final fallbackPath = p.join(dir.path, suggestedFileName);
          final file = File(fallbackPath);
          await file.writeAsBytes(coverBytes);
          debugPrint('CoverDownloadService: Fallback saved to $fallbackPath');
          success = true;
        } catch (fallbackErr) {
          debugPrint('CoverDownloadService: Fallback error: $fallbackErr');
          success = false;
        }
      }
    }

    if (!context.mounted) return success;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.tr('coverDownloaded'))),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (!userCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.tr('coverDownloadFailed'))),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    return success;
  }
}
