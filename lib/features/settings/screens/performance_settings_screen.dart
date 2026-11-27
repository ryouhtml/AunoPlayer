import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:auno_player/core/constants/app_constants.dart';
import 'package:auno_player/core/theme/adaptive_color_provider.dart';
import 'package:auno_player/features/settings/widgets/settings_widgets.dart';
import 'package:auno_player/providers/performance_provider.dart';
import 'package:auno_player/services/performance_tier_service.dart';

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
      title: 'Performance',
      initialSection: initialSection,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader('Graphics mode', sectionId: 'graphicsMode'),
          SettingsCard(
            children: [
              SelectionSetting(
                icon: Icons.auto_awesome,
                title: 'Auto',
                subtitle:
                    'Detect the device class from memory, cores and refresh '
                    'rate.',
                selected: mode == GraphicsPerformanceMode.auto,
                onTap: () => modeNotifier.setMode(
                  GraphicsPerformanceMode.auto,
                ),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.bolt,
                title: 'Lite',
                subtitle:
                    'For entry-level hardware: no blur layers, smaller '
                    'thumbnail caches.',
                selected: mode == GraphicsPerformanceMode.lite,
                onTap: () => modeNotifier.setMode(
                  GraphicsPerformanceMode.lite,
                ),
              ),
              const SettingsDivider(),
              SelectionSetting(
                icon: Icons.speed,
                title: 'High-End',
                subtitle:
                    'Unlocks depth-of-field blur and the richest ambient '
                    'layers.',
                selected: mode == GraphicsPerformanceMode.highEnd,
                onTap: () => modeNotifier.setMode(
                  GraphicsPerformanceMode.highEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader('Effects', sectionId: 'effects'),
          SettingsCard(
            children: [
              ToggleSetting(
                icon: LucideIcons.sparkles,
                title: 'Lyrics & glass blur',
                subtitle:
                    'Depth-of-field blur on inactive lyric lines and frosted '
                    'glass panels. Off by default on entry-level devices.',
                value: blurEnabled,
                onChanged: (value) => blurNotifier.setOverride(value),
              ),
              if (override != null) ...[
                const SettingsDivider(),
                ActionButton(
                  icon: LucideIcons.rotateCcw,
                  title: 'Follow device automatically',
                  subtitle:
                      'Clear the manual override and use the ${_tierLabel(profile.tier)} default.',
                  onTap: () => blurNotifier.setOverride(null),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SettingsSectionHeader('Detected device', sectionId: 'device'),
          SettingsCard(
            children: [
              InfoSetting(
                icon: Icons.category,
                title: 'Class',
                subtitle: profileAsync.isLoading
                    ? 'Detecting…'
                    : _tierLabel(profile.tier),
              ),
              const SettingsDivider(),
              InfoSetting(
                icon: Icons.memory,
                title: 'Memory',
                subtitle: profile.totalRamMb > 0
                    ? '${(profile.totalRamMb / 1024).toStringAsFixed(1)} GB'
                    : 'Unknown',
              ),
              const SettingsDivider(),
              InfoSetting(
                icon: Icons.developer_board,
                title: 'CPU cores',
                subtitle: '${profile.processorCount}',
              ),
              const SettingsDivider(),
              InfoSetting(
                icon: Icons.monitor,
                title: 'Display',
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
              'Auto picks Lite at 4 GB of RAM or less and High-End from 7 GB '
              'with eight cores. The override is stored per device and never '
              'touches playback quality.',
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
      DevicePerformanceTier.lite => 'Entry level',
      DevicePerformanceTier.standard => 'Standard',
      DevicePerformanceTier.highEnd => 'High-end',
    };
  }
}
