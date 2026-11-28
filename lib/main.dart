import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auno_player/src/rust/frb_generated.dart';
import 'package:auno_player/app/app.dart';
import 'package:auno_player/data/database.dart';
import 'package:auno_player/services/app_preferences_service.dart';
import 'package:auno_player/services/display_mode_service.dart';
import 'package:auno_player/services/external_playback_service.dart';
import 'package:auno_player/services/permission_service.dart';
import 'package:auno_player/services/player_service.dart';
import 'package:auno_player/services/playback_clock.dart';
import 'package:auno_player/services/playback_cache_maintenance.dart';
import 'package:auno_player/services/process_exit_diagnostics_service.dart';
import 'package:auno_player/services/uac2_preferences_service.dart';
import 'package:auno_player/services/uac2_service.dart';
import 'package:auno_player/core/utils/app_log.dart';
import 'package:auno_player/core/utils/dev_log.dart';
import 'package:auno_player/l10n/l10n.dart';
import 'package:auno_player/core/utils/frame_timings_monitor.dart';
import 'package:auno_player/src/rust/api/logging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge now playing: artwork reaches y = 0 behind a transparent
  // status bar, and the navigation bar blends into the ambient gradient.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // 2–4 GB devices cannot afford Flutter's default 100 MB / 1000-entry image
  // cache. Album art is downsampled at every call site; this is the hard
  // ceiling that keeps a large library scroll from thrashing the heap.
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 80;
  imageCache.maximumSizeBytes = 35 << 20;

  // Snapshot install freshness before anything can write to the preference
  // store: new installations start on the adaptive refresh-rate default.
  await AppPreferencesService.captureInstallFreshness();

  await AppLog.instance.initializePersistence();
  await Uac2PreferencesService().initializeDeveloperModeCache();
  // Follows developer mode and installs the frame-timing callback only while
  // it is enabled, so normal use pays no per-frame collection cost.
  FrameTimingsMonitor.instance.start();

  // Resolve the UI language before anything can produce a user-visible string.
  // The global `l10n` accessor is a plain global (see lib/l10n/l10n.dart), so
  // service-layer strings need it pointed at the right locale from the start.
  await LocaleController.instance.load();
  LocaleController.instance.bindLocale(LocaleController.instance.effectiveLocale);

  FlutterError.onError = (details) {
    AppLog.instance.add(
      '${details.exception}\n${details.stack}',
      source: LogSource.crash,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.instance.add('$error\n$stack', source: LogSource.platform);
    return true;
  };

  await RustLib.init();
  _subscribeRustLogs();
  unawaited(ProcessExitDiagnosticsService().reportPreviousExits());

  await Database.init();

  // Frame-driven position derived from the engine's 50 ms anchor ticks.
  PlaybackClock.instance.attach(PlayerService());

  final externalPlaybackHandled = await ExternalPlaybackService().initialize();
  if (!externalPlaybackHandled) {
    await _restoreLastPlayedSong();
  }

  runZonedGuarded(() {
    runApp(const ProviderScope(child: FlickPlayerApp()));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapAppAfterFirstFrame());
    });
  }, (error, stack) {
    AppLog.instance.add('$error\n$stack', source: LogSource.zone);
  });
}

void _subscribeRustLogs() {
  registerLogSink().listen(
    (msg) => AppLog.instance.add(msg, source: LogSource.rust),
    onError: (Object e) =>
        AppLog.instance.add('rust log stream error: $e', source: LogSource.rust),
  );
}

Future<void> _bootstrapAppAfterFirstFrame() async {
  unawaited(DisplayModeService().initialize());
  unawaited(
    _requestNotificationPermission().catchError(
      (Object e) => devLog('Notification permission request failed: $e'),
    ),
  );
  unawaited(
    Uac2Service.instance
        .initializeAndroidRouteMonitoring()
        .catchError((Object e) => devLog('USB route probe failed: $e')),
  );
  unawaited(
    PlayerService().prepareForAppLaunch().catchError(
      (Object e) => devLog('Audio prewarm failed: $e'),
    ),
  );
  unawaited(
    runPlaybackCacheMaintenance().catchError(
      (Object e) => devLog('Playback cache maintenance failed: $e'),
    ),
  );
}

Future<void> _requestNotificationPermission() async {
  final permissionService = PermissionService();
  final hasPermission = await permissionService.hasNotificationPermission();
  if (!hasPermission) {
    await permissionService.requestNotificationPermission();
  }
}

Future<void> _restoreLastPlayedSong() async {
  try {
    final playerService = PlayerService();
    await playerService.restorePlaybackModes();
    await playerService.restoreLastPlayed();
  } catch (e) {
    devLog('Failed to restore last played song: $e');
  }
}
