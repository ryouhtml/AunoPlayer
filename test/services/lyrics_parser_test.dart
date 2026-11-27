import 'package:flutter_test/flutter_test.dart';

import 'package:auno_player/models/synced_lyric_document.dart';
import 'package:auno_player/services/lyrics_parser.dart';

void main() {
  const parser = LyricsParser();

  group('standard LRC', () {
    test('parses timestamps, offset and multiple stamps per row', () {
      final document = parser.parse('''
[ar:Artist]
[offset:500]
[00:01.00]First line
[00:02.50][00:03.00]Repeated
[00:04.25]Last
''');

      expect(document.syncLevel, LyricSyncLevel.line);
      expect(document.lines.length, 4);
      expect(document.lines.first.start, const Duration(milliseconds: 1500));
      expect(document.lines.first.text, 'First line');
      expect(document.lines[1].text, 'Repeated');
      expect(document.lines[1].start, const Duration(milliseconds: 3000));
      expect(document.lines[2].start, const Duration(milliseconds: 3500));
      expect(
        document.lines[0].end,
        const Duration(milliseconds: 3000),
      );
    });

    test('does not invent word timing for line-synced lyrics', () {
      final document = parser.parse('[00:01.00]Hello world');
      expect(document.lines.single.words, isEmpty);
      expect(document.hasWordTiming, isFalse);
    });

    test('keeps plain text as plain', () {
      final document = parser.parse('One\nTwo\n\nThree');
      expect(document.syncLevel, LyricSyncLevel.plain);
      expect(document.lines.map((line) => line.text), ['One', 'Two', 'Three']);
      expect(document.isSynced, isFalse);
    });
  });

  group('enhanced LRC', () {
    test('extracts real word windows from inline markers', () {
      final document = parser.parse(
        '[00:10.00]<00:10.00>Hello <00:10.60>big <00:11.20>world\n'
        '[00:12.00]Next line',
      );

      expect(document.syncLevel, LyricSyncLevel.word);
      final line = document.lines.first;
      expect(line.text, 'Hello big world');
      expect(line.words.length, 3);
      expect(line.words[0].start, const Duration(seconds: 10));
      expect(line.words[1].start, const Duration(milliseconds: 10600));
      expect(line.words[2].end, const Duration(seconds: 12));
    });
  });

  group('TTML', () {
    test('parses line and word timing', () {
      final document = parser.parse('''
<tt xmlns="http://www.w3.org/ns/ttml">
  <body><div>
    <p begin="00:00:05.000" end="00:00:08.000">
      <span begin="00:00:05.000" end="00:00:06.000">Hello </span>
      <span begin="00:00:06.000" end="00:00:08.000">world</span>
    </p>
  </div></body>
</tt>
''');

      expect(document.syncLevel, LyricSyncLevel.word);
      final line = document.lines.single;
      expect(line.text, 'Hello world');
      expect(line.start, const Duration(seconds: 5));
      expect(line.words.length, 2);
      expect(line.words[1].start, const Duration(seconds: 6));
      expect(line.words[1].end, const Duration(seconds: 8));
    });

    test('parses nested syllable spans and translation spans', () {
      final document = parser.parse('''
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <body><div>
    <p begin="1.5s" end="4s">
      <span begin="1.5s" end="3s"><span begin="1.5s" end="2s">Ka</span><span begin="2s" end="3s">ra</span></span><span begin="3s" end="4s">oke</span>
      <span ttm:role="x-translation" begin="1.5s" end="4s">Terjemahan</span>
    </p>
  </div></body>
</tt>
''');

      final line = document.lines.single;
      expect(line.text, 'Karaoke');
      expect(line.translation, 'Terjemahan');
      expect(line.words.first.syllables.length, 2);
      expect(line.words.first.syllables[1].text, 'ra');
    });
  });
}
