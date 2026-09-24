class ConversionSettings {
  static const List<String> availableResolutions = [
    '1920x1080', // 1080p (16:9)
    '1280x720',  // 720p (16:9)
    '1080x1080', // Square (1:1)
    '3840x2160', // 4K UHD (16:9)
    '720x1280',  // Vertical (9:16)
  ];

  static const List<String> availableVideoBitrates = [
    '2500k',
    '5000k',
    '8000k',
    '12000k',
  ];

  static const List<String> availableAudioBitrates = [
    '128k',
    '192k',
    '256k',
    '320k',
  ];

  static const List<String> availableHwAccels = [
    'auto',
    'nvenc',
    'vaapi',
    'cpu_ultrafast',
  ];

  static const List<String> availableVideoFormats = [
    'mp4',
    'mkv',
    'mov',
    'webm',
    'avi',
    'flv',
    'wmv',
    'mpg',
    'mpeg',
    'ogv',
  ];

  static const List<String> allOutputFormatsForVideos = [
    'mp4',
    'mkv',
    'mov',
    'webm',
    'avi',
    'flv',
    'wmv',
    'mpg',
    'mpeg',
    'ogv',
    'mp3',
    'aac',
    'wav',
    'flac',
    'ogg',
    'opus',
  ];

  String defaultResolution;
  String defaultVideoBitrate;
  String defaultAudioBitrate;
  String hardwareAcceleration;
  String defaultVideoOutputFormat;
  String? outputFolder;
  String filenamePattern;

  ConversionSettings({
    this.defaultResolution = '1920x1080',
    this.defaultVideoBitrate = '5000k',
    this.defaultAudioBitrate = '320k',
    this.hardwareAcceleration = 'auto',
    this.defaultVideoOutputFormat = 'mp4',
    this.outputFolder,
    this.filenamePattern = '{name}_hawwil',
  });

  ConversionSettings copyWith({
    String? defaultResolution,
    String? defaultVideoBitrate,
    String? defaultAudioBitrate,
    String? hardwareAcceleration,
    String? defaultVideoOutputFormat,
    String? outputFolder,
    String? filenamePattern,
  }) {
    return ConversionSettings(
      defaultResolution: defaultResolution ?? this.defaultResolution,
      defaultVideoBitrate: defaultVideoBitrate ?? this.defaultVideoBitrate,
      defaultAudioBitrate: defaultAudioBitrate ?? this.defaultAudioBitrate,
      hardwareAcceleration: hardwareAcceleration ?? this.hardwareAcceleration,
      defaultVideoOutputFormat: defaultVideoOutputFormat ?? this.defaultVideoOutputFormat,
      outputFolder: outputFolder ?? this.outputFolder,
      filenamePattern: filenamePattern ?? this.filenamePattern,
    );
  }
}
