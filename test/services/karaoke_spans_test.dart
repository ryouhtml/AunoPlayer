import 'package:auno_player/providers/karaoke_provider.dart';
import 'package:auno_player/services/karaoke_model.dart';
import 'package:auno_player/services/karaoke_spans.dart';
import 'package:auno_player/services/lyrics_service.dart';
import 'package:auno_player/services/online_lyrics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('karaoke spans', () {
    KaraokeLine syllableLine() {
      return KaraokeLine(
        text: 'Hello world',
        startMs: 1000,
        endMs: 3000,
        startChar: 0,
        endChar: 11,
        source: TimingSource.embeddedEnhancedLrc,
        words: [
          KaraokeWord(
            text: 'Hello ',
            startMs: 1000,
            endMs: 2000,
            startChar: 0,
            endChar: 6,
            syllables: [
              KaraokeSyllable(
                text: 'Hel',
                startMs: 1000,
                endMs: 1400,
                startChar: 0,
                endChar: 3,
              ),
              KaraokeSyllable(
                text: 'lo ',
                startMs: 1400,
                endMs: 2000,
                startChar: 3,
                endChar: 6,
              ),
            ],
          ),
          KaraokeWord(
            text: 'world',
            startMs: 2000,
            endMs: 3000,
            startChar: 6,
            endChar: 11,
          ),
        ],
      );
    }

    test('syllables win over words when both carry timings', () {
      final spans = wordSpans(syllableLine());
      expect(spans.map((s) => s.text), ['Hel', 'lo ', 'world']);
    });

    test('sweep reports partial fill without changing the source', () {
      final line = syllableLine();
      final swept = sweepSpans(line, 1200);
      expect(swept.first.fill, closeTo(0.5, 1e-6));
      expect(swept.last.fill, 0.0);
      expect(revealedChars(line, 1200), 1);
      expect(charsSungAt(line, 1200), 0);
      expect(charsSungAt(line, 1500), 3);
    });

    test('explicit word style ignores syllable timings', () {
      final spans = wordSpans(
        syllableLine(),
        KaraokeSweepStyle.word,
      );
      expect(spans.map((s) => s.text), ['Hello ', 'world']);
    });

    test('preference strings map to sweep styles', () {
      expect(karaokeSweepStyleFromString('word'), KaraokeSweepStyle.word);
      expect(
        karaokeSweepStyleFromString('syllable'),
        KaraokeSweepStyle.syllable,
      );
      expect(karaokeSweepStyleFromString(null), KaraokeSweepStyle.auto);
      expect(karaokeSweepStyleFromString('unknown'), KaraokeSweepStyle.auto);
    });

    test('line-only lyrics reveal the whole line, never guessed words', () {
      final line = KaraokeLine(
        text: 'Just a line',
        startMs: 500,
        endMs: 2500,
        startChar: 0,
        endChar: 11,
        source: TimingSource.lineOnly,
      );
      final spans = wordSpans(line);
      expect(spans, hasLength(1));
      expect(spans.single.text, 'Just a line');
      // Half of an 11-character line is 5.5; partial characters stay hidden
      // until their sweep window has actually covered them.
      expect(revealedChars(line, 1500), 5);
      expect(line.isLineOnly, isTrue);
    });
  });

  group('KaraokeNormalizer', () {
    final normalizer = KaraokeNormalizer();

    test('parses syllable tags from raw enhanced LRC', () {
      final lines = normalizer.fromRawLrc(
        '[00:10.00]<00:10.00>Hel<00:10.20>lo <00:10.50>world\n'
        '[00:12.00]Next line\n',
        source: TimingSource.sidecarEnhancedLrc,
      );
      expect(lines, hasLength(2));
      final first = lines.first;
      expect(first.source, TimingSource.sidecarEnhancedLrc);
      expect(first.words, hasLength(2));
      expect(first.words.first.syllables.map((s) => s.text), ['Hel', 'lo ']);
      expect(first.words.first.endMs, 10500);
      expect(first.words.last.endMs, 12000);
      expect(lines.last.source, TimingSource.lineOnly);
    });

    test('accepts LRCLib synced lyrics', () {
      final result = OnlineLyricsResult(
        id: 1,
        syncedLyrics: '[00:01.00]<00:01.00>One <00:02.00>two',
        instrumental: false,
      );
      final lines = normalizer.fromOnline(result);
      expect(lines, hasLength(1));
      expect(lines.single.source, TimingSource.onlineProvider);
      expect(wordSpans(lines.single).map((s) => s.text), ['One ', 'two']);
    });

    test('falls back to line-only when an end timestamp is missing', () {
      final lines = normalizer.fromRawLrc(
        '[00:10.00]<00:10.00>Alpha\n'
        '[00:11.00]<00:11.00>Beta\n',
        source: TimingSource.embeddedEnhancedLrc,
      );
      final line = lines.first;
      // The next real line timestamp closes the last word, so this is a
      // valid word-timed line rather than a guessed one.
      expect(line.source, TimingSource.embeddedEnhancedLrc);
      expect(line.words.single.endMs, 11000);

      final rawOnly = normalizer.fromRawLrc(
        '[00:10.00]Alpha\n[00:11.00]Beta\n',
        source: TimingSource.embeddedEnhancedLrc,
      );
      expect(rawOnly.first.source, TimingSource.lineOnly);
      expect(rawOnly.first.words, isEmpty);
    });
  });

  group('karaokeControllerProvider', () {
    test('selects the active line from the supplied position', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final lyrics = LyricsService().parseLyricsText(
        '[00:01.00]First line\n[00:03.00]Second line\n',
      );

      final frame = container.read(
        karaokeControllerProvider(
          (lyrics: lyrics, position: const Duration(milliseconds: 3500)),
        ),
      );

      expect(frame.activeIndex, 1);
      expect(frame.activeLine?.text, 'Second line');
      expect(frame.positionMs, 3500);
      expect(frame.spans, hasLength(1));
      expect(frame.spans.single.fill, greaterThan(0.0));
    });
  });
}
