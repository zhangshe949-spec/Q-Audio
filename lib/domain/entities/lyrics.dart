/// 歌词行：时间戳 + 文本
class LyricLine {
  const LyricLine({
    required this.time,
    required this.text,
    this.translation,
  });

  /// 毫秒时间戳
  final int time;

  /// 原文
  final String text;

  /// 译文（可选）
  final String? translation;

  @override
  String toString() =>
      '[${_format(time)}] $text${translation != null ? ' / $translation' : ''}';

  static String _format(int ms) {
    final m = (ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final msRem = (ms % 1000 ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$msRem';
  }
}

/// 完整歌词数据
class Lyrics {
  const Lyrics({
    this.title,
    this.artist,
    this.album,
    this.lines = const <LyricLine>[],
    this.translatedLines = const <LyricLine>[],
    this.offset = 0,
  });

  final String? title;
  final String? artist;
  final String? album;
  final List<LyricLine> lines;
  final List<LyricLine> translatedLines;
  final int offset; // 全局偏移(ms)，用于手动校准

  /// 根据播放位置查找当前行索引
  int indexAt(int positionMs) {
    final adjusted = positionMs + offset;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (lines[i].time <= adjusted) return i;
    }
    return -1;
  }

  /// 获取指定位置的歌词行（用于预加载上下文）
  List<LyricLine> linesAround(int positionMs, {int radius = 3}) {
    final idx = indexAt(positionMs);
    if (idx < 0) return [];
    final start = (idx - radius).clamp(0, lines.length - 1);
    final end = (idx + radius + 1).clamp(0, lines.length);
    return lines.sublist(start, end);
  }

  bool get hasTranslation => translatedLines.isNotEmpty;

  @override
  String toString() =>
      'Lyrics(title: $title, lines: ${lines.length}, translated: ${translatedLines.length})';
}

/// LRC 解析器
class LrcParser {
  static const _timeTagRegex = r'\[(\d{1,2}):(\d{1,2})[.:](\d{1,3})\]';
  static final _lineRegex = RegExp('$_timeTagRegex(?:$_timeTagRegex)*(.*)');

  /// 解析标准 LRC 文本
  static Lyrics parse(String lrcText,
      {String? title, String? artist, String? album}) {
    final lines = <LyricLine>[];
    int? offset;

    for (final rawLine in lrcText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // 元数据标签
      if (line.startsWith('[offset:')) {
        offset = int.tryParse(line.substring(8, line.length - 1)) ?? 0;
        continue;
      }
      if (line.startsWith('[ti:')) {
        title ??= line.substring(4, line.length - 1);
        continue;
      }
      if (line.startsWith('[ar:')) {
        artist ??= line.substring(4, line.length - 1);
        continue;
      }
      if (line.startsWith('[al:')) {
        album ??= line.substring(4, line.length - 1);
        continue;
      }

      // 歌词行：可能包含多个时间标签（如 [00:12.34][00:15.67]歌词）
      final match = _lineRegex.firstMatch(line);
      if (match != null) {
        final text = match.group(match.groupCount)?.trim() ?? '';
        if (text.isEmpty) continue;

        // 提取所有时间标签
        final timeMatches = RegExp(_timeTagRegex).allMatches(line);
        for (final tm in timeMatches) {
          final m = int.parse(tm.group(1)!);
          final s = int.parse(tm.group(2)!);
          final msStr = tm.group(3)!;
          final ms = msStr.length == 3
              ? int.parse(msStr)
              : int.parse(msStr) * (msStr.length == 2 ? 10 : 100);
          final timeMs = m * 60000 + s * 1000 + ms;
          lines.add(LyricLine(time: timeMs, text: text));
        }
      }
    }

    lines.sort((a, b) => a.time.compareTo(b.time));

    return Lyrics(
      title: title,
      artist: artist,
      album: album,
      lines: lines,
      offset: offset ?? 0,
    );
  }

  /// 解析翻译歌词（仅提取文本，复用主歌词的时间轴）
  static List<LyricLine> parseTranslation(
      String tlrcText, List<LyricLine> mainLines) {
    final translated = <LyricLine>[];
    final textByTime = <int, String>{};

    for (final rawLine in tlrcText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = _lineRegex.firstMatch(line);
      if (match != null) {
        final text = match.group(match.groupCount)?.trim() ?? '';
        if (text.isEmpty) continue;

        final timeMatches = RegExp(_timeTagRegex).allMatches(line);
        for (final tm in timeMatches) {
          final m = int.parse(tm.group(1)!);
          final s = int.parse(tm.group(2)!);
          final msStr = tm.group(3)!;
          final ms = msStr.length == 3
              ? int.parse(msStr)
              : int.parse(msStr) * (msStr.length == 2 ? 10 : 100);
          final timeMs = m * 60000 + s * 1000 + ms;
          textByTime[timeMs] = text;
        }
      }
    }

    // 按主歌词时间轴对齐译文
    for (final main in mainLines) {
      final tlText = textByTime[main.time];
      if (tlText != null) {
        translated.add(LyricLine(time: main.time, text: tlText));
      }
    }

    return translated;
  }
}
