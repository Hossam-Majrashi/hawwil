import 'dart:typed_data';

enum ConversionDirection {
  mp3ToMp4,
  mp4ToMp3,
  videoToVideo,
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
  static const List<String> supportedVideoFormats = [
    'mp4',
    'mkv',
    'mov',
    'webm',
    'avi',
    'flv',
    'wmv',
  ];

  static const List<String> supportedInputVideoExtensions = [
    'mp4',
    'mkv',
    'mov',
    'webm',
    'avi',
    'flv',
    'wmv',
    'm4v',
    'ts',
    '3gp',
  ];

  static const List<String> supportedInputAudioExtensions = [
    'mp3',
    'wav',
    'aac',
    'flac',
    'm4a',
    'ogg',
    'wma',
  ];

  static const List<String> allAllowedInputExtensions = [
    'mp3',
    'wav',
    'aac',
    'flac',
    'm4a',
    'ogg',
    'wma',
    'mp4',
    'mkv',
    'mov',
    'webm',
    'avi',
    'flv',
    'wmv',
    'm4v',
    'ts',
    '3gp',
  ];

  final String id;
  final String sourcePath;
  final String fileName;
  String targetFormat; // 'mp3', 'mp4', 'mkv', 'mov', 'webm', 'avi', 'flv', 'wmv'
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
    ConversionDirection? direction,
    String? targetFormat,
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
  }) : targetFormat = targetFormat ??
            _resolveInitialTarget(fileName, direction);

  static String _resolveInitialTarget(String fileName, ConversionDirection? direction) {
    final ext = _extractExtension(fileName);
    final isAudio = supportedInputAudioExtensions.contains(ext) || ext == 'mp3';
    if (isAudio) {
      return 'mp4';
    }
    if (direction == ConversionDirection.mp4ToMp3) {
      return 'mp3';
    } else if (direction == ConversionDirection.mp3ToMp4 || direction == ConversionDirection.videoToVideo) {
      return 'mp4';
    }
    // Default for video files:
    // If input is MP4, default target is MP3 (audio extraction).
    // If input is non-MP4 (e.g. MKV, WebM), default target is MP4 (video transcode).
    return ext == 'mp4' ? 'mp3' : 'mp4';
  }

  static String _extractExtension(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < name.length - 1) {
      return name.substring(dotIndex + 1).toLowerCase();
    }
    return '';
  }

  String get fileExtension => _extractExtension(fileName);

  bool get isAudioInput =>
      supportedInputAudioExtensions.contains(fileExtension) ||
      fileExtension == 'mp3';

  bool get isVideoInput => !isAudioInput;

  bool get isTargetAudio => targetFormat.toLowerCase() == 'mp3';
  bool get isTargetVideo => !isTargetAudio;

  // Backward compatibility getters
  bool get isMp3 => isAudioInput;
  bool get isMp4 => isVideoInput;

  ConversionDirection get direction {
    if (isAudioInput) return ConversionDirection.mp3ToMp4;
    if (isTargetAudio) return ConversionDirection.mp4ToMp3;
    return ConversionDirection.videoToVideo;
  }

  set direction(ConversionDirection d) {
    if (d == ConversionDirection.mp3ToMp4) {
      targetFormat = 'mp4';
    } else if (d == ConversionDirection.mp4ToMp3) {
      targetFormat = 'mp3';
    } else {
      if (targetFormat == 'mp3') {
        targetFormat = 'mp4';
      }
    }
  }

  void reset() {
    status = ConversionStatus.queued;
    progress = 0.0;
    errorMessage = null;
  }
}

