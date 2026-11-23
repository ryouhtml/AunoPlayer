import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:auno_player/data/entities/listening_event_entity.dart';
import 'package:auno_player/data/repositories/recently_played_repository.dart';
import 'package:auno_player/services/listening_stats_service.dart';
import 'package:auno_player/services/replay_play_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

String _isarCorePath() {
  final override = Platform.environment['ISAR_CORE_LIB'];
  if (override != null) return override;
  final config = File('.dart_tool/package_config.json').absolute;
  final packages = jsonDecode(config.readAsStringSync())['packages'] as List;
  final package = packages.firstWhere(
    (dynamic item) => item['name'] == 'isar_community_flutter_libs',
  );
  final root = config.uri.resolve(package['rootUri'] as String);
  final library = switch (Abi.current()) {
    Abi.linuxX64 || Abi.linuxArm || Abi.linuxArm64 => 'linux/libisar.so',
    Abi.macosX64 || Abi.macosArm64 => 'macos/libisar.dylib',
    Abi.windowsX64 => 'windows/isar.dll',
    _ => throw UnsupportedError('Set ISAR_CORE_LIB for ${Abi.current()}'),
  };
  return Directory.fromUri(root).uri.resolve(library).toFilePath();
}

class _EmptyLegacy extends RecentlyPlayedRepository {
  @override
  Future<Map<ListeningRecapPeriod, ListeningRecap>> getListeningRecaps({
    Iterable<ListeningRecapPeriod>? periods,
    DateTime? now,
  }) async => const {};

  @override
  Future<ListeningRecap> getListeningRecap(
    ListeningRecapPeriod period, {
    DateTime? now,
  }) async => ListeningRecap.empty(period, period.rangeFor(now ?? DateTime.now()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Isar isar;
  late ListeningStatsService service;

  final now = DateTime(2026, 11, 23, 20, 10);

  setUpAll(() async {
    Isar.initializeIsarCore(libraries: {Abi.current(): _isarCorePath()});
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('auno_listening_stats');
    isar = await Isar.open(
      [ListeningEventEntitySchema],
      directory: dir.path,
      name: p.basename(dir.path),
    );
    service = ListeningStatsService(isar: isar, legacy: _EmptyLegacy());
  });

  tearDown(() async {
    await isar.close();
    await dir.delete(recursive: true);
  });

  Future<void> addEvent(
    String sessionId,
    DateTime at,
    int listenedMs, {
    String artist = 'Artist A',
  }) {
    return service.recordSession(
      ListeningSessionSnapshot(
        songId: 'local-a',
        sessionId: sessionId,
        startedAt: at,
        listenedMs: listenedMs,
        completedRatio: 0.8,
        title: 'Song A',
        artist: artist,
        album: 'Album A',
      ),
    );
  }

  test('aggregates actual listening time, hour buckets, and dedupes sessions',
      () async {
    await addEvent('session-1', now.subtract(const Duration(hours: 2)), 120000);
    await addEvent('session-2', now.subtract(const Duration(hours: 1)), 60000);
    await addEvent('session-2', now.subtract(const Duration(hours: 1)), 60000);
    await addEvent(
      'session-3',
      now.subtract(const Duration(days: 1, hours: 2)),
      30000,
      artist: 'Artist B',
    );

    final recaps = await service.getRecaps(
      periods: {ListeningRecapPeriod.daily, ListeningRecapPeriod.yearly},
      now: now,
    );
    final daily = recaps[ListeningRecapPeriod.daily]!;
    final yearly = recaps[ListeningRecapPeriod.yearly]!;

    expect(daily.totalPlays, 2);
    expect(daily.actualListenedMs, 180000);
    expect(daily.totalListeningTime, const Duration(milliseconds: 180000));
    expect(daily.hourBuckets![18], 120000);
    expect(daily.hourBuckets![19], 60000);
    expect(daily.streakDays, 2);
    expect(daily.topSong!.song.title, 'Song A');
    expect(daily.uniqueArtists, 1);

    expect(yearly.totalPlays, 3);
    expect(yearly.actualListenedMs, 210000);
    expect(yearly.uniqueArtists, 2);
    expect(yearly.activeDays, 2);
  });

  test('falls back to the legacy recap when no new events exist', () async {
    final recaps = await service.getRecaps(
      periods: {ListeningRecapPeriod.daily},
      now: now,
    );
    expect(recaps[ListeningRecapPeriod.daily], isNotNull);
    expect(recaps[ListeningRecapPeriod.daily]!.actualListenedMs, isNull);
  });

  test('clearEvents removes all persisted sessions', () async {
    await addEvent('session-1', now, 1000);
    await service.clearEvents();
    final recaps = await service.getRecaps(
      periods: {ListeningRecapPeriod.daily},
      now: now,
    );
    expect(recaps[ListeningRecapPeriod.daily]!.actualListenedMs, isNull);
  });
}
