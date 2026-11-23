import 'package:isar_community/isar.dart';

part 'listening_event_entity.g.dart';

/// One deduplicated listening session used by listening statistics and recap.
///
/// Unlike the legacy recently-played collection, this stores the actual
/// listened duration and a snapshot of the track metadata so recaps remain
/// correct if a file is later moved or deleted.
@collection
class ListeningEventEntity {
  Id id = Isar.autoIncrement;

  /// MediaStore/Isar song id. Zero when the song id is not numeric.
  @Index()
  late int songId;

  /// Stable id for one play session; pause/resume reuses the same value.
  @Index()
  late String sessionId;

  /// Time the session started (or crossed the counting threshold).
  @Index()
  late DateTime playedAt;

  /// Actual time heard, in milliseconds — never the file's full duration.
  late int listenedMs;

  /// 0.0..=1.0 portion of the track heard in this session.
  late double completedRatio;

  /// Metadata snapshot for resilient recaps.
  late String title;
  late String artist;
  late String album;
}
