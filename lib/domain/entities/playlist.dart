import '../../domain/entities/track.dart';

/// 播放列表实体
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.trackIds = const [],
    this.createdAt,
    this.updatedAt,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final List<String> trackIds; // 格式: "sourceId:id"
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;

  int get trackCount => trackIds.length;

  bool containsTrack(String sourceId, String id) {
    return trackIds.contains('$sourceId:$id');
  }

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    String? coverUrl,
    List<String>? trackIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'coverUrl': coverUrl,
    'trackIds': trackIds,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'metadata': metadata,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    coverUrl: json['coverUrl'] as String?,
    trackIds: List<String>.from(json['trackIds'] as List? ?? []),
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
  );

  /// 从 Track 列表创建
  static String trackKey(Track track) => '${track.sourceId}:${track.id}';

  /// 添加曲目
  Playlist addTrack(Track track) {
    final key = Playlist.trackKey(track);
    if (trackIds.contains(key)) return this;
    return copyWith(
      trackIds: [...trackIds, key],
      updatedAt: DateTime.now(),
    );
  }

  /// 移除曲目
  Playlist removeTrack(Track track) {
    final key = Playlist.trackKey(track);
    if (!trackIds.contains(key)) return this;
    return copyWith(
      trackIds: trackIds.where((k) => k != key).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// 移动曲目（重排序）
  Playlist moveTrack(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= trackIds.length) return this;
    if (newIndex < 0 || newIndex >= trackIds.length) return this;
    final newList = List<String>.from(trackIds);
    final item = newList.removeAt(oldIndex);
    newList.insert(newIndex, item);
    return copyWith(trackIds: newList, updatedAt: DateTime.now());
  }

  /// 清空曲目
  Playlist clearTracks() {
    return copyWith(trackIds: [], updatedAt: DateTime.now());
  }
}

/// 播放列表仓库接口
abstract interface class PlaylistRepository {
  /// 获取所有播放列表
  Future<List<Playlist>> getAll();

  /// 根据 ID 获取
  Future<Playlist?> getById(String id);

  /// 保存（新增或更新）
  Future<void> save(Playlist playlist);

  /// 删除
  Future<void> delete(String id);

  /// 变更流
  Stream<List<Playlist>> watch();
}