import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:auno_player/core/constants/app_constants.dart';
import 'package:auno_player/core/theme/adaptive_color_provider.dart';
import 'package:auno_player/core/theme/app_colors.dart';
import 'package:auno_player/features/settings/widgets/settings_widgets.dart';
import 'package:auno_player/providers/lyrics_engine_provider.dart';
import 'package:auno_player/services/lyrics_providers.dart';
import 'package:auno_player/l10n/settings_l10n.dart';

/// Multi-provider lyric engine configuration.
///
/// Copy stays English here, matching every other Settings screen.
/// The list order is the fallback order: the first enabled provider that
/// returns synced lyrics wins.
class LyricsSourcesScreen extends ConsumerWidget {
  const LyricsSourcesScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(lyricsEngineSettingsProvider);
    final notifier = ref.read(lyricsEngineSettingsProvider.notifier);

    final providers = <LyricsProvider>[];
    for (final id in settings.providerOrder) {
      final provider = lyricsProviderById(id);
      if (provider != null) providers.add(provider);
    }

    return SettingsScaffold(
      title: l10n.lyricsSources,
      initialSection: initialSection,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.lookupOrder, sectionId: 'lookupOrder'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.fileText,
                title: l10n.embeddedLyricsFirst,
                subtitle: l10n.embeddedLyricsFirstDescription,
                value: settings.embeddedFirst,
                onChanged: notifier.setEmbeddedFirst,
              ),
              const SettingsDivider(),
              ToggleSetting(
                icon: LucideIcons.globe,
                title: l10n.onlineProviders,
                subtitle: l10n.onlineProvidersDescription,
                value: settings.onlineEnabled,
                onChanged: notifier.setOnlineEnabled,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(
            l10n.providerPriority,
            sectionId: 'providerPriority',
          ),
          SettingsCard(
            children: [
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                padding: EdgeInsets.zero,
                itemCount: providers.length,
                onReorder: (oldIndex, newIndex) {
                  notifier.moveProvider(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final provider = providers[index];
                  return _ProviderRow(
                    key: ValueKey(provider.id),
                    provider: provider,
                    index: index,
                    enabled: settings.enabledProviderIds.contains(
                      provider.id,
                    ),
                    onToggle: (value) {
                      notifier.setProviderEnabled(provider.id, value);
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingXs,
            ),
            child: Text(
              l10n.providerReorderHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextTertiary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsCard(
            children: [
              ActionButton(
                icon: LucideIcons.rotateCcw,
                title: l10n.resetSources,
                subtitle: l10n.resetSourcesDescription,
                onTap: notifier.resetToDefaults,
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

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    super.key,
    required this.provider,
    required this.index,
    required this.enabled,
    required this.onToggle,
  });

  final LyricsProvider provider;
  final int index;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final configured = provider.isConfigured;
    final accent = enabled ? AppColors.accentLight : context.adaptiveTextTertiary;

    final status = !configured
        ? l10n.needsBuildTimeEndpoint
        : enabled
        ? l10n.ready
        : l10n.disabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onToggle(!enabled),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.glassBorder, width: 1),
            ),
          ),
          padding: const EdgeInsets.only(
            left: AppConstants.spacingLg,
            right: AppConstants.spacingSm,
            top: 10,
            bottom: 10,
          ),
          child: Row(
            children: [
              Icon(
                configured ? LucideIcons.globe : LucideIcons.globeLock,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: enabled
                            ? context.adaptiveTextPrimary
                            : context.adaptiveTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.adaptiveTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              CustomSwitch(value: enabled, onChanged: onToggle),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingSm,
                    vertical: 8,
                  ),
                  child: Icon(
                    LucideIcons.gripVertical,
                    size: 18,
                    color: context.adaptiveTextTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
