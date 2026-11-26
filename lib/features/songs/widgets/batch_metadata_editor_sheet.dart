import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auno_player/core/constants/app_constants.dart';
import 'package:auno_player/core/theme/adaptive_color_provider.dart';
import 'package:auno_player/core/theme/app_colors.dart';
import 'package:auno_player/core/utils/dev_log.dart';
import 'package:auno_player/l10n/l10n.dart';
import 'package:auno_player/models/song.dart';
import 'package:auno_player/providers/providers.dart';
import 'package:auno_player/services/metadata_editor_service.dart';
import 'package:auno_player/services/player_service.dart';
import 'package:auno_player/src/rust/api/metadata_editor.dart' as rust_metadata;
import 'package:auno_player/widgets/common/glass_bottom_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Outcome of one batch metadata pass, reported back to the caller so it can
/// summarise what happened without reading provider state.
class BatchMetadataEditResult {
  const BatchMetadataEditResult({
    required this.updated,
    required this.failed,
    required this.skipped,
  });

  final int updated;
  final int failed;
  final int skipped;
}

/// Edits the tags shared by many songs at once.
///
/// Blank fields are left untouched per song, so a batch edit can change only
/// the album (or only the genre) without overwriting titles, track numbers, or
/// anything else the user did not ask to change.
class BatchMetadataEditorSheet extends ConsumerStatefulWidget {
  const BatchMetadataEditorSheet({
    super.key,
    required this.songs,
    this.service,
    this.onSongSynced,
  });

  final List<Song> songs;

  /// Test seam; production resolves [MetadataEditorService.instance].
  final MetadataEditorService? service;

  /// Called after each successful tag write so the player mirror can refresh.
  /// Defaults to [PlayerService.syncSongMetadata].
  final void Function(Song song, rust_metadata.TagEditFields fields)?
      onSongSynced;

  static Future<BatchMetadataEditResult?> show(
    BuildContext context,
    List<Song> songs,
  ) {
    return showModalBottomSheet<BatchMetadataEditResult>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: AppBottomSheetSurface(
          maxHeightRatio: 0.9,
          child: BatchMetadataEditorSheet(songs: songs),
        ),
      ),
    );
  }

  @override
  ConsumerState<BatchMetadataEditorSheet> createState() =>
      _BatchMetadataEditorSheetState();
}

