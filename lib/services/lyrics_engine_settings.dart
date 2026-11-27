import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auno_player/services/lyrics_providers.dart';

/// User configuration for the multi-provider lyric engine.
@immutable
class LyricsEngineSettings {
  const LyricsEngineSettings({
    required this.providerOrder,
    required this.enabledProviderIds,
    this.embeddedFirst = true,
    this.onlineEnabled = true,
    this.translationLanguage = 'off',
  });

  /// Provider ids in lookup priority order.
  final List<String> providerOrder;

  /// Providers allowed to run.
  final Set<String> enabledProviderIds;

  /// Embedded tag / sidecar lyrics win before any network request.
  final bool embeddedFirst;

  /// Master switch for remote providers.
  final bool onlineEnabled;

  /// `off`, `id`, `en`, `romaji`, …
  final String translationLanguage;

  static final LyricsEngineSettings defaults = LyricsEngineSettings(
    providerOrder: List.unmodifiable([
      for (final provider in allLyricsProviders) provider.id,
    ]),
    enabledProviderIds: Set.unmodifiable({
      for (final provider in allLyricsProviders) provider.id,
    }),
  );

  List<String> get enabledProvidersInOrder => [
    for (final id in providerOrder)
      if (enabledProviderIds.contains(id)) id,
  ];

  LyricsEngineSettings copyWith({
    List<String>? providerOrder,
    Set<String>? enabledProviderIds,
    bool? embeddedFirst,
    bool? onlineEnabled,
    String? translationLanguage,
  }) {
    return LyricsEngineSettings(
      providerOrder: providerOrder ?? this.providerOrder,
      enabledProviderIds: enabledProviderIds ?? this.enabledProviderIds,
      embeddedFirst: embeddedFirst ?? this.embeddedFirst,
      onlineEnabled: onlineEnabled ?? this.onlineEnabled,
      translationLanguage: translationLanguage ?? this.translationLanguage,
    );
  }
}

/// Persists the lyric engine configuration.
class LyricsEngineSettingsService {
  static const _orderKey = 'lyrics_provider_order_v1';
  static const _enabledKey = 'lyrics_provider_enabled_v1';
  static const _embeddedFirstKey = 'lyrics_embedded_first_v1';
  static const _onlineEnabledKey = 'lyrics_online_enabled_v1';
  static const _translationKey = 'lyrics_translation_language_v1';

  Future<LyricsEngineSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedOrder = prefs.getStringList(_orderKey);
    final storedEnabled = prefs.getStringList(_enabledKey);

    final known = <String>{
      for (final provider in allLyricsProviders) provider.id,
    };
    final order = <String>[];
    if (storedOrder != null) {
      for (final id in storedOrder) {
        if (known.contains(id) && !order.contains(id)) order.add(id);
      }
    }
    for (final provider in allLyricsProviders) {
      if (!order.contains(provider.id)) order.add(provider.id);
    }

    final enabled = storedEnabled == null
        ? {...LyricsEngineSettings.defaults.enabledProviderIds}
        : storedEnabled.where(known.contains).toSet();

    return LyricsEngineSettings(
      providerOrder: List.unmodifiable(order),
      enabledProviderIds: Set.unmodifiable(enabled),
      embeddedFirst: prefs.getBool(_embeddedFirstKey) ?? true,
      onlineEnabled: prefs.getBool(_onlineEnabledKey) ?? true,
      translationLanguage: prefs.getString(_translationKey) ?? 'off',
    );
  }

  Future<void> save(LyricsEngineSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_orderKey, settings.providerOrder);
    await prefs.setStringList(
      _enabledKey,
      settings.enabledProviderIds.toList(),
    );
    await prefs.setBool(_embeddedFirstKey, settings.embeddedFirst);
    await prefs.setBool(_onlineEnabledKey, settings.onlineEnabled);
    await prefs.setString(_translationKey, settings.translationLanguage);
  }
}
