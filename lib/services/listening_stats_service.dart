import 'package:isar_community/isar.dart';

import '../data/database.dart';
import '../data/entities/listening_event_entity.dart';
import '../data/repositories/recently_played_repository.dart';
import '../data/repositories/song_repository.dart';
import '../models/song.dart';
import 'replay_play_tracker.dart';

/// Local-only listening event storage and recap aggregation.
///
/// The service never contacts a network. When no new events exist it returns
/// the legacy recap so older installations still show meaningful history.
class ListeningStatsService {
  ListeningStatsService({Isar? isar, RecentlyPlayedRepository? legacy})
    : _isar = isar,
      _legacy = legacy;

  Isar? _isar;
  final RecentlyPlayedRepository? _legacy;

  static const int maxEvents = 50000;

  Isar get _database => _isar ??= Database.instance;

  RecentlyPlayedRepository get _legacyRepository =>
      _legacy ?? RecentlyPlayedRepository(isar: _database);

  /// Persist one deduplicated listening session.
  Future<void> recordSession(ListeningSessionSnapshot session) async {
    final songId = int.tryParse(session.songId) ?? 0;
    final entity = ListeningEventEntity()
      ..songId = songId
      ..sessionId = session.sessionId
      ..playedAt = session.startedAt
      ..listenedMs = session.listenedMs.clamp(0, 1 << 62).toInt()
      ..completedRatio = session.completedRatio.clamp(0.0, 1.0)
      ..title = session.title
      ..artist = session.artist
      ..album = session.album;

    await _database.writeTxn(() async {
      await _database.listeningEventEntitys.put(entity);
      final count = await _database.listeningEventEntitys.count();
      if (count > maxEvents) {
        final old = await _database.listeningEventEntitys
            .where()
            .sortByPlayedAt()
            .limit(count - maxEvents)
            .findAll();
        await _database.listeningEventEntitys
            .deleteAll(old.map((event) => event.id).toList());
      }
    });
  }

  /// Remove locally stored listening events when the user clears history.
  Future<void> clearEvents() async {
    await _database.writeTxn(() async {
      await _database.listeningEventEntitys.clear();
    });
  }

  /// Build recaps for the requested periods from real listening events.
  Future<Map<ListeningRecapPeriod, ListeningRecap>> getRecaps({
    required Set<ListeningRecapPeriod> periods,
    DateTime? now,
  }) async {
    final anchor = now ?? DateTime.now();
    final streakDays = await _computeGlobalStreak(anchor);
    final result = <ListeningRecapPeriod, ListeningRecap>{};
    for (final period in periods) {
      final range = period.rangeFor(anchor);
      final events = await _eventsBetween(range.start, range.endExclusive);
      if (events.isEmpty) {
        result[period] = await _legacyRepository.getListeningRecap(
          period,
          now: now,
        );
      } else {
        result[period] = await _buildRecap(
          period,
          range,
          events,
          anchor,
          streakDays: streakDays,
        );
      }
    }
    return result;
  }

  Future<List<ListeningEventEntity>> _eventsBetween(
    DateTime start,
    DateTime endExclusive,
  ) async {
    final events = await _database.listeningEventEntitys
        .where()
        .playedAtBetween(start, endExclusive, includeUpper: false)
        .findAll();
    // A changed system clock must not create absurd future rows or rows from
    // a decade ago. Deduplicate by session id in case a write was retried.
    final lowerBound = start.subtract(const Duration(days: 3650));
    final upperBound = endExclusive.add(const Duration(days: 1));
    final seen = <String>{};
    return events.where((event) {
      if (event.playedAt.isBefore(lowerBound) ||
          event.playedAt.isAfter(upperBound)) {
        return false;
      }
      return seen.add(event.sessionId);
    }).toList();
  }

