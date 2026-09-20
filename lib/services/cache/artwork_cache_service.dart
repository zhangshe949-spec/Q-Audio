import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// 二级缓存服务：内存 + 磁盘
/// - 内存：使用 Flutter 自带的 ImageCache（已实现 LRU）
/// - 磁盘：应用缓存目录，默认 50MB，文件名为 URL 的 hash
class ArtworkCacheService {
  ArtworkCacheService._internal() {
    _initDiskCache();
  }

  static final ArtworkCacheService instance = ArtworkCacheService._internal();

  // 磁盘缓存目录
  Directory? _diskCacheDir;
  static const int _maxDiskCacheBytes = 50 * 1024 * 1024; // 50MB

  Future<void> _initDiskCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      _diskCacheDir = Directory('${cacheDir.path}/artwork_cache');
      if (!await _diskCacheDir!.exists()) {
        await _diskCacheDir!.create(recursive: true);
      }
      _cleanOldDiskCache();
    } catch (e) {
      debugPrint('ArtworkCacheService: Failed to init disk cache: $e');
    }
  }

  /// 获取图片提供者：优先内存 -> 磁盘 -> 网络
  /// 返回一个自动处理缓存的 ImageProvider
  ImageProvider getImage(String url) {
    if (url.isEmpty) {
      return const AssetImage('assets/placeholder.png'); // 后续可替换
    }

    // 1. 检查磁盘缓存
    final diskPath = _getDiskCachePath(url);
    if (diskPath != null) {
      final file = File(diskPath);
      if (file.existsSync()) {
        // 磁盘命中，使用 FileImage（会被 ImageCache 自动缓存到内存）
        return FileImage(file);
      }
    }

    // 2. 网络加载，使用自定义 provider 自动存入磁盘
    return _DiskCachedNetworkImage(url, this);
  }

  /// 预加载图片到内存和磁盘
  Future<void> precache(String url, BuildContext context) async {
    if (url.isEmpty) return;

    final diskPath = _getDiskCachePath(url);
    if (diskPath != null && File(diskPath).existsSync()) return;

    try {
      final provider = NetworkImage(url);
      // ignore: unawaited_futures
      provider.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((info, _) {
          _saveToDiskCache(url, info.image);
        }, onError: (_, __) {}),
      );
    } catch (e) {
      debugPrint('ArtworkCacheService: Precache failed for $url: $e');
    }
  }

  /// 清理内存缓存（清空 Flutter 的 ImageCache）
  void clearMemoryCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// 清理磁盘缓存
  Future<void> clearDiskCache() async {
    if (_diskCacheDir != null && await _diskCacheDir!.exists()) {
      await _diskCacheDir!.delete(recursive: true);
      await _diskCacheDir!.create(recursive: true);
    }
  }

  /// 获取磁盘缓存大小
  Future<int> getDiskCacheSize() async {
    if (_diskCacheDir == null || !await _diskCacheDir!.exists()) return 0;
    int size = 0;
    await for (final file in _diskCacheDir!.list()) {
      if (file is File) {
        size += await file.length();
      }
    }
    return size;
  }

  String _getDiskCacheKey(String url) {
    // 简单的 hash，避免文件名过长或非法字符
    return url.hashCode.abs().toRadixString(16);
  }

  String? _getDiskCachePath(String url) {
    if (_diskCacheDir == null) return null;
    return '${_diskCacheDir!.path}/${_getDiskCacheKey(url)}.cache';
  }

  Future<void> _saveToDiskCache(String url, ui.Image image) async {
    if (_diskCacheDir == null) return;
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final file = File(_getDiskCachePath(url)!);
        await file.writeAsBytes(byteData.buffer.asUint8List());
        _enforceDiskCacheLimit();
      }
    } catch (e) {
      debugPrint('ArtworkCacheService: Failed to save to disk cache: $e');
    }
  }

  void _cleanOldDiskCache() {
    if (_diskCacheDir == null) return;
    try {
      final files = _diskCacheDir!.listSync().whereType<File>().toList()
        ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      int totalSize = files.fold(0, (sum, f) => sum + f.lengthSync());
      for (final file in files) {
        if (totalSize <= _maxDiskCacheBytes) break;
        totalSize -= file.lengthSync();
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('ArtworkCacheService: Clean old cache failed: $e');
    }
  }

  void _enforceDiskCacheLimit() {
    if (_diskCacheDir == null) return;
    try {
      final files = _diskCacheDir!.listSync().whereType<File>().toList()
        ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      int totalSize = files.fold(0, (sum, f) => sum + f.lengthSync());
      for (final file in files) {
        if (totalSize <= _maxDiskCacheBytes) break;
        totalSize -= file.lengthSync();
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('ArtworkCacheService: Enforce limit failed: $e');
    }
  }
}

/// 带磁盘缓存的 NetworkImage
class _DiskCachedNetworkImage extends ImageProvider<_DiskCachedNetworkImage> {
  _DiskCachedNetworkImage(this.url, this.cacheService);

  final String url;
  final ArtworkCacheService cacheService;

  @override
  Future<_DiskCachedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_DiskCachedNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _DiskCachedNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAndCache(key.url, decode),
      scale: 1.0,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<String>('URL', url);
      },
    );
  }

  Future<ui.Codec> _loadAndCache(String url, ImageDecoderCallback decode) async {
    // 尝试从磁盘加载
    final diskPath = cacheService._getDiskCachePath(url);
    if (diskPath != null) {
      final file = File(diskPath);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      }
    }

    // 网络下载
    final response = await HttpClient().getUrl(Uri.parse(url));
    final httpResponse = await response.close();
    if (httpResponse.statusCode == 200) {
      final bytes = await _consolidateHttpClientResponseBytes(httpResponse);
      // 保存到磁盘缓存
      if (diskPath != null) {
        await File(diskPath).writeAsBytes(bytes);
        cacheService._enforceDiskCacheLimit();
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    }

    throw Exception('Failed to load image: ${httpResponse.statusCode}');
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _DiskCachedNetworkImage &&
            runtimeType == other.runtimeType &&
            url == other.url;
  }

  @override
  int get hashCode => url.hashCode;
}

/// 合并 HTTP 响应字节
Future<Uint8List> _consolidateHttpClientResponseBytes(HttpClientResponse response) async {
  final contentLength = response.contentLength;
  if (contentLength == 0) return Uint8List(0);

  final builder = BytesBuilder();
  await for (final data in response) {
    builder.add(data);
  }
  return builder.toBytes();
}