import 'dart:async';

/// 下载任务状态
enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

/// 下载任务实体
class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.url,
    required this.filePath,
    this.title,
    this.artist,
    this.album,
    this.artworkUrl,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.pending,
    this.error,
    this.createdAt,
    this.updatedAt,
    this.mimeType,
    this.metadata = const {},
  });

  final String id;
  final String url;
  final String filePath;
  final String? title;
  final String? artist;
  final String? album;
  final String? artworkUrl;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final String? error;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? mimeType;
  final Map<String, dynamic> metadata;

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  bool get isActive => status == DownloadStatus.downloading || status == DownloadStatus.pending;

  DownloadTask copyWith({
    String? id,
    String? url,
    String? filePath,
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    String? error,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? mimeType,
    Map<String, dynamic>? metadata,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mimeType: mimeType ?? this.mimeType,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'filePath': filePath,
    'title': title,
    'artist': artist,
    'album': album,
    'artworkUrl': artworkUrl,
    'totalBytes': totalBytes,
    'downloadedBytes': downloadedBytes,
    'status': status.index,
    'error': error,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'mimeType': mimeType,
    'metadata': metadata,
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
    id: json['id'] as String,
    url: json['url'] as String,
    filePath: json['filePath'] as String,
    title: json['title'] as String?,
    artist: json['artist'] as String?,
    album: json['album'] as String?,
    artworkUrl: json['artworkUrl'] as String?,
    totalBytes: json['totalBytes'] as int? ?? 0,
    downloadedBytes: json['downloadedBytes'] as int? ?? 0,
    status: DownloadStatus.values[json['status'] as int? ?? 0],
    error: json['error'] as String?,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    mimeType: json['mimeType'] as String?,
    metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
  );
}

/// 下载仓库接口
abstract interface class DownloadRepository {
  /// 获取所有任务
  Future<List<DownloadTask>> getAll();

  /// 根据 ID 获取任务
  Future<DownloadTask?> getById(String id);

  /// 保存任务（新增或更新）
  Future<void> save(DownloadTask task);

  /// 删除任务
  Future<void> delete(String id);

  /// 清理已完成/失败的任务
  Future<int> clearCompleted({bool includeFailed = true});

  /// 任务变更流
  Stream<List<DownloadTask>> watch();
}