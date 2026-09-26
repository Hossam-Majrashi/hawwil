import 'dart:typed_data';

enum MergeMediaType {
  image,
  video,
  audio,
}

class MergeMediaItem {
  final String id;
  final String path;
  final String name;
  final MergeMediaType type;
  Duration duration;
  Uint8List? thumbnailBytes;
  final int? width;
  final int? height;
  final double? fps;

  MergeMediaItem({
    required this.id,
    required this.path,
    required this.name,
    required this.type,
    required this.duration,
    this.thumbnailBytes,
    this.width,
    this.height,
    this.fps,
  });

  bool get isImage => type == MergeMediaType.image;
  bool get isVideo => type == MergeMediaType.video;
  bool get isAudio => type == MergeMediaType.audio;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  MergeMediaItem copyWith({
    String? id,
    String? path,
    String? name,
    MergeMediaType? type,
    Duration? duration,
    Uint8List? thumbnailBytes,
    int? width,
    int? height,
    double? fps,
  }) {
    return MergeMediaItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
    );
  }
}

class MergeTrackDragPayload {
  final MergeMediaItem item;
  final int sourceTrack; // 1 = image, 2 = video, 3 = audio
  final int sourceIndex;

  const MergeTrackDragPayload({
    required this.item,
    required this.sourceTrack,
    required this.sourceIndex,
  });
}