class _BatchMetadataEditorSheetState
    extends ConsumerState<BatchMetadataEditorSheet> {
  late final TextEditingController _albumController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumArtistController;
  late final TextEditingController _genreController;
  late final TextEditingController _yearController;
  late final FocusNode _albumFocus;
  late final List<Song> _editableSongs;

  bool _isSaving = false;
  int _done = 0;
  int _total = 0;

  int get _skipped => widget.songs.length - _editableSongs.length;
  MetadataEditorService get _service =>
      widget.service ?? MetadataEditorService.instance;

  @override
  void initState() {
    super.initState();
    _editableSongs = widget.songs.where(_canEdit).toList(growable: false);
    _albumController = TextEditingController();
    _artistController = TextEditingController();
    _albumArtistController = TextEditingController();
    _genreController = TextEditingController();
    _yearController = TextEditingController();
    _albumFocus = FocusNode();
    for (final controller in [
      _albumController,
      _artistController,
      _albumArtistController,
      _genreController,
      _yearController,
    ]) {
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _albumController.dispose();
    _artistController.dispose();
    _albumArtistController.dispose();
    _genreController.dispose();
    _yearController.dispose();
    _albumFocus.dispose();
    super.dispose();
  }

  /// Mirrors [MetadataEditorService.writeTags] preconditions: plain file
  /// paths only, no cue-sheet offsets, no external (network) sources.
  bool _canEdit(Song song) =>
      song.filePath != null &&
      song.filePath!.isNotEmpty &&
      song.startOffsetMs == null &&
      !song.isExternal;

  bool get _hasInput =>
      _albumController.text.trim().isNotEmpty ||
      _artistController.text.trim().isNotEmpty ||
      _albumArtistController.text.trim().isNotEmpty ||
      _genreController.text.trim().isNotEmpty ||
      _yearController.text.trim().isNotEmpty;

  String? get _yearError {
    final text = _yearController.text.trim();
    if (text.isEmpty) return null;
    final year = int.tryParse(text);
    if (year == null || year < 1 || year > 9999) {
      return context.l10n.enterAYear19999;
    }
    return null;
  }

  bool get _hasInvalidFields => _yearError != null;

  rust_metadata.TagEditFields _fields() {
    String? text(TextEditingController controller) {
      final trimmed = controller.text.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return rust_metadata.TagEditFields(
      album: text(_albumController),
      artist: text(_artistController),
      albumArtist: text(_albumArtistController),
      genre: text(_genreController),
      year: int.tryParse(_yearController.text.trim()),
    );
  }

  Future<void> _save() async {
    if (_isSaving || !_hasInput || _hasInvalidFields) return;
    if (_editableSongs.isEmpty) return;

    final fields = _fields();
    setState(() {
      _isSaving = true;
      _done = 0;
      _total = _editableSongs.length;
    });

    var updated = 0;
    var failed = 0;
    for (final song in _editableSongs) {
      try {
        final result = await _service.writeTags(song, fields);
        if (!mounted) return;
        if (result.saved) {
          updated++;
          final synced = widget.onSongSynced;
          if (synced != null) {
            synced(song, fields);
          } else {
            PlayerService().syncSongMetadata(
              filePath: song.filePath!,
              album: fields.album,
              artist: fields.artist,
              albumArtist: fields.albumArtist,
              genre: fields.genre,
              year: fields.year,
            );
          }
        } else {
          failed++;
        }
      } catch (e) {
        devLog('Batch metadata write failed for ${song.id}: $e');
        failed++;
      }
      if (!mounted) return;
      setState(() => _done++);
    }

    ref.invalidate(songsProvider);
    if (!mounted) return;
    Navigator.of(context).pop(
      BatchMetadataEditResult(
        updated: updated,
        failed: failed,
        skipped: _skipped,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = context.adaptiveTextPrimary;
    final canSave = _editableSongs.isNotEmpty &&
        _hasInput &&
        !_isSaving &&
        !_hasInvalidFields;

    return PopScope(
      canPop: !_isSaving,
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
                      l10n.editMetadata,
                      style: TextStyle(
                        fontFamily: 'GoogleSansFlex',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.selected(widget.songs.length),
                      style: TextStyle(
                        fontFamily: 'GoogleSansFlex',
                        fontSize: 12,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _isSaving ? null : () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.spacingXs),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Icon(
                    LucideIcons.x,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoBanner(
                    context,
                    icon: LucideIcons.info,
                    text: l10n.batchEditKeepExisting,
                  ),
                  if (_skipped > 0) ...[
                    const SizedBox(height: AppConstants.spacingSm),
                    _buildInfoBanner(
                      context,
                      icon: LucideIcons.triangleAlert,
                      text: l10n.batchEditSomeSkipped(_skipped),
                      warning: true,
                    ),
                  ],
                  const SizedBox(height: AppConstants.spacingMd),
                  _buildField(
                    context,
                    l10n.album,
                    _albumController,
                    fieldKey: const ValueKey('batchField_album'),
                    focusNode: _albumFocus,
                    textInputAction: TextInputAction.next,
                  ),
                  _buildField(
                    context,
                    l10n.artist,
                    _artistController,
                    fieldKey: const ValueKey('batchField_artist'),
                  ),
                  _buildField(
                    context,
                    l10n.albumArtist,
                    _albumArtistController,
                    fieldKey: const ValueKey('batchField_albumArtist'),
                  ),
                  _buildField(
                    context,
                    l10n.genre,
                    _genreController,
                    fieldKey: const ValueKey('batchField_genre'),
                  ),
                  _buildField(
                    context,
                    l10n.year,
                    _yearController,
                    fieldKey: const ValueKey('batchField_year'),
                    keyboardType: TextInputType.number,
                    errorText: _yearError,
                  ),
                  if (_isSaving) ...[
                    const SizedBox(height: AppConstants.spacingSm),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusRound),
                      child: LinearProgressIndicator(
                        value: _total == 0 ? null : _done / _total,
                        minHeight: 4,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                          AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXs),
                    Text(
                      '$_done / $_total',
                      style: TextStyle(
                        fontFamily: 'GoogleSansFlex',
                        fontSize: 12,
                        color: context.adaptiveTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_editableSongs.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingMd),
            _buildSaveButton(canSave),
            const SizedBox(height: AppConstants.spacingSm),
          ],
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

  Widget _buildInfoBanner(
    BuildContext context, {
    required IconData icon,
    required String text,
    bool warning = false,
  }) {
    final color = warning ? Colors.orangeAccent : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: warning
            ? Colors.orangeAccent.withValues(alpha: 0.1)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 13,
                height: 1.35,
                color: warning ? Colors.orangeAccent : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    Key? fieldKey,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    String? errorText,
  }) {
    final enabled = !_isSaving;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.adaptiveTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 15,
              color: context.adaptiveTextPrimary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm + 2,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              errorText: errorText,
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              errorStyle: const TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 11,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool canSave) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: canSave ? _save : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor:
              AppColors.surfaceLight.withValues(alpha: 0.6),
          foregroundColor: AppColors.background,
          disabledForegroundColor: AppColors.textTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          padding: EdgeInsets.zero,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.background),
                ),
              )
            : Text(
                context.l10n.saveChanges,
                style: const TextStyle(
                  fontFamily: 'GoogleSansFlex',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
