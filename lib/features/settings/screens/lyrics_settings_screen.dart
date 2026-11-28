import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:auno_player/core/constants/app_constants.dart';
import 'package:auno_player/core/utils/navigation_helper.dart';
import 'package:auno_player/features/settings/screens/lyrics_sources_screen.dart';
import 'package:auno_player/features/settings/widgets/settings_widgets.dart';
import 'package:auno_player/providers/app_preferences_provider.dart';
import 'package:auno_player/providers/lyrics_engine_provider.dart';
import 'package:auno_player/services/lyrics_translation_service.dart';
import 'package:auno_player/l10n/settings_l10n.dart';

class LyricsSettingsScreen extends ConsumerWidget {
  const LyricsSettingsScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appPrefs = ref.watch(appPreferencesProvider);
    final engine = ref.watch(lyricsEngineSettingsProvider);
    final enabledProviders = ref.watch(enabledLyricsProvidersProvider);
    final engineNotifier = ref.read(lyricsEngineSettingsProvider.notifier);

    final translationLanguages = <(String, String, String)>[
      ('off', l10n.off, l10n.translationLanguageOffDescription),
      ('id', l10n.indonesian, l10n.translationLanguageIdDescription),
      ('en', l10n.english, l10n.translationLanguageEnDescription),
      (
        'es',
        l10n.translationLanguageSpanish,
        l10n.translationLanguageEsDescription,
      ),
      (
        'tl',
        l10n.translationLanguageFilipino,
        l10n.translationLanguageTlDescription,
      ),
      (
        'zh',
        l10n.translationLanguageChinese,
        l10n.translationLanguageZhDescription,
      ),
    ];

    final providerSummary = enabledProviders.isEmpty
        ? l10n.lyricsSourcesSummaryNone
        : l10n.lyricsSourcesSummary(
            enabledProviders.length,
            enabledProviders.first.displayName,
          );

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
          SettingsSectionHeader(
            l10n.lyricsEngine,
            sectionId: 'lyricsEngine',
          ),
          SettingsCard(
            children: [
              NavigationSetting(
                icon: LucideIcons.globe,
                title: l10n.lyricsSources,
                subtitle: providerSummary,
                onTap: () => NavigationHelper.pushOnRoot(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const LyricsSourcesScreen(),
                  ),
                ),
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.fileText,
                title: l10n.embeddedLyricsFirst,
                subtitle: l10n.embeddedLyricsFirstDescription,
                value: engine.embeddedFirst,
                onChanged: engineNotifier.setEmbeddedFirst,
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.globe,
                title: l10n.onlineProviders,
                subtitle: l10n.onlineProvidersDescription,
                value: engine.onlineEnabled,
                onChanged: engineNotifier.setOnlineEnabled,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.translation, sectionId: 'translation'),
          SettingsCard(
            children: [
              for (var i = 0; i < translationLanguages.length; i++) ...[
                if (i > 0) const SettingsDivider(),
                SelectionSetting(
                  icon: i == 0 ? Icons.translate : Icons.translate_rounded,
                  title: translationLanguages[i].$2,
                  subtitle: translationLanguages[i].$3,
                  selected:
                      engine.translationLanguage == translationLanguages[i].$1,
                  onTap: () => engineNotifier.setTranslationLanguage(
                    translationLanguages[i].$1,
                  ),
                ),
              ],
            ],
          ),
          if (LyricsTranslationService.endpoint.trim().isEmpty) ...[
            const SizedBox(height: AppConstants.spacingSm),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingXs,
              ),
              child: Text(
                l10n.onlineTranslationEndpointNotice,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
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
