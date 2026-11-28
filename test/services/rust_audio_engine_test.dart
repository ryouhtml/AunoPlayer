import 'package:auno_player/models/audio_engine_type.dart';
import 'package:auno_player/models/playback_state.dart';
import 'package:auno_player/models/song.dart';
import 'package:auno_player/services/rust_audio_engine.dart';
import 'package:auno_player/services/rust_audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

typedef PlayCall = ({String path, double? start, double? end});

class FakeRustAudioService implements RustAudioService {
  @override
  final stateNotifier = ValueNotifier(RustPlaybackState.idle);
  @override
  final positionNotifier = ValueNotifier(Duration.zero);
  @override
  final durationNotifier = ValueNotifier(Duration.zero);
  @override
  final bufferLevelNotifier = ValueNotifier(0.0);

  final plays = <PlayCall>[];
  final seeks = <Duration>[];
  @override
  String? currentPath;
  int resumes = 0;

  @override
  Future<void> pause() async {
    stateNotifier.value = RustPlaybackState.paused;
  }

  @override
  Future<void> resume() async {
    resumes++;
    stateNotifier.value = RustPlaybackState.playing;
  }

  @override
  Future<void> play(String path, {double? startSecs, double? endSecs}) async {
    plays.add((path: path, start: startSecs, end: endSecs));
    stateNotifier.value = RustPlaybackState.playing;
  }

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Song track({int? start, int? end}) => Song(
  id: 'cue-${start ?? 'file'}',
  title: 'Track',
  artist: 'Artist',
  duration: const Duration(seconds: 18),
  fileType: 'FLAC',
  filePath: '/music/album.flac',
  startOffsetMs: start,
  endOffsetMs: end,
);

void main() {
  late FakeRustAudioService service;
  late RustAudioEngine engine;

  setUp(() {
    service = FakeRustAudioService();
    engine = RustAudioEngine(
      playbackMode: AudioEngineType.usbDacExperimental,
      rustAudioService: service,
      ensureInitialized: () async {},
      resolvePlaybackPath: (song) async => song.filePath,
      disposeEngine: () async {},
    );
  });

  tearDown(() async {
    await engine.dispose();
    service.stateNotifier.dispose();
    service.positionNotifier.dispose();
    service.durationNotifier.dispose();
    service.bufferLevelNotifier.dispose();
  });

  test(
    'local play forwards first, middle, final and unbounded tracks',
    () async {
      for (final song in [
        track(start: 0, end: 13000),
        track(start: 13000, end: 31000),
        track(start: 31000),
        track(),
      ]) {
        await engine.load(song);
        await engine.play();
      }

      expect(service.plays, [
        (path: '/music/album.flac', start: 0.0, end: 13.0),
        (path: '/music/album.flac', start: 13.0, end: 31.0),
        (path: '/music/album.flac', start: 31.0, end: null),
        (path: '/music/album.flac', start: null, end: null),
      ]);
      expect(service.seeks, isEmpty);
    },
  );

  test('deferred and active seeks remain track-relative', () async {
    await engine.load(track(start: 13000, end: 31000));
    await engine.seek(const Duration(seconds: 2));
    expect(service.seeks, isEmpty);
    await engine.play();
    await engine.seek(const Duration(seconds: 4));

    expect(service.seeks, [
      const Duration(seconds: 2),
      const Duration(seconds: 4),
    ]);
  });

  test('native progress and duration stay relative to the CUE track', () async {
    final states = <PlaybackState>[];
    final subscription = engine.playbackStateStream.listen(states.add);
    await engine.load(track(start: 13000, end: 31000));
    service.positionNotifier.value = const Duration(seconds: 3);
    service.durationNotifier.value = const Duration(milliseconds: 18001);
    await Future<void>.delayed(Duration.zero);

    expect(states.last.position, const Duration(seconds: 3));
    expect(states.last.duration, const Duration(milliseconds: 18001));
    await subscription.cancel();
  });

  test('track switch during playback restores the playing UI state', () async {
    final states = <PlaybackState>[];
    final subscription = engine.playbackStateStream.listen(states.add);
    await engine.load(track());
    await engine.play();
    await Future<void>.delayed(Duration.zero);
    expect(states.last.isPlaying, isTrue);

    // The native stream never stopped, so play() does not change the Rust
    // state notifier; the engine must still emit the accepted playing state.
    await engine.load(track(start: 13000, end: 31000));
    await Future<void>.delayed(Duration.zero);
    expect(states.last.isPlaying, isFalse);
    await engine.play();
    await Future<void>.delayed(Duration.zero);

    expect(service.stateNotifier.value, RustPlaybackState.playing);
    expect(states.last.isPlaying, isTrue);
    await subscription.cancel();
  });

  group('managed audio focus', () {
    late bool granted;
    late int requests;

    setUp(() async {
      await engine.dispose();
      granted = true;
      requests = 0;
      engine = RustAudioEngine(
        playbackMode: AudioEngineType.rustOboe,
        rustAudioService: service,
        ensureInitialized: () async {},
        resolvePlaybackPath: (song) async => song.filePath,
        disposeEngine: () async {},
        requestAudioFocus: () async {
          requests++;
          expect(service.stateNotifier.value, isNot(RustPlaybackState.playing));
          return granted;
        },
      );
    });

    test('play without a source does not acquire focus', () async {
      await expectLater(engine.play(), throwsStateError);
      expect(requests, 0);
    });

    test('loading does not acquire focus and denied play can be retried',
        () async {
      await engine.load(track());
      expect(requests, 0);
      granted = false;
      await engine.play();
      expect(service.plays, isEmpty);
      expect(service.resumes, 0);

      granted = true;
      await engine.play();
      expect(requests, 2);
      expect(service.plays, hasLength(1));
    });

    test(
      'every resume reacquires focus without reloading or seeking',
      () async {
        await engine.load(track());
        await engine.play();
        service.positionNotifier.value = const Duration(seconds: 7);
        await engine.pause();
        granted = false;
        await engine.play();
        expect(service.resumes, 0);
        expect(service.stateNotifier.value, RustPlaybackState.paused);

        granted = true;
        await engine.play();
        expect(requests, 3);
        expect(service.resumes, 1);
        expect(service.plays, hasLength(1));
        expect(service.seeks, isEmpty);
        expect(service.positionNotifier.value, const Duration(seconds: 7));
      },
    );

    test('a fresh track on a reused engine also requests focus', () async {
      await engine.load(track());
      await engine.play();
      await engine.pause();
      await engine.load(track(start: 13000, end: 31000));
      await engine.play();
      expect(requests, 2);
      expect(service.plays, hasLength(2));
      expect(service.resumes, 0);
    });
  });
}
