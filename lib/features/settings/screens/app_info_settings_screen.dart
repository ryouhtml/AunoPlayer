import 'package:auno_player/widgets/common/flick_snackbar.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:auno_player/core/theme/adaptive_color_provider.dart';
import 'package:auno_player/core/theme/app_colors.dart';
import 'package:auno_player/core/constants/app_constants.dart';
import 'package:auno_player/core/utils/responsive.dart';
import 'package:auno_player/features/onboarding/screens/onboarding_screen.dart';
import 'package:auno_player/features/settings/screens/privacy_policy_screen.dart';
import 'package:auno_player/features/settings/widgets/settings_widgets.dart';
import 'package:auno_player/providers/providers.dart';
import 'package:auno_player/services/build_info_service.dart';
import 'package:auno_player/widgets/common/glass_bottom_sheet.dart';
import 'package:auno_player/l10n/settings_l10n.dart';

class AppInfoSettingsScreen extends ConsumerStatefulWidget {
  const AppInfoSettingsScreen({super.key, this.initialSection});

  final String? initialSection;

  @override
  ConsumerState<AppInfoSettingsScreen> createState() =>
      _AppInfoSettingsScreenState();
}

class _AppInfoSettingsScreenState extends ConsumerState<AppInfoSettingsScreen> {
  String? _buildFlavor;

  @override
  void initState() {
    super.initState();
    _loadBuildFlavor();
  }

  void _showToast(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showFlickSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadBuildFlavor() async {
    final flavor = await BuildInfoService().getBuildFlavor();
    if (!mounted || flavor == null) return;
    setState(() => _buildFlavor = flavor);
  }

  String _buildFlavorSubtitle(String flavor) => switch (flavor) {
        'full' => l10n.buildFlavorFull,
        'play' => l10n.buildFlavorPlay,
        _ => flavor,
      };

  void _showAboutBottomSheet() {
    GlassBottomSheet.show(
      context: context,
      title: l10n.englishForFilipino.aboutFlickPlayer,
      maxHeightRatio: 0.5,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppConstants.spacingMd),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.glassBackgroundStrong,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Center(
              child: Image.asset(
                'assets/icons/auno_logo_square.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            l10n.flickPlayer,
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.version(kAppVersion),
            style: TextStyle(
              fontFamily: 'GoogleSansFlex',
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              l10n.aPremiumMusicPlayerWithCustom,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'GoogleSansFlex',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () =>
                    _launchUrl('https://github.com/ryouhtml/AunoPlayer'),
                icon: const Icon(LucideIcons.squareCode, size: 18),
                label: Text(
                  l10n.github,
                  style: TextStyle(fontFamily: 'GoogleSansFlex'),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              TextButton.icon(
                onPressed: () => _launchUrl('https://discord.gg/5hgcrdnKY6'),
                icon: const Icon(LucideIcons.messageCircle, size: 18),
                label: Text(
                  l10n.discord,
                  style: TextStyle(fontFamily: 'GoogleSansFlex'),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
        ],
      ),
    );
  }

  static String get _flickLicenseText => l10n.mitLicenseCopyrightC2026Flick;

  static bool _flickLicenseRegistered = false;

  // ponytail: LicensePage covers the list + detail UI; only Auno Player's own entry is added manually
  void _openLicensesScreen() {
    if (!_flickLicenseRegistered) {
      _flickLicenseRegistered = true;
      LicenseRegistry.addLicense(() async* {
        yield LicenseEntryWithLineBreaks(['Auno Player'], _flickLicenseText);
        // The Simplified Chinese fallback font ships with the app, so its
        // license has to be surfaced here as well.
        yield LicenseEntryWithLineBreaks(
          ['Noto Sans SC'],
          await rootBundle.loadString('assets/fonts/NotoSansSC-OFL.txt'),
        );
        yield LicenseEntryWithLineBreaks(
          ['Noto Sans Tagalog'],
          await rootBundle.loadString('assets/fonts/NotoSansTagalog-OFL.txt'),
        );
      });
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // ponytail: iOS platform override swaps the app bar back arrow for a chevron-left
        builder: (context) {
          final page = Theme(
            data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
            child: LicensePage(
              applicationName: l10n.flick,
              applicationVersion: kAppVersion,
              applicationIcon: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingSm),
                child: Image.asset(
                  'assets/icons/auno_logo_square.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
          // Flutter's LicensePage uses MaterialLocalizations, not our copy
          // getter. Keep its list/detail chrome English in Taglish too.
          return context.l10n.isFilipino
              ? Localizations.override(
                  context: context,
                  locale: kFallbackLocale,
                  child: page,
                )
              : page;
        },
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!launched && mounted) {
        _showToast(l10n.couldNotOpenTheLink);
      }
    } catch (e) {
      if (mounted) {
        _showToast(l10n.couldNotOpenTheLink2(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: l10n.englishForFilipino.appInfo,
      initialSection: widget.initialSection,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSectionHeader(l10n.englishForFilipino.about, sectionId: 'about'),
          SettingsCard(
            children: [
              NavigationSetting(
                icon: LucideIcons.info,
                title: l10n.englishForFilipino.aboutFlickPlayer,
                subtitle: l10n.version(kAppVersion),
                onTap: _showAboutBottomSheet,
              ),
              if (_buildFlavor != null) ...[
                const SettingsDivider(),
                InfoSetting(
                  icon: LucideIcons.package,
                  title: l10n.englishForFilipino.buildFlavor,
                  subtitle: _buildFlavorSubtitle(_buildFlavor!),
                ),
              ],
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.fileText,
                title: l10n.englishForFilipino.licenses,
                subtitle: l10n.openSourceLicenses,
                onTap: _openLicensesScreen,
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.shieldCheck,
                title: l10n.englishForFilipino.privacyPolicy,
                subtitle: l10n.howWeHandleYourData,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.sparkles,
                title: l10n.englishForFilipino.viewOnboarding,
                subtitle: l10n.replayTheTutorialAndFeatureGuide,
                onTap: () {
                  ref.read(onboardingCompletedProvider.notifier).reset();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OnboardingScreen(),
                    ),
                  );
                },
              ),
              const SettingsDivider(),
              NavigationSetting(
                icon: LucideIcons.graduationCap,
                title: l10n.englishForFilipino.interactiveTutorial,
                subtitle: l10n.stepByStepWalkthroughOfThe,
                onTap: () {
                  ref.read(tutorialProvider.notifier).showPicker();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.navBarHeight + 40),
        ],
      ),
    );
  }
}