  Future<ListeningRecap> _buildRecap(
    ListeningRecapPeriod period,
    ListeningRecapRange range,
    List<ListeningEventEntity> events,
    DateTime anchor, {
    required int streakDays,
  }) async {
    final songStats = <int, _Accumulator>{};
    final artistStats = <String, _Accumulator>{};
    final albumStats = <String, _Accumulator>{};
    final activeDays = <DateTime>{};
    final hourBuckets = <int, int>{};
    var totalMs = 0;
    var completedRatioSum = 0.0;
    DateTime? firstListenedAt;
    DateTime? lastPlayedAt;

    for (final event in events) {
      final listenedMs = event.listenedMs.clamp(0, 1 << 62).toInt();
      totalMs += listenedMs;
      completedRatioSum += event.completedRatio.clamp(0.0, 1.0);
      final day = DateTime(
        event.playedAt.year,
        event.playedAt.month,
        event.playedAt.day,
      );
      activeDays.add(day);
      hourBuckets[event.playedAt.hour] =
          (hourBuckets[event.playedAt.hour] ?? 0) + listenedMs;
      firstListenedAt = _earlier(firstListenedAt, event.playedAt);
      lastPlayedAt = _later(lastPlayedAt, event.playedAt);

      final song = songStats.putIfAbsent(
        event.songId,
        () => _Accumulator(
          id: event.songId,
          title: event.title,
          artist: event.artist,
          album: event.album,
        ),
      );
      song.add(event);
      final artistKey = event.artist.trim().toLowerCase();
      if (artistKey.isNotEmpty) {
        final artist = artistStats.putIfAbsent(
          artistKey,
          () => _Accumulator(id: 0, title: event.artist),
        );
        artist.add(event);
      }
      final albumKey =
          '${event.album.trim().toLowerCase()}\u0000${artistKey}';
      if (event.album.trim().isNotEmpty) {
        final album = albumStats.putIfAbsent(
          albumKey,
          () => _Accumulator(
            id: 0,
            title: event.album,
            artist: event.artist,
          ),
        );
        album.add(event);
      }
    }

    final topSongAcc = _sorted(songStats.values).take(5).toList();
    final topArtistAcc = _sorted(artistStats.values).take(5).toList();
    final topAlbumAcc = _sorted(albumStats.values).take(5).toList();

    final rankedSongs = <RankedRecapSong>[];
    for (final acc in topSongAcc) {
      final stored = acc.id == 0 ? null : await _songRepository.getSongById(acc.id);
      rankedSongs.add(
        RankedRecapSong(
          song: stored ?? _snapshotSong(acc, totalMs),
          plays: acc.plays,
          listeningTime: Duration(milliseconds: acc.listenedMs),
          lastPlayedAt: acc.lastPlayedAt,
        ),
      );
    }

    final peakHour = hourBuckets.entries.isEmpty
        ? null
        : hourBuckets.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return ListeningRecap(
      period: period,
      start: range.start,
      endExclusive: range.endExclusive,
      totalPlays: events.length,
      totalListeningTime: Duration(milliseconds: totalMs),
      uniqueSongs: songStats.length,
      uniqueArtists: artistStats.length,
      activeDays: activeDays.length,
      peakHour: peakHour,
      topSong: rankedSongs.isEmpty ? null : rankedSongs.first,
      topArtist: topArtistAcc.isEmpty
          ? null
          : RankedRecapArtist(
              artist: topArtistAcc.first.title,
              plays: topArtistAcc.first.plays,
              uniqueSongs: topArtistAcc.first.songIds.length,
              listeningTime: Duration(milliseconds: topArtistAcc.first.listenedMs),
              lastPlayedAt: topArtistAcc.first.lastPlayedAt,
            ),
      topAlbum: topAlbumAcc.isEmpty
          ? null
          : RankedRecapAlbum(
              album: topAlbumAcc.first.title,
              artist: topAlbumAcc.first.artist,
              plays: topAlbumAcc.first.plays,
              uniqueSongs: topAlbumAcc.first.songIds.length,
              listeningTime: Duration(milliseconds: topAlbumAcc.first.listenedMs),
              lastPlayedAt: topAlbumAcc.first.lastPlayedAt,
              representativeSong: _snapshotSong(topAlbumAcc.first, totalMs),
            ),
      topSongs: rankedSongs,
      topArtists: topArtistAcc
          .map(
            (acc) => RankedRecapArtist(
              artist: acc.title,
              plays: acc.plays,
              uniqueSongs: acc.songIds.length,
              listeningTime: Duration(milliseconds: acc.listenedMs),
              lastPlayedAt: acc.lastPlayedAt,
            ),
          )
          .toList(growable: false),
      topAlbums: topAlbumAcc
          .map(
            (acc) => RankedRecapAlbum(
              album: acc.title,
              artist: acc.artist,
              plays: acc.plays,
              uniqueSongs: acc.songIds.length,
              listeningTime: Duration(milliseconds: acc.listenedMs),
              lastPlayedAt: acc.lastPlayedAt,
              representativeSong: _snapshotSong(acc, totalMs),
            ),
          )
          .toList(growable: false),
      actualListenedMs: totalMs,
      streakDays: streakDays,
      hourBuckets: Map<int, int>.unmodifiable(hourBuckets),
      firstListenedAt: firstListenedAt,
      listeningPersonality: _personality(
        peakHour: peakHour,
        averageCompletion: completedRatioSum / events.length,
        uniqueSongs: songStats.length,
        plays: events.length,
      ),
    );
  }

