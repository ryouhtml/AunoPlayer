import 'package:flutter/material.dart';

import '../../../data/repositories/recently_played_repository.dart';
import 'replay_card_options.dart';
import 'replay_card_surface.dart';
import 'replay_reveal.dart';
import 'replay_style.dart';
import 'package:auno_player/l10n/replay_l10n.dart';

/// Local listening-event insights that complement the artwork-led replay.
///
/// Legacy recaps have no event fields, so the card disappears without changing
/// any of the existing replay sections.
class ReplayInsights extends StatelessWidget {
  final ListeningRecap recap;
  final ReplayCardOptions options;
  final ScrollController scrollController;

  const ReplayInsights({
    super.key,
    required this.recap,
    required this.options,
    required this.scrollController,
  });

  bool get hasInsights =>
      recap.actualListenedMs != null ||
      recap.streakDays != null ||
      recap.hourBuckets != null ||
      recap.firstListenedAt != null ||
      recap.listeningPersonality != null;

  @override
  Widget build(BuildContext context) {
    if (!hasInsights) return const SizedBox.shrink();
    final palette = ReplayCardPalette.resolve(options, ReplayCardKind.overview);
    return ReplayReveal(
      scrollController: scrollController,
      order: 1,
      child: ReplayCardSurface(
        palette: palette,
        options: options,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReplayBrand(color: palette.foreground),
              const SizedBox(height: 18),
              Text(
                l10n.recapListeningClock,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.recapListeningClockHint,
                style: TextStyle(fontSize: 12, color: palette.secondary),
              ),
              const SizedBox(height: 18),
              _HourMap(
                buckets: recap.hourBuckets ?? const <int, int>{},
                color: palette.dark ? palette.accent : ReplayStyle.acid,
                muted: palette.secondary,
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (recap.actualListenedMs != null)
                    _Chip(
                      label: l10n.recapActualListeningLabel,
                      value: ReplayStyle.durationLabel(
                        Duration(milliseconds: recap.actualListenedMs!),
                      ),
                      color: palette.foreground,
                      muted: palette.secondary,
                    ),
                  if (recap.streakDays != null && recap.streakDays! > 0)
                    _Chip(
                      label: l10n.activeDays,
                      value: l10n.recapStreakDays(recap.streakDays!),
                      color: palette.foreground,
                      muted: palette.secondary,
                    ),
                  if (recap.listeningPersonality != null)
                    _Chip(
                      label: l10n.recapPersonality,
                      value: _personality(recap.listeningPersonality!),
                      color: palette.foreground,
                      muted: palette.secondary,
                    ),
                  if (recap.firstListenedAt != null)
                    _Chip(
                      label: l10n.recapFirstListened,
                      value: _date(recap.firstListenedAt!),
                      color: palette.foreground,
                      muted: palette.secondary,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.recapLocalOnlyStats,
                style: TextStyle(fontSize: 11, color: palette.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _personality(String value) => switch (value) {
    'nightOwl' => l10n.recapPersonalityNightOwl,
    'completionist' => l10n.recapPersonalityCompletionist,
    'explorer' => l10n.recapPersonalityExplorer,
    _ => l10n.recapPersonalityBalanced,
  };

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _HourMap extends StatelessWidget {
  final Map<int, int> buckets;
  final Color color;
  final Color muted;

  const _HourMap({
    required this.buckets,
    required this.color,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final max = buckets.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 76,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var hour = 0; hour < 24; hour++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Semantics(
                      label:
                          '${l10n.recapHourLabel(hour)} · '
                          '${ReplayStyle.durationLabel(
                            Duration(milliseconds: buckets[hour] ?? 0),
                          )}',
                      child: Container(
                        height: max == 0
                            ? 3
                            : 6 +
                                ((buckets[hour] ?? 0) / max) * 70,
                        decoration: BoxDecoration(
                          color: hour == (buckets.isEmpty
                              ? -1
                              : buckets.entries
                                  .reduce((a, b) =>
                                      a.value >= b.value ? a : b)
                                  .key)
                              ? color
                              : muted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.recapHourLabel(0),
              style: TextStyle(fontSize: 10, color: muted),
            ),
            Text(
              l10n.recapHourLabel(12),
              style: TextStyle(fontSize: 10, color: muted),
            ),
            Text(
              l10n.recapHourLabel(23),
              style: TextStyle(fontSize: 10, color: muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color muted;

  const _Chip({
    required this.label,
    required this.value,
    required this.color,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: muted.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: muted)),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
