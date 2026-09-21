import 'dart:typed_data';

enum ConversionDirection {
  mp3ToMp4,
  mp4ToMp3,
}

enum ConversionStatus {
  queued,
  extractingThumbnail,
  converting,
  completed,
  failed,
  cancelled,
}

class ConversionItem {
  final String id;
  final String sourcePath;
  final String fileName;
  ConversionDirection direction;
  ConversionStatus status;
  double progress; // 0.0 to 1.0
  String? errorMessage;
  String? outputPath;

  Uint8List? thumbnailBytes;
  String? customImagePath;
  bool hasEmbeddedCover;
  double videoScrubSeconds;
  double? durationSeconds;

  // Metadata tags
  String? title;
  String? artist;
  String? album;

  // Item overrides
  String? resolutionOverride;
  String? videoBitrateOverride;
  String? audioBitrateOverride;

  ConversionItem({
    required this.id,
    required this.sourcePath,
    required this.fileName,
    required this.direction,
    this.status = ConversionStatus.queued,
    this.progress = 0.0,
    this.errorMessage,
    this.outputPath,
    this.thumbnailBytes,
    this.customImagePath,
    this.hasEmbeddedCover = false,
    this.videoScrubSeconds = 0.0,
    this.durationSeconds,
    this.title,
    this.artist,
    this.album,
    this.resolutionOverride,
    this.videoBitrateOverride,
    this.audioBitrateOverride,
  });

  bool get isMp3 => fileName.toLowerCase().endsWith('.mp3');
  bool get isMp4 =>
      fileName.toLowerCase().endsWith('.mp4') ||
      fileName.toLowerCase().endsWith('.m4v') ||
      fileName.toLowerCase().endsWith('.mov') ||
      fileName.toLowerCase().endsWith('.mkv') ||
      fileName.toLowerCase().endsWith('.webm');

  void reset() {
    status = ConversionStatus.queued;
    progress = 0.0;
    errorMessage = null;
  }
}
