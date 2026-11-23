import 'dart:io';
import 'package:auno_player/widgets/common/flick_snackbar.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auno_player/core/constants/app_constants.dart';
import 'package:auno_player/core/theme/adaptive_color_provider.dart';
import 'package:auno_player/core/theme/app_colors.dart';
import 'package:auno_player/models/song.dart';
import 'package:auno_player/services/album_art_import_service.dart';
import 'package:auno_player/services/player_service.dart';
import 'package:auno_player/widgets/common/cached_image_widget.dart';
import 'package:auno_player/widgets/common/glass_bottom_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:auno_player/l10n/english_l10n.dart';

class AlbumArtPickerBottomSheet extends StatefulWidget {
  const AlbumArtPickerBottomSheet({super.key, required this.song});

  final Song song;

  static Future<bool> show(BuildContext context, Song song) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await showModalBottomSheet<_AlbumArtSheetResult>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AppBottomSheetSurface(
        maxHeightRatio: 0.95,
        child: AlbumArtPickerBottomSheet(song: song),
      ),
    );

    final changed = result != null;
    if (!context.mounted || messenger == null || result == null) {
      return changed;
    }

    messenger
      .showFlickSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    return changed;
  }

  @override
  State<AlbumArtPickerBottomSheet> createState() =>
      _AlbumArtPickerBottomSheetState();
}

class _AlbumArtPickerBottomSheetState extends State<AlbumArtPickerBottomSheet> {
  final AlbumArtImportService _service = AlbumArtImportService.instance;
  final PlayerService _playerService = PlayerService();

  bool _isWorking = false;
  late bool _hasCustomArtwork;
  AlbumArtScope _scope = AlbumArtScope.wholeAlbum;

  @override
  void initState() {
    super.initState();
    _hasCustomArtwork = _service.isCustomArtworkPath(widget.song.albumArt);
  }

  Future<void> _pickLocalImage() async {
    if (_isWorking) {
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
        withData: kIsWeb,
      );
      final file = result?.files.single;
      if (file == null) {
        return;
      }

      final bytes = file.bytes ?? await _readFileBytes(file.path);
      if (bytes == null || bytes.isEmpty) {
        throw AlbumArtImportException(
          l10n.englishForFilipino.couldNotReadTheSelectedImage,
        );
      }

      await _runMutation(
        action: () => _scope == AlbumArtScope.wholeAlbum
            ? _service.applyImageBytes(song: widget.song, bytes: bytes)
            : _service.applyImageBytesToSong(song: widget.song, bytes: bytes),
        successMessage: (result) => _scope == AlbumArtScope.wholeAlbum
            ? l10n.englishForFilipino.updatedAlbumArtFor(result.albumName)
            : l10n.englishForFilipino.updatedAlbumArtFor2(widget.song.title),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showInlineMessage(error.toString());
    }
  }

  Future<void> _removeCustomArtwork() async {
    if (_isWorking) {
      return;
    }

    await _runMutation(
      action: () => _scope == AlbumArtScope.wholeAlbum
          ? _service.removeCustomArtwork(widget.song)
          : _service.removeCustomArtworkForSong(widget.song),
      successMessage: (result) => _scope == AlbumArtScope.wholeAlbum
          ? l10n.englishForFilipino.removedCustomAlbumArtFor(result.albumName)
          : l10n.englishForFilipino.removedCustomAlbumArtFor2(
              widget.song.title,
            ),
    );
  }

  Future<void> _resetArtwork() async {
    if (_isWorking) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.resetArtwork),
        content: Text(l10n.resetArtworkDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _runMutation(
      syncPlayer: false,
      action: () => _scope == AlbumArtScope.wholeAlbum
          ? _service.resetArtwork(widget.song)
          : _service.resetArtworkForSong(widget.song),
      successMessage: (result) => _scope == AlbumArtScope.wholeAlbum
          ? l10n.englishForFilipino.resetArtworkFor(result.albumName)
          : l10n.englishForFilipino.resetArtworkFor2(widget.song.title),
    );
  }

