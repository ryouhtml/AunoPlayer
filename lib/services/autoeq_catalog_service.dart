import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:auno_player/providers/equalizer_provider.dart';
import 'package:auno_player/services/autoeq_format.dart';
import 'package:auno_player/services/eq_preset_service.dart';

const Map<String, ParametricBandType> _kCodeToBandType = {
  'PK': ParametricBandType.peaking,
  'LS': ParametricBandType.lowShelf,
  'HS': ParametricBandType.highShelf,
};

class AutoEqEntry {
  const AutoEqEntry({
    required this.id,
    required this.brand,
    required this.model,
    required this.type,
    required this.source,
    required this.preampDb,
    required this.bands,
    this.upstreamName,
    this.rig,
    this.upstreamPath,
    this.upstreamRevision,
    this.upstreamSha256,
    this.target,
  });

  final String id;
  final String brand;
  final String model;
  final String type; // in-ear, earbud, over-ear, ...
  final String source; // measurement campaign
  final double preampDb;
  final List<ParametricBand> bands;
  final String? upstreamName;
  final String? rig;
  final String? upstreamPath;
  final String? upstreamRevision;
  final String? upstreamSha256;
  // Null means upstream did not identify a target unambiguously. Never infer
  // a Harman version from headphone category alone.
  final String? target;

  String get displayName => upstreamName ?? '$brand $model';

  factory AutoEqEntry.fromJson(Map<String, dynamic> j) {
    final profile = AutoEqProfile.fromJson(j);
    String requiredString(String key) {
      final value = j[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing AutoEq field: $key');
      }
      return value;
    }

    return AutoEqEntry(
      id: requiredString('id'),
      brand: requiredString('b'),
      model: requiredString('m'),
      type: requiredString('t'),
      source: requiredString('s'),
      preampDb: profile.preampDb,
      bands: List.unmodifiable(
        profile.filters.map(
          (filter) => ParametricBand(
            frequencyHz: filter.frequencyHz,
            gainDb: filter.gainDb,
            q: filter.q,
            type: _kCodeToBandType[filter.type]!,
          ),
        ),
      ),
      upstreamName: j['n'] as String?,
      rig: j['r'] as String?,
      upstreamPath: j['p'] as String?,
      upstreamRevision: j['c'] as String?,
      upstreamSha256: j['h'] as String?,
      target: j['tg'] as String?,
    );
  }

  EqPreset toEqPreset() => EqPreset(
    id: 'autoeq_$id',
    name: displayName,
    enabled: true,
    mode: EqMode.parametric,
    preampDb: preampDb,
    graphicGainsDb: List<double>.filled(10, 0.0, growable: false),
    parametricBands: List.unmodifiable(bands),
  );
}

class AutoEqSearchResult {
  final AutoEqEntry entry;
  final int score;
  const AutoEqSearchResult(this.entry, this.score);
}

class AutoEqCatalogService {
  AutoEqCatalogService({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;
  static final AutoEqCatalogService instance = AutoEqCatalogService();

  final AssetBundle _bundle;

  static const _catalogAsset = 'assets/autoeq/autoeq_catalog.json';
  static const _brandsAsset = 'assets/autoeq/autoeq_brands.json';

  List<AutoEqEntry>? _entriesCache;
  List<String>? _brandsCache;

  /// Pinned to `tool/autoeq_catalog.lock.json`. Fetching raw files at a fixed
  /// commit avoids GitHub's anonymous API rate limit and keeps the index and
  /// profile from the same revision. Update both together deliberately.
  static const upstreamRevision = '7ae0f56d53074872b028649617a22bbb4232feb7';

  Future<List<AutoEqEntry>> loadBundled() async {
    final cached = _entriesCache;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(_catalogAsset);
    final list = jsonDecode(raw) as List;
    final entries = list
        .map((e) => AutoEqEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
    if (entries.map((e) => e.id).toSet().length != entries.length) {
      throw const FormatException('Duplicate AutoEq catalog IDs');
    }
    return _entriesCache = List.unmodifiable(entries);
  }

  Future<List<String>> loadBrands() async {
    final cached = _brandsCache;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(_brandsAsset);
    final list = (jsonDecode(raw) as List).cast<String>();
    return _brandsCache = List.unmodifiable(list);
  }

  static final _separators = RegExp(r'[^\p{L}\p{N}+]', unicode: true);
  String _norm(String s) => s.toLowerCase().replaceAll(_separators, '');

  /// Substring + token matching. Empty [query] returns everything (optionally
  /// filtered by [brand]). Score ranks exact-model and brand hits higher.
  List<AutoEqSearchResult> search(
    String query, {
    String? brand,
    int limit = 60,
  }) {
    if (limit <= 0) return const [];
    final entries = _entriesCache ?? const <AutoEqEntry>[];
    final brandNorm = brand == null || brand.isEmpty ? null : _norm(brand);
    final q = query.trim();
    final qNorm = _norm(q);
    // Tokenize before stripping separators, so reordered/partial multi-word
    // queries still work. Require every token, not just an unrelated brand hit.
    final qTokens = q
        .split(RegExp(r'\s+'))
        .map(_norm)
        .where((token) => token.isNotEmpty)
        .toList();

    final results = <AutoEqSearchResult>[];
    for (final e in entries) {
      if (brandNorm != null && _norm(e.brand) != brandNorm) continue;

      if (qNorm.isEmpty) {
        results.add(AutoEqSearchResult(e, 0));
        continue;
      }

      final modelNorm = _norm(e.model);
      final brandNormE = _norm(e.brand);
      final nameNorm = _norm(e.displayName);
      var score = 0;
      if ('$brandNormE$modelNorm' == qNorm || nameNorm == qNorm) {
        score = 1000;
      } else if (modelNorm == qNorm) {
        score = 800;
      } else if (modelNorm.contains(qNorm)) {
        score = 500;
      } else if ('$brandNormE$modelNorm'.contains(qNorm)) {
        score = 300;
      } else if (qTokens.isNotEmpty) {
        var matched = 0;
        for (final t in qTokens) {
          if (modelNorm.contains(t) ||
              brandNormE.contains(t) ||
              nameNorm.contains(t)) {
            matched++;
          }
        }
        if (matched != qTokens.length) continue;
        score = 50 * matched;
      } else {
        continue;
      }
      results.add(AutoEqSearchResult(e, score));
    }

    results.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      final name = a.entry.displayName.toLowerCase().compareTo(
        b.entry.displayName.toLowerCase(),
      );
      return name != 0 ? name : a.entry.id.compareTo(b.entry.id);
    });
    return results.take(limit).toList(growable: false);
  }
}
