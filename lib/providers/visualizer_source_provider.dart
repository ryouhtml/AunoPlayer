import 'package:flutter_riverpod/legacy.dart';
import 'package:auno_player/providers/player_provider.dart';
import 'package:auno_player/services/visualizer_source.dart';

/// One shared live visualizer source for every player surface.
final visualizerSourceProvider = ChangeNotifierProvider<VisualizerSource>((
  ref,
) {
  final controller = VisualizerSourceController(
    playerService: ref.watch(playerServiceProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
