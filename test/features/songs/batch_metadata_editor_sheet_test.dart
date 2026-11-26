import 'package:auno_player/features/songs/widgets/batch_metadata_editor_sheet.dart';
import 'package:auno_player/l10n/english_l10n.dart';
import 'package:auno_player/models/song.dart';
import 'package:auno_player/services/metadata_editor_service.dart';
import 'package:auno_player/src/rust/api/metadata_editor.dart' as rust_metadata;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Song> _songs = [
  Song(
    id: 'a',
    title: 'First',
    artist: 'Artist A',
    filePath: '/tmp/auno-a.flac',
    duration: Duration(minutes: 3),
    fileType: 'FLAC',
  ),
  Song(
    id: 'b',
    title: 'Second',
    artist: 'Artist B',
    filePath: '/tmp/auno-b.flac',
    duration: Duration(minutes: 4),
    fileType: 'FLAC',
  ),
];

MetadataEditorService _fakeService(
  List<rust_metadata.TagEditFields> writes,
) {
  return MetadataEditorService.forTesting(
    writeTagFile: (path, fields) async {
      writes.add(fields);
      return const rust_metadata.TagWriteResult(success: true);
    },
    readTagFile: (path) async => null,
    persistMetadata: (path, fields) async {},
    temporaryDirectory: () async => throw UnsupportedError('no SAF in test'),
  );
}

/// Hosts the sheet on a pushed route so a successful save can pop it without
/// taking the root route down with it.
Widget _host(
  List<Song> songs, {
  required MetadataEditorService service,
  void Function(Song song, rust_metadata.TagEditFields fields)? onSongSynced,
}) {
  final sheet = BatchMetadataEditorSheet(
    songs: songs,
    service: service,
    onSongSynced: onSongSynced ?? (_, __) {},
  );
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: kAppLocalizationsDelegates,
      supportedLocales: kSupportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('openBatchEditor'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(body: sheet),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('openBatchEditor')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('writes only the filled fields to every editable song',
      (tester) async {
    final writes = <rust_metadata.TagEditFields>[];
    final synced = <String>[];

    await tester.pumpWidget(
      _host(
        _songs,
        service: _fakeService(writes),
        onSongSynced: (song, fields) => synced.add(song.id),
      ),
    );
    await _openEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('batchField_album')),
      'Remastered',
    );
    await tester.enterText(
      find.byKey(const ValueKey('batchField_year')),
      '1999',
    );
    await tester.tap(find.text(l10n.saveChanges));
    await tester.pumpAndSettle();

    expect(writes, hasLength(2));
    for (final fields in writes) {
      expect(fields.album, 'Remastered');
      expect(fields.year, 1999);
      expect(fields.artist, isNull);
      expect(fields.albumArtist, isNull);
      expect(fields.genre, isNull);
      expect(fields.title, isNull);
      expect(fields.trackNumber, isNull);
    }
    expect(synced, ['a', 'b']);
  });

  testWidgets('skips songs that cannot be edited as files', (tester) async {
    final writes = <rust_metadata.TagEditFields>[];
    const songs = [
      Song(
        id: 'a',
        title: 'First',
        artist: 'Artist A',
        filePath: '/tmp/auno-a.flac',
        duration: Duration(minutes: 3),
        fileType: 'FLAC',
      ),
      Song(
        id: 'ext',
        title: 'External',
        artist: 'Artist X',
        filePath: '/tmp/auno-ext.flac',
        duration: Duration(minutes: 1),
        fileType: 'FLAC',
        isExternal: true,
      ),
    ];

    await tester.pumpWidget(
      _host(songs, service: _fakeService(writes)),
    );
    await _openEditor(tester);

    expect(find.text(l10n.batchEditSomeSkipped(1)), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('batchField_genre')),
      'Ambient',
    );
    await tester.tap(find.text(l10n.saveChanges));
    await tester.pumpAndSettle();

    expect(writes, hasLength(1));
    expect(writes.single.genre, 'Ambient');
  });

  testWidgets('rejects an out-of-range year without writing', (tester) async {
    final writes = <rust_metadata.TagEditFields>[];

    await tester.pumpWidget(_host(_songs, service: _fakeService(writes)));
    await _openEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('batchField_year')),
      '12000',
    );
    await tester.pump();

    expect(find.text(l10n.enterAYear19999), findsOneWidget);
    await tester.tap(find.text(l10n.saveChanges));
    await tester.pumpAndSettle();

    expect(writes, isEmpty);
  });
}
