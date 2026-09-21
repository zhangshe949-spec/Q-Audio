import 'package:flutter/material.dart';
import 'package:q_audio/services/cache/artwork_cache_service.dart';

/// 封面图片组件：自动使用二级缓存（内存 + 磁盘）
class CachedArtwork extends StatelessWidget {
  const CachedArtwork({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final cacheService = ArtworkCacheService.instance;
    final provider = cacheService.getImage(url);

    Widget image = Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(
                  Icons.music_note_rounded,
                  size: 40,
                  color: Colors.white54,
                ),
              ),
            );
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}

/// 圆形封面头像
class CachedArtworkCircle extends StatelessWidget {
  const CachedArtworkCircle({
    super.key,
    required this.url,
    this.radius = 24,
    this.borderWidth = 0,
    this.borderColor,
  });

  final String url;
  final double radius;
  final double borderWidth;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        decoration: borderWidth > 0
            ? BoxDecoration(
                border: Border.all(
                  color: borderColor ?? Theme.of(context).colorScheme.outline,
                  width: borderWidth,
                ),
                shape: BoxShape.circle,
              )
            : null,
        child: CachedArtwork(
          url: url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
