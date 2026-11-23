import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../data/repositories/song_repository.dart';
import '../models/song.dart';
import 'album_art_service.dart';
import 'player_service.dart';
import 'package:auno_player/l10n/english_l10n.dart';

class AlbumArtImportException implements Exception {
  const AlbumArtImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum AlbumArtScope { wholeAlbum, songOnly }

class AlbumArtUpdateResult {
  const AlbumArtUpdateResult({
    required this.albumName,
    required this.albumArtist,
    required this.albumArtPath,
    required this.filePaths,
  });

  final String albumName;
  final String albumArtist;
  final String? albumArtPath;
  final List<String> filePaths;
}

class AlbumArtImportService {
  AlbumArtImportService._({SongRepository? songRepository})
    : _songRepository = songRepository ?? SongRepository();

  static final AlbumArtImportService instance = AlbumArtImportService._();
  static const String _customArtworkDirectoryName = 'album_art_overrides';

  final SongRepository _songRepository;

  /// Stale network rows can survive in the local library; never treat one as
  /// a file whose artwork may be imported or reset.
  void _ensureLocalSong(Song song) {
    if (song.isNetworkSource) {
      throw AlbumArtImportException(l10n.artworkOnlyForLocalFiles);
    }
  }

  bool isCustomArtworkPath(String? path) {
    if (path == null || path.isEmpty) {
      return false;
    }

    final normalized = path.replaceAll('\\', '/');
    return normalized.contains('/$_customArtworkDirectoryName/');
  }

  Future<AlbumArtUpdateResult> applyImageBytes({
    required Song song,
    required Uint8List bytes,
  }) async {
    _ensureLocalSong(song);
    if (!_looksLikeImage(bytes)) {
      throw AlbumArtImportException(l10n.selectedFileIsNotASupported);
    }

    final group = await _resolveAlbumGroup(song);
    final filePaths = _albumFilePaths(group);
    final file = await _writeCustomArtwork(group.key, bytes);

    await _songRepository.updateAlbumArtPaths(filePaths, file.path);

    return AlbumArtUpdateResult(
      albumName: group.albumName,
      albumArtist: group.albumArtist,
      albumArtPath: file.path,
      filePaths: filePaths,
    );
  }

  Future<AlbumArtUpdateResult> removeCustomArtwork(Song song) async {
    _ensureLocalSong(song);
    final group = await _resolveAlbumGroup(song);
    final filePaths = _albumFilePaths(group);
    final customPaths = group.songs
        .map((entry) => entry.albumArt)
        .whereType<String>()
        .where(isCustomArtworkPath)
        .toSet();

    if (customPaths.isEmpty) {
      throw AlbumArtImportException(l10n.noCustomAlbumArtIsSet);
    }

    await _songRepository.updateAlbumArtPaths(filePaths, null);

    for (final path in customPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Best effort cleanup.
      }
    }

    return AlbumArtUpdateResult(
      albumName: group.albumName,
      albumArtist: group.albumArtist,
      albumArtPath: null,
      filePaths: filePaths,
    );
  }

  Future<AlbumArtUpdateResult> applyImageBytesToSong({
    required Song song,
    required Uint8List bytes,
  }) async {
    _ensureLocalSong(song);
    if (!_looksLikeImage(bytes)) {
      throw AlbumArtImportException(l10n.selectedFileIsNotASupported);
    }

    final filePath = song.filePath;
    if (filePath == null || filePath.isEmpty) {
      throw AlbumArtImportException(l10n.songHasNoFilePath);
    }

    final file = await _writeCustomArtwork(filePath, bytes);
    await _songRepository.updateAlbumArtPath(filePath, file.path);

    return AlbumArtUpdateResult(
      albumName: song.album ?? song.title,
      albumArtist: song.albumArtist ?? song.artist,
      albumArtPath: file.path,
      filePaths: [filePath],
    );
  }

