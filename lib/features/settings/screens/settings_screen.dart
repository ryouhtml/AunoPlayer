import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:auno_player/core/theme/adaptive_color_provider.dart';
import 'package:auno_player/core/constants/app_constants.dart';
import 'package:auno_player/features/settings/screens/app_info_settings_screen.dart';
import 'package:auno_player/features/settings/screens/audio_settings_screen.dart';
import 'package:auno_player/features/settings/screens/bluetooth_settings_screen.dart';
import 'package:auno_player/features/settings/screens/interface_settings_screen.dart';
import 'package:auno_player/features/settings/screens/library_settings_screen.dart';
import 'package:auno_player/features/settings/screens/playback_display_settings_screen.dart';
import 'package:auno_player/features/settings/screens/queue_settings_screen.dart';
import 'package:auno_player/features/settings/screens/ui_customization_settings_screen.dart';
import 'package:auno_player/features/settings/screens/lyrics_settings_screen.dart';
import 'package:auno_player/features/settings/screens/player_layout_settings_screen.dart';
import 'package:auno_player/features/settings/screens/widget_settings_screen.dart';
import 'package:auno_player/core/utils/navigation_helper.dart';
import 'package:auno_player/features/settings/widgets/settings_widgets.dart';
import 'package:auno_player/features/milestone/screens/milestones_screen.dart';
import 'package:auno_player/features/manual/screens/manual_screen.dart';
import 'package:auno_player/services/milestone_service.dart';
import 'package:auno_player/l10n/settings_l10n.dart';
import 'package:auno_player/widgets/common/baybayin_text.dart';
import 'package:auno_player/widgets/common/glass_search_bar.dart';
import '../data/settings_search.dart';
import '../data/settings_search_catalog.dart';
import '../widgets/settings_search_results.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _milestonesUnlocked = 0;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refreshMilestoneCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshMilestoneCount();
  }

  Future<void> _refreshMilestoneCount() async {
    final shown = await MilestoneService().getShownMilestones();
    if (!mounted) return;
    if (shown.length != _milestonesUnlocked) {
      setState(() => _milestonesUnlocked = shown.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Background is handled by _PersistentBackground in MaterialApp.builder.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
              ),
              child: GlassSearchBar(
                controller: _searchController,
                hintText: l10n.searchSettings,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            if (_query.isNotEmpty)
              Expanded(
                child: SettingsSearchResults(
                  query: _query,
                  results: searchSettings(_query, buildSettingsSearchCatalog()),
                  onOpen: (page, sectionId) {
                    FocusScope.of(context).unfocus();
                    _navigate(context, page.buildPage(sectionId));
                  },
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  key: const PageStorageKey('settingsCategories'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        l10n.englishForFilipino.media,
                      ),
                      SettingsCard(
                        children: [
                          _CategoryTile(
                            icon: LucideIcons.library,
                            iconBg: const Color(0xFF2D4A6F),
                            iconFg: const Color(0xFF8BB8FF),
                            title: l10n.englishForFilipino.libraryLabel,
                            subtitle: l10n.foldersScanningAndDuplicates,
                            onTap: () => _navigate(
                              context,
                              const LibrarySettingsScreen(),
                            ),
                          ),
                          const SettingsDivider(),
                          _CategoryTile(
                            icon: LucideIcons.play,
                            iconBg: const Color(0xFF4A2D6F),
                            iconFg: const Color(0xFFD19FFF),
                            title: l10n.englishForFilipino.playbackDisplay,
                            subtitle: l10n.gaplessViewModeAndAppearance,
                            onTap: () => _navigate(
                              context,
                              const PlaybackDisplaySettingsScreen(),
                            ),
                          ),
                          const SettingsDivider(),
                          _CategoryTile(
                            icon: LucideIcons.listOrdered,
                            iconBg: const Color(0xFF2D6F4A),
                            iconFg: const Color(0xFF8BFFC4),
                            title: l10n.englishForFilipino.queue,
                            subtitle: l10n.wrapAroundAndQueueBehavior,
                            onTap: () =>
                                _navigate(context, const QueueSettingsScreen()),
                          ),
                          const SettingsDivider(),
                          _CategoryTile(
                            icon: LucideIcons.layoutPanelTop,
                            iconBg: const Color(0xFF4A2D6F),
                            iconFg: const Color(0xFFC4A3FF),
                            title: l10n.englishForFilipino.playerLayout,
                            subtitle: l10n.layoutModeSizingAndQuickActions,
                            onTap: () => _navigate(
                              context,
                              const PlayerLayoutSettingsScreen(),
                            ),
                          ),
                          const SettingsDivider(),
                          _CategoryTile(
                            icon: LucideIcons.headphones,
                            iconBg: const Color(0xFF6F4A2D),
                            iconFg: const Color(0xFFFFC48B),
                            title: l10n.englishForFilipino.audio,
                            subtitle: l10n.uac2AndEqualizer,
                            onTap: () =>
                                _navigate(context, const AudioSettingsScreen()),
                          ),
                          const SettingsDivider(),
                          _CategoryTile(
                            icon: LucideIcons.bluetooth,
                            iconBg: const Color(0xFF2D4A6F),
                            iconFg: const Color(0xFF8BB8FF),
                            title: l10n.englishForFilipino.bluetooth,
                            subtitle: l10n.disconnectBehaviorAndCodecInfo,
                            onTap: () => _navigate(
                              context,
                              const BluetoothSettingsScreen(),
                            ),
                          ),
                          const SettingsDivider(),
                          _CategoryTile(
                            icon: LucideIcons.fileText,
                            iconBg: const Color(0xFF4A6F2D),
                            iconFg: const Color(0xFFC4FF8B),
                            title: l10n.englishForFilipino.lyrics,
                            subtitle: l10n.lyricsSavingBehavior,
                            onTap: () => _navigate(
                              context,
                              const LyricsSettingsScreen(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingLg),
                      _buildSectionHeader(
                        context,
                        l10n.englishForFilipino.system,
                      ),
                      SettingsCard(
                        children: [
                          _CategoryTile(
                            icon: LucideIcons.layoutDashboard,
                            iconBg: const Color(0xFF2D6F4A),
                            iconFg: const Color(0xFF8BFFC4),
                            title: l10n.englishForFilipino.interfaceLabel,
                            subtitle: l10n.animationsAndHapticFeedback,
                            onTap: () => _navigate(
                              context,
                              const InterfaceSettingsScreen(),
                            ),
                          ),
                          const SettingsDivider(),
                          _CategoryTile(
                            icon: LucideIcons.palette,
                            iconBg: const Color(0xFF2D4A6F),
                            iconFg: const Color(0xFF8BB8FF),
                            title: l10n.englishForFilipino.uiCustomization,
                            subtitle: l10n.showOrHideHomeScreenSections,
                            onTap: () => _navigate(
                              context,
                              const UiCustomizationSettingsScreen(),
                            ),
                          ),
                          const SettingsDivider(),
                          _CategoryTile(
                            icon: LucideIcons.layoutGrid,
                            iconBg: const Color(0xFF2D4A6F),
                            iconFg: const Color(0xFF8BB8FF),
                            title: l10n.englishForFilipino.widgets,
                            subtitle: l10n.customizeHomeScreenWidgets,
                            onTap: () => _navigate(
                              context,
                              const WidgetSettingsScreen(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingLg),
                      _buildSectionHeader(
                        context,
                        l10n.englishForFilipino.help,
                      ),
                      SettingsCard(
                        children: [
                          _CategoryTile(
                            icon: LucideIcons.bookOpen,
                            iconBg: const Color(0xFF2D4A6F),
                            iconFg: const Color(0xFF8BB8FF),
                            title: l10n.englishForFilipino.helpManual,
                            subtitle: l10n.browseTheFullControlsGuide,
                            onTap: () =>
                                _navigate(context, const ManualScreen()),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingLg),
                      _buildSectionHeader(
                        context,
                        l10n.englishForFilipino.about,
                      ),
                      SettingsCard(
                        children: [
                          _CategoryTile(
                            icon: LucideIcons.trophy,
                            iconBg: const Color(0xFF3A3320),
                            iconFg: const Color(0xFFD4B265),
                            title: l10n.englishForFilipino.milestones,
                            subtitle: _milestonesUnlocked == 0
                                ? l10n.noAchievementsYetKeepListening
                                : l10n.unlocked3(
                                    _milestonesUnlocked,
                                    MilestoneType.values.length,
                                  ),
                            onTap: () async {
                              _navigate(context, const MilestonesScreen());
                              await _refreshMilestoneCount();
                            },
                          ),
                          const SettingsDivider(),
                          _CategoryTile(
                            icon: LucideIcons.info,
                            iconBg: const Color(0xFF3A3A3A),
                            iconFg: const Color(0xFFB0B0B0),
                            title: l10n.englishForFilipino.appInfo,
                            subtitle: l10n.updatesAboutAndSupport,
                            onTap: () => _navigate(
                              context,
                              const AppInfoSettingsScreen(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingLg),
                      SizedBox(
                        height:
                            AppConstants.navBarHeight +
                            MediaQuery.of(context).padding.bottom +
                            AppConstants.spacingLg * 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaybayinText(
                  label: BaybayinLabel.settings,
                  fallback: l10n.settings,
                  header: true,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.configureYourMusicExperience,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppConstants.spacingXs,
        bottom: AppConstants.spacingSm,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.adaptiveTextTertiary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    NavigationHelper.pushOnRoot(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

/// A single category row in the main settings menu with a colored icon.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              ColoredSettingsIcon(
                icon: icon,
                backgroundColor: iconBg,
                iconColor: iconFg,
                size: 36,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.adaptiveTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.adaptiveTextTertiary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: context.adaptiveTextTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
