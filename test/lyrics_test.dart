import 'package:flutter_test/flutter_test.dart';
import 'package:q_audio/domain/entities/lyrics.dart';

void main() {
  group('LyricLine', () {
    test('formats time correctly', () {
      const line = LyricLine(time: 0, text: 'Start');
      expect(line.toString(), contains('[00:00.00] Start'));

      const line2 = LyricLine(time: 61234, text: 'Middle');
      expect(line2.toString(), contains('[01:01.23] Middle'));

      const line3 = LyricLine(time: 3661000, text: 'Long');
      expect(line3.toString(), contains('[61:01.00] Long'));
    });

    test('includes translation when present', () {
      const line = LyricLine(time: 0, text: 'Hello', translation: '你好');
      expect(line.toString(), contains('Hello / 你好'));
    });
  });

  group('Lyrics', () {
    const sampleLines = [
      LyricLine(time: 0, text: 'First line'),
      LyricLine(time: 5000, text: 'Second line'),
      LyricLine(time: 10000, text: 'Third line'),
      LyricLine(time: 15000, text: 'Fourth line'),
      LyricLine(time: 20000, text: 'Fifth line'),
    ];

    const lyrics = Lyrics(lines: sampleLines);

    test('indexAt returns correct index for position', () {
      expect(lyrics.indexAt(-1000), -1);
      expect(lyrics.indexAt(0), 0);
      expect(lyrics.indexAt(2500), 0);
      expect(lyrics.indexAt(5000), 1);
      expect(lyrics.indexAt(7500), 1);
      expect(lyrics.indexAt(10000), 2);
      expect(lyrics.indexAt(15000), 3);
      expect(lyrics.indexAt(20000), 4);
      expect(lyrics.indexAt(30000), 4);
    });

    test('indexAt respects offset', () {
      const lyricsWithOffset = Lyrics(lines: sampleLines, offset: 1000);
      // offset=1000 means lyrics appear 1s earlier
      // at position 0, adjusted=1000, so line at time 0 (First) is shown
      expect(lyricsWithOffset.indexAt(0), 0);
      // at position 5000, adjusted=6000, so line at 5000 (Second) is shown
      expect(lyricsWithOffset.indexAt(5000), 1);
      // at position 10000, adjusted=11000, so line at 10000 (Third) is shown
      expect(lyricsWithOffset.indexAt(10000), 2);
    });

    test('linesAround returns context around current line', () {
      final around = lyrics.linesAround(7500, radius: 1);
      expect(around.length, 3);
      expect(around.map((l) => l.text).toList(),
          ['First line', 'Second line', 'Third line']);
    });

    test('linesAround clamps at boundaries', () {
      final aroundStart = lyrics.linesAround(0, radius: 2);
      expect(aroundStart.length, 3);
      expect(aroundStart.first.text, 'First line');

      final aroundEnd = lyrics.linesAround(20000, radius: 2);
      expect(aroundEnd.length, 3);
      expect(aroundEnd.last.text, 'Fifth line');
    });

    test('hasTranslation returns false when no translated lines', () {
      expect(lyrics.hasTranslation, isFalse);
    });

    test('hasTranslation returns true when translated lines exist', () {
      const withTrans = Lyrics(
        lines: sampleLines,
        translatedLines: [LyricLine(time: 0, text: '第一行')],
      );
      expect(withTrans.hasTranslation, isTrue);
    });
  });

  group('LrcParser', () {
    test('parses basic LRC with time tags', () {
      const lrc = '''
[00:12.34]First line
[00:15.67]Second line
[00:20.00]Third line
''';

      final lyrics =
          LrcParser.parse(lrc, title: 'Test', artist: 'Artist', album: 'Album');

      expect(lyrics.title, 'Test');
      expect(lyrics.artist, 'Artist');
      expect(lyrics.album, 'Album');
      expect(lyrics.lines.length, 3);
      expect(lyrics.lines[0].time, 12340); // 00:12.34 = 12*1000 + 340
      expect(lyrics.lines[0].text, 'First line');
      expect(lyrics.lines[1].time, 15670);
      expect(lyrics.lines[2].time, 20000);
    });

    test('parses LRC with multiple time tags per line', () {
      const lrc = '''
[00:10.00][00:11.00]Same text at two times
[00:15.00]Another line
''';

      final lyrics = LrcParser.parse(lrc);

      expect(lyrics.lines.length, 3);
      expect(lyrics.lines[0].time, 10000);
      expect(lyrics.lines[0].text, 'Same text at two times');
      expect(lyrics.lines[1].time, 11000);
      expect(lyrics.lines[1].text, 'Same text at two times');
      expect(lyrics.lines[2].time, 15000);
    });

    test('parses metadata tags', () {
      const lrc = '''
[ti:Song Title]
[ar:Artist Name]
[al:Album Name]
[offset:500]
[00:00.00]Start
''';

      final lyrics = LrcParser.parse(lrc);

      expect(lyrics.title, 'Song Title');
      expect(lyrics.artist, 'Artist Name');
      expect(lyrics.album, 'Album Name');
      expect(lyrics.offset, 500);
    });

    test('handles milliseconds with different precision', () {
      const lrc = '''
[00:01.5]Short ms
[00:02.50]Two digits
[00:03.500]Three digits
''';

      final lyrics = LrcParser.parse(lrc);

      expect(lyrics.lines[0].time, 1500); // 1.5s = 1500ms
      expect(lyrics.lines[1].time, 2500); // 2.50s = 2500ms
      expect(lyrics.lines[2].time, 3500); // 3.500s = 3500ms
    });

    test('ignores empty lines and metadata-only lines', () {
      const lrc = '''
[ti:Title]

[00:00.00]First

[00:05.00]Second

''';

      final lyrics = LrcParser.parse(lrc);

      expect(lyrics.lines.length, 2);
    });

    test('sorts lines by time', () {
      const lrc = '''
[00:10.00]Third
[00:00.00]First
[00:05.00]Second
''';

      final lyrics = LrcParser.parse(lrc);

      expect(lyrics.lines[0].text, 'First');
      expect(lyrics.lines[1].text, 'Second');
      expect(lyrics.lines[2].text, 'Third');
    });

    test('parseTranslation aligns with main lines', () {
      const mainLrc = '''
[00:00.00]Hello
[00:05.00]World
[00:10.00]Test
''';

      const transLrc = '''
[00:00.00]你好
[00:05.00]世界
[00:10.00]测试
''';

      final main = LrcParser.parse(mainLrc);
      final translated = LrcParser.parseTranslation(transLrc, main.lines);

      expect(translated.length, 3);
      expect(translated[0].time, 0);
      expect(translated[0].text, '你好');
      expect(translated[1].text, '世界');
      expect(translated[2].text, '测试');
    });

    test('parseTranslation handles missing translations', () {
      const mainLrc = '''
[00:00.00]Hello
[00:05.00]World
[00:10.00]Test
''';

      const transLrc = '''
[00:00.00]你好
[00:10.00]测试
''';

      final main = LrcParser.parse(mainLrc);
      final translated = LrcParser.parseTranslation(transLrc, main.lines);

      // Only lines with matching timestamps get translations
      expect(translated.length, 2);
      expect(translated[0].time, 0);
      expect(translated[0].text, '你好');
      expect(translated[1].time, 10000);
      expect(translated[1].text, '测试');
    });

    test('returns empty for invalid LRC', () {
      const lrc = 'invalid content';
      final lyrics = LrcParser.parse(lrc);
      expect(lyrics.lines, isEmpty);
    });

    test('handles LRC with only metadata', () {
      const lrc = '''
[ti:Only Meta]
[ar:Artist]
''';

      final lyrics = LrcParser.parse(lrc);
      expect(lyrics.title, 'Only Meta');
      expect(lyrics.artist, 'Artist');
      expect(lyrics.lines, isEmpty);
    });
  });
}
