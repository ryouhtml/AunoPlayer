// Replay copy is English in the Taglish locale.
//
// Replay screens and their poster/export widgets read the app-wide `l10n`
// getter instead of a BuildContext, so a widget-level override cannot reach
// them. Files under `lib/features/recap/` import this library instead of
// `l10n.dart`: it re-exports every localization symbol and API, but replaces
// the global `l10n` getter with the English-for-Filipino copy role. English,
// Indonesian, Spanish and Chinese are unchanged (`englishForFilipino` returns
// the current localized catalog for them).

import 'package:auno_player/l10n/l10n.dart' as base;

export 'package:auno_player/l10n/l10n.dart' hide l10n;

base.AppLocalizations get l10n => base.l10n.englishForFilipino;
