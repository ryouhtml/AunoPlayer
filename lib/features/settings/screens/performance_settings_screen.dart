import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:auno_player/core/constants/app_constants.dart';
import 'package:auno_player/core/theme/adaptive_color_provider.dart';
import 'package:auno_player/features/settings/widgets/settings_widgets.dart';
import 'package:auno_player/providers/performance_provider.dart';
import 'package:auno_player/services/performance_tier_service.dart';
import 'package:auno_player/l10n/settings_l10n.dart';

/// Rendering budget: Auto / Lite / High-End plus the blur master switch.
///
/// Copy stays English here, matching every other Settings screen.
class PerformanceSettingsScreen extends ConsumerWidget {
  const PerformanceSettingsScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(graphicsPerformanceModeProvider);
    final override = ref.watch(blurEffectsOverrideProvider);
    final blurEnabled = ref.watch(blurEffectsEnabledProvider);
    final profileAsync = ref.watch(performanceProfileProvider);
    final profile = profileAsync.value ?? DevicePerformanceProfile.fallback;
    final modeNotifier = ref.read(graphicsPerformanceModeProvider.notifier);
    final blurNotifier = ref.read(blurEffectsOverrideProvider.notifier);

    return SettingsScaffold(
      title: l10n.performance,
      initialSection: initialSection,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.graphicsMode, sectionId: 'graphicsMode'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: Icons.auto_awesome,
                title: l10n.auto,
                subtitle: l10n.graphicsModeAutoDescription,
                selected: mode == GraphicsPerformanceMode.auto,
                onTap: () => modeNotifier.setMode(
                  GraphicsPerformanceMode.auto,
                ),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.bolt,
                title: l10n.lite,
                subtitle: l10n.graphicsModeLiteDescription,
                selected: mode == GraphicsPerformanceMode.lite,
                onTap: () => modeNotifier.setMode(
                  GraphicsPerformanceMode.lite,
                ),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.speed,
                title: l10n.highEnd,
                subtitle: l10n.graphicsModeHighEndDescription,
                selected: mode == GraphicsPerformanceMode.highEnd,
                onTap: () => modeNotifier.setMode(
                  GraphicsPerformanceMode.highEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(l10n.effects, sectionId: 'effects'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.sparkles,
                title: l10n.lyricsGlassBlur,
                subtitle: l10n.lyricsGlassBlurDescription,
                value: blurEnabled,
                onChanged: (value) => blurNotifier.setOverride(value),
              ),
              if (override != null) ...[
                const SettingsDivider(),
                ActionButton(
                  icon: LucideIcons.rotateCcw,
                  title: l10n.followDeviceAutomatically,
                  subtitle: l10n.followDeviceAutomaticallyDescription(
                    _tierLabel(profile.tier),
                  ),
                  onTap: () => blurNotifier.setOverride(null),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader(
            l10n.detectedDevice,
            sectionId: 'detectedDevice',
          ),
          SettingsCard(
            children: [
              InfoSetting(
                icon: Icons.category,
                title: l10n.deviceClass,
                subtitle: profileAsync.isLoading
                    ? l10n.detecting
                    : _tierLabel(profile.tier),
              ),
              const SettingsDivider(),
              InfoSetting(
                icon: Icons.memory,
                title: l10n.memory,
                subtitle: profile.totalRamMb > 0
                    ? '${(profile.totalRamMb / 1024).toStringAsFixed(1)} GB'
                    : l10n.unknown,
              ),
              const SettingsDivider(),
              InfoSetting(
                icon: Icons.developer_board,
                title: l10n.cpuCores,
                subtitle: '${profile.processorCount}',
              ),
              const SettingsDivider(),
              InfoSetting(
                icon: Icons.monitor,
                title: l10n.display,
                subtitle: '${profile.refreshRateHz.toStringAsFixed(0)} Hz',
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingXs,
            ),
            child: Text(
              l10n.performanceAutoHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.adaptiveTextTertiary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }

  static String _tierLabel(DevicePerformanceTier tier) {
    return switch (tier) {
      DevicePerformanceTier.lite => l10n.entryLevel,
      DevicePerformanceTier.standard => l10n.standard,
      DevicePerformanceTier.highEnd => l10n.highEnd,
    };
  }
}
