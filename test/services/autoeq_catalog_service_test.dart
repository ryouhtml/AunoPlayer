import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auno_player/providers/equalizer_provider.dart';
import 'package:auno_player/services/autoeq_catalog_service.dart';
import 'package:auno_player/services/eq_preset_service.dart';

const _revision = '7ae0f56d53074872b028649617a22bbb4232feb7';
Map<String, dynamic> _entry(String id, String brand, String model) => {
  'id': id,
  'b': brand,
  'm': model,
  't': 'over-ear',
  's': 'test',
  'pa': -7.123,
  'g': [
    [205.25, -12.2, 0.18, 'PK'],
  ],
};

class _Bundle extends CachingAssetBundle {
  _Bundle(this.entries);
  final List<Map<String, dynamic>> entries;
  @override
  Future<ByteData> load(String key) async {
    final data = key.endsWith('autoeq_brands.json')
        ? entries.map((e) => e['b']).toSet().toList()
        : entries;
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(jsonEncode(data))),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('online index is pinned to the generator lock revision', () async {
    final lock =
        jsonDecode(await File('tool/autoeq_catalog.lock.json').readAsString())
            as Map<String, dynamic>;
    expect(AutoEqCatalogService.upstreamRevision, lock['revision']);
  });

  test(
    'bundled catalog loads offline and preserves every low-Q value',
    () async {
      final raw =
          (jsonDecode(
                    await File(
                      'assets/autoeq/autoeq_catalog.json',
                    ).readAsString(),
                  )
                  as List)
              .cast<Map<String, dynamic>>();
      final service = AutoEqCatalogService(bundle: _Bundle(raw));
      final entries = await service.loadBundled();
      final brands = await service.loadBrands();
      expect(entries, hasLength(466));
      expect(brands.toSet(), entries.map((e) => e.brand).toSet());
      final bundledBrands =
          jsonDecode(
                await File('assets/autoeq/autoeq_brands.json').readAsString(),
              )
              as List;
      expect(bundledBrands.toSet(), brands.toSet());
      var lowQCount = 0;
      for (var i = 0; i < entries.length; i++) {
        expect(entries[i].preampDb, raw[i]['pa']);
        final filters = raw[i]['g'] as List;
        for (var j = 0; j < filters.length; j++) {
          expect(entries[i].bands[j].q, filters[j][2]);
          if (entries[i].bands[j].q < 0.2) lowQCount++;
        }
      }
      expect(lowQCount, 21);
      expect(identical(await service.loadBundled(), entries), isTrue);
      expect(() => entries.clear(), throwsUnsupportedError);
    },
  );

  test(
    'search supports multi-word order, all tokens, punctuation and brand filters',
    () async {
      final service = AutoEqCatalogService(
        bundle: _Bundle([
          _entry('sony', 'Sony', 'WH-1000XM5'),
          _entry('hd650', 'Sennheiser', 'HD 650'),
          _entry('pads', 'Sennheiser', 'HD 650 (new earpads)'),
          _entry('cra', 'CCA', 'CRA'),
          _entry('plus', 'CCA', 'CRA+'),
          _entry('unicode', '音特美', 'ER4'),
          {..._entry('alias', '7Hz', 'Timeless'), 'n': '7Hertz Timeless'},
        ]),
      );
      await service.loadBundled();
      expect(service.search('HD 650').first.entry.id, 'hd650');
      expect(service.search('650 senn').first.entry.id, 'hd650');
      expect(service.search('senn nonexistent'), isEmpty);
      expect(service.search('sony 1000 xm5').single.entry.id, 'sony');
      expect(
        service.search('wh1000xm5', brand: 'sony').single.entry.id,
        'sony',
      );
      expect(service.search('hd650', brand: 'Sony'), isEmpty);
      expect(service.search('CRA+').single.entry.id, 'plus');
      expect(service.search('音特美 ER4').single.entry.id, 'unicode');
      expect(service.search('7Hertz Timeless').single.entry.id, 'alias');
      expect(service.search('???', limit: 2), hasLength(2));
      expect(service.search('', limit: 0), isEmpty);
      expect(service.search('', limit: -1), isEmpty);
    },
  );

  test('rejects duplicate IDs and unsupported catalog filters', () async {
    final entry = _entry('same', 'Brand', 'Model');
    await expectLater(
      AutoEqCatalogService(bundle: _Bundle([entry, entry])).loadBundled(),
      throwsFormatException,
    );
    expect(
      () => AutoEqEntry.fromJson({
        ...entry,
        'g': [
          [1000, 2, 1, 'AP'],
        ],
      }),
      throwsFormatException,
    );
  });

  test(
    'saved correction is a settings snapshot independent of later catalog data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final original = AutoEqEntry.fromJson(_entry('stable', 'Brand', 'Model'));
      final saved = original.toEqPreset();
      final storage = EqPresetService();
      await storage.upsertCustomPreset(saved);
      final updated = AutoEqEntry.fromJson({
        ..._entry('stable', 'Brand', 'Model'),
        'pa': -2,
        'g': [
          [1000, 4, 1, 'PK'],
        ],
      });
      expect(updated.id, original.id);
      final restored = (await EqPresetService().loadCustomPresets()).single;
      expect(restored.toJson(), saved.toJson());
      expect(restored.preampDb, -7.123);
      expect(restored.parametricBands.single.q, 0.18);
    },
  );
}

