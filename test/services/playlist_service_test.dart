import 'dart:io';

import 'package:auno_player/models/playlist.dart';
import 'package:auno_player/services/playlist_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('song added-at timestamps', () {
    test('addSongToPlaylist records the add timestamp', () async {
      final service = PlaylistService();
      final playlist = await service.createPlaylist('Test');
      expect(playlist, isNotNull);

      await service.addSongToPlaylist(playlist!.id, 'song-1');
      await service.addSongToPlaylist(playlist.id, 'song-2');

      final updated = await service.getPlaylist(playlist.id);
      expect(updated!.songIds, ['song-1', 'song-2']);
      expect(updated.songAddedAt['song-1'], isNotNull);
      expect(updated.songAddedAt['song-2'], isNotNull);
      expect(
        updated.songAddedAt['song-2']!.isAfter(updated.songAddedAt['song-1']!),
        isTrue,
      );
    });

    test('timestamps are pruned when a song is removed', () async {
      final service = PlaylistService();
      final playlist = await service.createPlaylist('Test');
      await service.addSongToPlaylist(playlist!.id, 'song-1');
      await service.addSongToPlaylist(playlist.id, 'song-2');

      await service.removeSongFromPlaylist(playlist.id, 'song-1');

      final updated = await service.getPlaylist(playlist.id);
      expect(updated!.songIds, ['song-2']);
      expect(updated.songAddedAt.containsKey('song-1'), isFalse);
      expect(updated.songAddedAt.containsKey('song-2'), isTrue);
    });

    test('timestamps survive a reload from prefs', () async {
      final service = PlaylistService();
      final playlist = await service.createPlaylist('Test');
      await service.addSongToPlaylist(playlist!.id, 'song-1');
      final addedAt = (await service.getPlaylist(
        playlist.id,
      ))!.songAddedAt['song-1'];

      final reloaded = PlaylistService();
      final updated = await reloaded.getPlaylist(playlist.id);
      expect(updated!.songAddedAt['song-1'], addedAt);
    });

    test('legacy playlists without timestamps stay readable', () async {
      final legacy = Playlist.fromJson({
        'id': 'p1',
        'name': 'Legacy',
        'songIds': ['song-1'],
        'createdAt': DateTime(2024).toIso8601String(),
      });
      expect(legacy.songAddedAt, isEmpty);
      expect(legacy.songIds, ['song-1']);
    });
  });

  group('playlist covers', () {
    late Directory storageDir;

    setUp(() async {
      storageDir = await Directory.systemTemp.createTemp(
        'playlist_cover_test_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => storageDir.path,
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (await storageDir.exists()) {
        await storageDir.delete(recursive: true);
      }
    });

    Future<File> createSourceImage(String name) async {
      final file = File('${storageDir.path}/$name');
      await file.writeAsBytes([1, 2, 3, 4]);
      return file;
    }

    test('copies the image into app storage and persists it', () async {
      final service = PlaylistService();
      final playlist = await service.createPlaylist('Test');
      final source = await createSourceImage('picked.jpg');

      expect(await service.setPlaylistCover(playlist!.id, source.path), isTrue);

      final updated = await service.getPlaylist(playlist.id);
      final coverPath = updated!.coverPath;
      expect(coverPath, isNotNull);
      expect(coverPath, contains('playlist_covers'));
      expect(await File(coverPath!).exists(), isTrue);
      expect(await source.exists(), isTrue);

      final reloaded = PlaylistService();
      final persisted = await reloaded.getPlaylist(playlist.id);
      expect(persisted!.coverPath, coverPath);
    });

    test('replacing a cover deletes the previous file', () async {
      final service = PlaylistService();
      final playlist = await service.createPlaylist('Test');
      await service.setPlaylistCover(
        playlist!.id,
        (await createSourceImage('first.jpg')).path,
      );
      final oldPath = (await service.getPlaylist(playlist.id))!.coverPath!;

      await service.setPlaylistCover(
        playlist.id,
        (await createSourceImage('second.png')).path,
      );

      final newPath = (await service.getPlaylist(playlist.id))!.coverPath!;
      expect(newPath, isNot(oldPath));
      expect(newPath, endsWith('.png'));
      expect(await File(oldPath).exists(), isFalse);
      expect(await File(newPath).exists(), isTrue);
    });

    test('removing a cover clears the path and deletes the file', () async {
      final service = PlaylistService();
      final playlist = await service.createPlaylist('Test');
      await service.setPlaylistCover(
        playlist!.id,
        (await createSourceImage('cover.jpg')).path,
      );
      final coverPath = (await service.getPlaylist(playlist.id))!.coverPath!;

      expect(await service.removePlaylistCover(playlist.id), isTrue);

      final updated = await service.getPlaylist(playlist.id);
      expect(updated!.coverPath, isNull);
      expect(await File(coverPath).exists(), isFalse);

      final reloaded = PlaylistService();
      expect((await reloaded.getPlaylist(playlist.id))!.coverPath, isNull);
    });

    test('deleting a playlist deletes its cover file', () async {
      final service = PlaylistService();
      final playlist = await service.createPlaylist('Test');
      await service.setPlaylistCover(
        playlist!.id,
        (await createSourceImage('cover.jpg')).path,
      );
      final coverPath = (await service.getPlaylist(playlist.id))!.coverPath!;

      expect(await service.deletePlaylist(playlist.id), isTrue);

      expect(await service.getPlaylist(playlist.id), isNull);
      expect(await File(coverPath).exists(), isFalse);
    });

    test('a missing source image is rejected', () async {
      final service = PlaylistService();
      final playlist = await service.createPlaylist('Test');

      final changed = await service.setPlaylistCover(
        playlist!.id,
        '${storageDir.path}/missing.jpg',
      );

      expect(changed, isFalse);
      expect((await service.getPlaylist(playlist.id))!.coverPath, isNull);
    });

    test('clearAll deletes every cover file', () async {
      final service = PlaylistService();
      final first = (await service.createPlaylist('First'))!;
      final second = (await service.createPlaylist('Second'))!;
      await service.setPlaylistCover(
        first.id,
        (await createSourceImage('first.jpg')).path,
      );
      await service.setPlaylistCover(
        second.id,
        (await createSourceImage('second.jpg')).path,
      );
      final paths = (await service.getPlaylists())
          .map((playlist) => playlist.coverPath!)
          .toList();

      await service.clearAll();

      expect(await service.getPlaylists(), isEmpty);
      for (final path in paths) {
        expect(await File(path).exists(), isFalse);
      }
    });
  });

  group('playlist rename', () {
    test('renames a local playlist and persists the new name', () async {
      final service = PlaylistService();
      final created = (await service.createPlaylist('Old name'))!;

      final updated = await service.updatePlaylist(
        created.copyWith(name: '  New name  '),
      );

      expect(updated?.name, 'New name');
      final reloaded = await PlaylistService().getPlaylists();
      expect(reloaded.single.name, 'New name');
    });

    test('rejects a name already used by another playlist', () async {
      final service = PlaylistService();
      final first = (await service.createPlaylist('One'))!;
      await service.createPlaylist('Two');

      final updated = await service.updatePlaylist(
        first.copyWith(name: 'two'),
      );

      expect(updated, isNull);
      final playlists = await service.getPlaylists();
      expect(playlists.map((p) => p.name), ['One', 'Two']);
    });

    test('rejects an empty name', () async {
      final service = PlaylistService();
      final created = (await service.createPlaylist('Old'))!;

      expect(
        await service.updatePlaylist(created.copyWith(name: '   ')),
        isNull,
      );
      expect((await service.getPlaylist(created.id))!.name, 'Old');
    });
  });
}
