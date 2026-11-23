import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:auno_player/core/constants/app_constants.dart';
import 'package:auno_player/features/settings/widgets/settings_widgets.dart';
import 'package:auno_player/providers/app_preferences_provider.dart';
import 'package:auno_player/l10n/settings_l10n.dart';

class LyricsSettingsScreen extends ConsumerWidget {
  const LyricsSettingsScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appPrefs = ref.watch(appPreferencesProvider);

    return SettingsScaffold(
      title: l10n.englishForFilipino.lyrics,
      initialSection: initialSection,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.englishForFilipino.saving2, sectionId: 'saving2'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.fileText,
                title: l10n.englishForFilipino.matchAudioFilename,
                subtitle:
                    l10n.useTheCurrentAudioFileS,
                value: appPrefs.lyricsMatchAudioFilename,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setLyricsMatchAudioFilename(value);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.englishForFilipino.display, sectionId: 'display'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.music,
                title: l10n.englishForFilipino.karaokeEffect,
                subtitle:
                    '${l10n.sweepAHighlightThroughWordsAs} · ${l10n.karaokeSweepStyle}',
                value: appPrefs.karaokeEnabled,
                onChanged: (value) {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setKaraokeEnabled(value);
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.auto_awesome,
                title: l10n.karaokeSweepStyleAuto,
                subtitle: l10n.karaokeSweepStyleAutoDescription,
                selected: appPrefs.karaokeSweepStyle == 'auto',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setKaraokeSweepStyle('auto');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.text_fields_rounded,
                title: l10n.karaokeSweepStyleWord,
                subtitle: l10n.karaokeSweepStyleWordDescription,
                selected: appPrefs.karaokeSweepStyle == 'word',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setKaraokeSweepStyle('word');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.segment_rounded,
                title: l10n.karaokeSweepStyleSyllable,
                subtitle: l10n.karaokeSweepStyleSyllableDescription,
                selected: appPrefs.karaokeSweepStyle == 'syllable',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setKaraokeSweepStyle('syllable');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.format_align_left_rounded,
                title: l10n.englishForFilipino.left,
                subtitle: l10n.alignLyricTextToTheLeft,
                selected: appPrefs.lyricsTextAlign == 'left',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setLyricsTextAlign('left');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.format_align_center_rounded,
                title: l10n.englishForFilipino.center,
                subtitle: l10n.alignLyricTextToTheCenter,
                selected: appPrefs.lyricsTextAlign == 'center',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setLyricsTextAlign('center');
                },
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.format_align_right_rounded,
                title: l10n.englishForFilipino.right,
                subtitle: l10n.alignLyricTextToTheRight,
                selected: appPrefs.lyricsTextAlign == 'right',
                onTap: () {
                  ref
                      .read(appPreferencesProvider.notifier)
                      .setLyricsTextAlign('right');
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}
