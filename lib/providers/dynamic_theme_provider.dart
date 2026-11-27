import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:auno_player/core/theme/dynamic_palette.dart';
import 'package:auno_player/models/song.dart';
import 'package:auno_player/providers/player_provider.dart';

/// Stable cache identity for a song's cover: album when available, else song.
String paletteCacheKeyForSong(Song song) {
  final album = song.album?.trim();
  if (album != null && album.isNotEmpty) {
    final artist = (song.albumArtist ?? song.artist).trim().toLowerCase();
    return 'album:$artist|${album.toLowerCase()}';
  }
  return 'song:${song.id}';
}

/// Palette for the current track. Cached entries resolve without a frame of
/// neutral color, so skipping inside an album is instant.
final dynamicPaletteProvider = FutureProvider<DynamicThemePalette>((ref) async {
  final song = ref.watch(currentSongProvider);
  if (song == null) return DynamicThemePalette.neutral;

  final key = paletteCacheKeyForSong(song);
  final cached = DynamicPaletteService.instance.cached(key);
  if (cached != null) return cached;

  final palette = await DynamicPaletteService.instance.paletteFor(
    key: key,
    imagePath: song.albumArt,
  );
  return palette ?? DynamicThemePalette.neutral;
});
