import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:auno_player/services/lyrics_engine_settings.dart';
import 'package:auno_player/services/lyrics_providers.dart';
import 'package:auno_player/services/lyrics_repository.dart';

class LyricsEngineSettingsNotifier extends Notifier<LyricsEngineSettings> {
  bool _initialized = false;

  @override
  LyricsEngineSettings build() {
    if (!_initialized) {
      _initialized = true;
      Future<void>.microtask(_load);
    }
    return LyricsEngineSettings.defaults;
  }

  Future<void> _load() async {
    final loaded = await LyricsEngineSettingsService().load();
    if (ref.mounted) state = loaded;
  }

  Future<void> _commit(LyricsEngineSettings next) async {
    state = next;
    await LyricsEngineSettingsService().save(next);
  }

  Future<void> setProviderEnabled(String id, bool enabled) async {
    final enabledIds = {...state.enabledProviderIds};
    if (enabled) {
      enabledIds.add(id);
    } else {
      enabledIds.remove(id);
    }
    await _commit(
      state.copyWith(enabledProviderIds: Set.unmodifiable(enabledIds)),
    );
  }

  Future<void> moveProvider(int oldIndex, int newIndex) async {
    final order = [...state.providerOrder];
    if (oldIndex < 0 || oldIndex >= order.length) return;

    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, order.length - 1);
    if (target == oldIndex) return;

    final id = order.removeAt(oldIndex);
    order.insert(target, id);
    await _commit(state.copyWith(providerOrder: List.unmodifiable(order)));
  }

  Future<void> setEmbeddedFirst(bool value) async {
    await _commit(state.copyWith(embeddedFirst: value));
  }

  Future<void> setOnlineEnabled(bool value) async {
    await _commit(state.copyWith(onlineEnabled: value));
  }

  Future<void> setTranslationLanguage(String language) async {
    await _commit(state.copyWith(translationLanguage: language));
  }

  Future<void> resetToDefaults() async {
    await _commit(LyricsEngineSettings.defaults);
  }
}

final lyricsEngineSettingsProvider =
    NotifierProvider<LyricsEngineSettingsNotifier, LyricsEngineSettings>(
      LyricsEngineSettingsNotifier.new,
    );

final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  final repository = LyricsRepository();
  ref.onDispose(repository.cancelPending);
  return repository;
});

/// Enabled providers in priority order, used by the settings summary.
final enabledLyricsProvidersProvider = Provider<List<LyricsProvider>>((ref) {
  final settings = ref.watch(lyricsEngineSettingsProvider);
  final providers = <LyricsProvider>[];
  for (final id in settings.providerOrder) {
    if (!settings.enabledProviderIds.contains(id)) continue;
    final provider = lyricsProviderById(id);
    if (provider != null) providers.add(provider);
  }
  return List.unmodifiable(providers);
});