  late final SongRepository _songRepository = SongRepository(isar: _database);

  static Song _snapshotSong(_Accumulator acc, int fallbackMs) {
    return Song(
      id: acc.id == 0 ? '0' : '$acc.id',
      title: acc.title,
      artist: acc.artist,
      album: acc.album,
      duration: Duration(milliseconds: acc.listenedMs == 0 ? fallbackMs : acc.listenedMs),
      fileType: 'LOCAL',
    );
  }

  static DateTime? _earlier(DateTime? a, DateTime b) =>
      a == null || b.isBefore(a) ? b : a;

  static DateTime? _later(DateTime? a, DateTime b) =>
      a == null || b.isAfter(a) ? b : a;

  static List<_Accumulator> _sorted(Iterable<_Accumulator> values) {
    final list = values.toList()
      ..sort((a, b) {
        final plays = b.plays.compareTo(a.plays);
        if (plays != 0) return plays;
        final time = b.listenedMs.compareTo(a.listenedMs);
        if (time != 0) return time;
        return b.lastPlayedAt.compareTo(a.lastPlayedAt);
      });
    return list;
  }

  Future<int> _computeGlobalStreak(DateTime anchor) async {
    final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
    final events = await _eventsBetween(
      anchorDay.subtract(const Duration(days: 400)),
      anchorDay.add(const Duration(days: 1)),
    );
    final activeDays = <DateTime>{};
    for (final event in events) {
      activeDays.add(
        DateTime(
          event.playedAt.year,
          event.playedAt.month,
          event.playedAt.day,
        ),
      );
    }
    return _streakDays(activeDays, anchorDay);
  }

  static int _streakDays(Set<DateTime> activeDays, DateTime anchor) {
    if (activeDays.isEmpty) return 0;
    var cursor = DateTime(anchor.year, anchor.month, anchor.day);
    if (!activeDays.contains(cursor)) {
      final latest = activeDays.reduce((a, b) => a.isAfter(b) ? a : b);
      if (latest != cursor.subtract(const Duration(days: 1))) return 0;
      cursor = latest;
    }
    var streak = 0;
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static String _personality({
    required int? peakHour,
    required double averageCompletion,
    required int uniqueSongs,
    required int plays,
  }) {
    if (peakHour != null && (peakHour >= 21 || peakHour < 5)) {
      return 'nightOwl';
    }
    if (averageCompletion >= 0.8 && plays > 0) return 'completionist';
    if (uniqueSongs >= plays * 0.7 && plays >= 3) return 'explorer';
    return 'balanced';
  }
}

class _Accumulator {
  _Accumulator({
    required this.id,
    required this.title,
    this.artist = '',
    this.album = '',
  });

  final int id;
  final String title;
  final String artist;
  final String album;
  final Set<int> songIds = <int>{};
  int listenedMs = 0;
  int plays = 0;
  DateTime lastPlayedAt = DateTime.fromMillisecondsSinceEpoch(0);

  void add(ListeningEventEntity event) {
    songIds.add(event.songId);
    listenedMs += event.listenedMs.clamp(0, 1 << 62).toInt();
    plays++;
    if (event.playedAt.isAfter(lastPlayedAt)) lastPlayedAt = event.playedAt;
  }
}