  Future<void> _runMutation({
    required Future<AlbumArtUpdateResult> Function() action,
    required String Function(AlbumArtUpdateResult result) successMessage,
    bool syncPlayer = true,
  }) async {
    setState(() {
      _isWorking = true;
    });

    try {
      final result = await action();
      if (syncPlayer) {
        _playerService.syncAlbumArtPaths(
          filePaths: result.filePaths,
          albumArtPath: result.albumArtPath,
        );
      }
      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pop(_AlbumArtSheetResult(message: successMessage(result)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showInlineMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<Uint8List?> _readFileBytes(String? path) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    return file.readAsBytes();
  }

  void _showInlineMessage(String message) {
    ScaffoldMessenger.of(context)
      .showFlickSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final previewPath = widget.song.albumArt;
    final previewSourcePath = widget.song.filePath;
    final albumName = widget.song.album?.trim();
    final albumArtist = widget.song.albumArtist?.trim();
    final effectiveAlbumArtist = (albumArtist != null && albumArtist.isNotEmpty)
        ? albumArtist
        : widget.song.artist;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDragHandle(),
              const SizedBox(height: AppConstants.spacingMd),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.setAlbumArt,
                          style: TextStyle(
                            fontFamily: 'GoogleSansFlex',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.adaptiveTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          albumName != null && albumName.isNotEmpty
                              ? '$albumName • $effectiveAlbumArtist'
                              : widget.song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'GoogleSansFlex',
                            fontSize: 14,
                            color: context.adaptiveTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSm),
              _buildScopeToggle(context),
              const SizedBox(height: AppConstants.spacingLg),
              _buildPreviewCard(
                context,
                imagePath: previewPath,
                audioSourcePath: previewSourcePath,
                title: _hasCustomArtwork
                    ? l10n.currentCustomArt
                    : l10n.currentArtwork,
                subtitle: effectiveAlbumArtist,
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Wrap(
                spacing: AppConstants.spacingSm,
                runSpacing: AppConstants.spacingSm,
                children: [
                  FilledButton.icon(
                    onPressed: _isWorking ? null : _pickLocalImage,
                    icon: const Icon(LucideIcons.folderOpen, size: 18),
                    label: Text(l10n.pickImage),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  if (_hasCustomArtwork)
                    OutlinedButton.icon(
                      onPressed: _isWorking ? null : _removeCustomArtwork,
                      icon: const Icon(LucideIcons.trash2, size: 18),
                      label: Text(l10n.removeCustomArt),
                    ),
                  if (!_hasCustomArtwork)
                    OutlinedButton.icon(
                      onPressed: _isWorking ? null : _resetArtwork,
                      icon: const Icon(LucideIcons.rotateCcw, size: 18),
                      label: Text(l10n.resetArtwork),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_isWorking)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.18),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildScopeToggle(BuildContext context) {
    return Row(
      children: [
        _buildScopeChip(
          context,
          label: l10n.wholeAlbum,
          icon: LucideIcons.disc3,
          selected: _scope == AlbumArtScope.wholeAlbum,
          onTap: () => setState(() => _scope = AlbumArtScope.wholeAlbum),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        _buildScopeChip(
          context,
          label: l10n.thisSongOnly,
          icon: LucideIcons.music,
          selected: _scope == AlbumArtScope.songOnly,
          onTap: () => setState(() => _scope = AlbumArtScope.songOnly),
        ),
      ],
    );
  }

  Widget _buildScopeChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isWorking ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.accent : context.adaptiveTextSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.accent : context.adaptiveTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context, {
    required String? imagePath,
    required String? audioSourcePath,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 112,
              height: 112,
              child: CachedImageWidget(
                imagePath: imagePath,
                audioSourcePath: audioSourcePath,
                fit: BoxFit.cover,
                placeholder: const ColoredBox(
                  color: AppColors.surface,
                  child: Icon(
                    LucideIcons.image,
                    color: AppColors.textTertiary,
                    size: 30,
                  ),
                ),
                errorWidget: const ColoredBox(
                  color: AppColors.surface,
                  child: Icon(
                    LucideIcons.imageOff,
                    color: AppColors.textTertiary,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontSize: 13,
                    color: context.adaptiveTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _scope == AlbumArtScope.wholeAlbum
                      ? l10n.importedArtIsSavedInsideThe
                      : l10n.importedArtIsSavedInsideThe2,
                  style: TextStyle(
                    fontFamily: 'GoogleSansFlex',
                    fontSize: 12,
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.glassBorderStrong,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
      ),
    );
  }

}

class _AlbumArtSheetResult {
  const _AlbumArtSheetResult({required this.message});

  final String message;
}
