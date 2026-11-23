import 'package:auno_player/data/entities/listening_event_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ListeningEventEntity pins Isar property ids', () {
    // Isar identifies persisted properties by numeric id. Adding or renaming
    // fields must not silently shift these ids for existing installations.
    expect(ListeningEventEntitySchema.properties['album']?.id, 0);
    expect(ListeningEventEntitySchema.properties['artist']?.id, 1);
    expect(ListeningEventEntitySchema.properties['completedRatio']?.id, 2);
    expect(ListeningEventEntitySchema.properties['listenedMs']?.id, 3);
    expect(ListeningEventEntitySchema.properties['playedAt']?.id, 4);
    expect(ListeningEventEntitySchema.properties['sessionId']?.id, 5);
    expect(ListeningEventEntitySchema.properties['songId']?.id, 6);
    expect(ListeningEventEntitySchema.properties['title']?.id, 7);
  });
}