  Future<AlbumArtUpdateResult> removeCustomArtworkForSong(Song song) async {
    _ensureLocalSong(song);
    final filePath = song.filePath;
    if (filePath == null || filePath.isEmpty) {
      throw AlbumArtImportException(l10n.songHasNoFilePath);
    }

    final currentPath = song.albumArt;
    if (currentPath == null || !isCustomArtworkPath(currentPath)) {
      throw AlbumArtImportException(l10n.noCustomAlbumArtIsSet);
    }

    await _songRepository.updateAlbumArtPath(filePath, null);

    try {
      final file = File(currentPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort cleanup.
    }

    return AlbumArtUpdateResult(
      albumName: song.album ?? song.title,
      albumArtist: song.albumArtist ?? song.artist,
      albumArtPath: null,
      filePaths: [filePath],
    );
  }

  /// Clears auto-resolved artwork for an album and re-derives it from the
  /// files themselves. Custom (user-picked) artwork is left untouched.
  Future<AlbumArtUpdateResult> resetArtwork(Song song) async {
    _ensureLocalSong(song);
    final group = await _resolveAlbumGroup(song);
    return _resetArtworkEntries(
      albumName: group.albumName,
      albumArtist: group.albumArtist,
      songs: group.songs,
    );
  }

  /// Like [resetArtwork] but only for [song].
  Future<AlbumArtUpdateResult> resetArtworkForSong(Song song) async {
    _ensureLocalSong(song);
    return _resetArtworkEntries(
      albumName: song.album ?? song.title,
      albumArtist: song.albumArtist ?? song.artist,
      songs: [song],
    );
  }

  Future<AlbumArtUpdateResult> _resetArtworkEntries({
    required String albumName,
    required String albumArtist,
    required List<Song> songs,
  }) async {
    final filePaths = <String>[];
    for (final entry in songs) {
      final path = entry.filePath;
      if (path == null || path.isEmpty) continue;
      if (isCustomArtworkPath(entry.albumArt)) continue;
      filePaths.add(path);
    }

    if (filePaths.isEmpty) {
      throw AlbumArtImportException(l10n.noLibraryFilesForThisAlbum);
    }

    for (final path in filePaths) {
      await _songRepository.updateAlbumArtPath(path, null);
    }

    // Drop stale in-memory artwork first so a reset is visible immediately,
    // then re-derive per file (a successful resolve syncs on its own).
    PlayerService().syncAlbumArtPaths(filePaths: filePaths, albumArtPath: null);

    final artService = AlbumArtService.instance;
    for (final path in filePaths) {
      artService.evictFolderCoverCache(path);
      try {
        await artService.resolveArtworkPath(audioSourcePath: path);
      } catch (_) {
        // Best effort: CachedImageWidget retries on the next build.
      }
    }

    return AlbumArtUpdateResult(
      albumName: albumName,
      albumArtist: albumArtist,
      albumArtPath: null,
      filePaths: filePaths,
    );
  }

  Future<AlbumGroup> _resolveAlbumGroup(Song song) async {
    final group = await _songRepository.getAlbumGroupForSong(song);
    if (group == null || group.songs.isEmpty) {
      throw AlbumArtImportException(l10n.couldNotResolveTheAlbum);
    }
    return group;
  }

  List<String> _albumFilePaths(AlbumGroup group) {
    final filePaths = group.songs
        .map((entry) => entry.filePath)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList();
    if (filePaths.isEmpty) {
      throw AlbumArtImportException(l10n.noLibraryFilesForThisAlbum);
    }
    return filePaths;
  }

  Future<File> _writeCustomArtwork(String albumKey, Uint8List bytes) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final artworkDirectory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}$_customArtworkDirectoryName',
    );
    if (!await artworkDirectory.exists()) {
      await artworkDirectory.create(recursive: true);
    }

    final digest = md5.convert(utf8.encode(albumKey)).toString();
    final file = File(
      '${artworkDirectory.path}${Platform.pathSeparator}$digest.cover',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.isEmpty) {
      return false;
    }

    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true;
    }

    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return true;
    }

    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return true;
    }

    return false;
  }
}
