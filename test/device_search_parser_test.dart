import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/services/device_search_parsers.dart';

/// Purpose: Read a saved source fixture from `test/fixtures/`.
/// Inputs: `name` — the fixture file name.
/// Returns: The fixture contents as a string.
/// Side effects: Reads from the local file system.
/// Notes: Fixtures are trimmed captures of the live sources, so a failure here
/// means either a parser regression or that the captured markup was changed.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  group('decodeEntities / stripHtml', () {
    test('decodes entities instead of deleting them', () {
      // The old implementation deleted entities, turning "12&nbsp;GB" into
      // "12GB" and "&amp;" into "".
      expect(decodeEntities('12&nbsp;GB'), '12 GB');
      expect(decodeEntities('AT&amp;T'), 'AT&T');
      expect(decodeEntities('&lt;tag&gt;'), '<tag>');
      expect(decodeEntities('&#39;quoted&#39;'), "'quoted'");
      expect(decodeEntities('&#x41;'), 'A');
    });

    test('leaves unknown entities verbatim', () {
      expect(decodeEntities('&notareal;'), '&notareal;');
    });

    test('does not double-decode', () {
      expect(decodeEntities('&amp;nbsp;'), '&nbsp;');
    });

    test('strips tags to whitespace and collapses runs', () {
      expect(stripHtml('<b>Intel</b><i>Core</i>'), 'Intel Core');
      expect(stripHtml('  <p>4800&nbsp;mAh</p>  '), '4800 mAh');
    });
  });

  group('looksBlocked', () {
    test('flags the captured Cloudflare challenge served as HTTP 200', () {
      expect(looksBlocked(fixture('cloudflare_challenge.html')), isTrue);
    });

    test('does not flag a genuine results page', () {
      expect(looksBlocked(fixture('notebookcheck_search.html')), isFalse);
      expect(looksBlocked(fixture('phonedb_search.html')), isFalse);
    });
  });

  group('cleanDeviceName', () {
    test('strips the Notebookcheck "Reviews and Specs" suffix', () {
      expect(
        cleanDeviceName('Samsung Galaxy Z Fold8 - Reviews and Specs'),
        'Samsung Galaxy Z Fold8',
      );
      expect(
        cleanDeviceName('Samsung Galaxy Z Fold8 Ultra - Reviews and Specs'),
        'Samsung Galaxy Z Fold8 Ultra',
      );
    });

    test('leaves an already-plain name alone', () {
      expect(
        cleanDeviceName('Samsung Galaxy Z Fold7'),
        'Samsung Galaxy Z Fold7',
      );
    });

    test('strips phonedb SKU noise down to the marketing name', () {
      expect(
        cleanDeviceName(
          'Samsung SM-F9660 Galaxy Z Fold7 5G Dual SIM TD-LTE CN HK TW 1TB  (Samsung Q7) specs',
        ),
        'Samsung Galaxy Z Fold7 CN HK TW',
      );
    });
  });

  group('isReviewArticle', () {
    test('keeps a cleaned device name', () {
      // This is the regression that mattered: the raw title contains the word
      // "Reviews", so filtering before cleaning discarded the newest devices.
      expect(
        isReviewArticle(
          cleanDeviceName('Samsung Galaxy Z Fold8 - Reviews and Specs'),
        ),
        isFalse,
      );
      expect(isReviewArticle('Samsung Galaxy Z Fold7'), isFalse);
      expect(isReviewArticle('Lenovo ThinkPad X13 G6 Intel'), isFalse);
    });

    test('rejects genuine editorial titles', () {
      expect(
        isReviewArticle(
          'The market leader strikes back – Samsung Galaxy Z Fold7 review',
        ),
        isTrue,
      );
      expect(isReviewArticle('Galaxy S26 vs iPhone 17 Pro'), isTrue);
      expect(isReviewArticle('ab'), isTrue);
    });
  });

  group('relevance gate', () {
    test('accepts a result that carries every query token', () {
      expect(
        isRelevant(
          'Galaxy Z Fold7',
          'Samsung SM-F9660 Galaxy Z Fold7 5G Dual SIM TD-LTE CN HK TW 1TB',
        ),
        isTrue,
      );
      expect(isRelevant('Galaxy Z Fold8', 'Samsung Galaxy Z Fold8'), isTrue);
    });

    test('drops phonedb noise for a model it does not carry', () {
      // phonedb answers "Galaxy Z Fold8" with 120 unrelated Galaxy phones.
      expect(
        isRelevant(
          'Galaxy Z Fold8',
          'Samsung SM-E566B/DS Galaxy F56 5G 2025 Dual SIM Global TD-LTE 128GB',
        ),
        isFalse,
      );
    });

    test('ignores single characters but keeps model generations', () {
      expect(tokenize('Galaxy Z Fold8'), ['galaxy', 'fold8']);
      expect(tokenize('iPhone 17 Pro Max'), ['iphone', '17', 'pro', 'max']);
    });

    test('scores partial matches between 0 and 1', () {
      expect(relevanceScore('Galaxy Z Fold8', 'Galaxy F56'), closeTo(0.5, 1e-9));
      expect(relevanceScore('', 'anything'), 0);
    });
  });

  group('value parsers', () {
    test('parseCapacity normalises decimal and binary units', () {
      expect(parseCapacity('12 GB , LPDDR5x'), '12 GB');
      expect(parseCapacity('256 GB UFS 4.0 Flash, 256 GB , 217.8 GB free'),
          '256 GB');
      expect(parseCapacity('12 GiB RAM'), '12 GB');
      expect(parseCapacity('256 GB ROM'), '256 GB');
      expect(parseCapacity('no capacity here'), isNull);
    });

    test('parseMemory splits a combined storage/RAM string', () {
      expect(parseMemory('256GB 12GB RAM'), ('12 GB', '256 GB'));
      expect(parseMemory('1TB 16GB RAM'), ('16 GB', '1 TB'));
      expect(parseMemory('8GB RAM'), ('8 GB', null));
      expect(parseMemory(null), (null, null));
    });

    test('parseScreenSize reads inches', () {
      expect(parseScreenSize('7.60 inch 4:3, 2448 x 1848 pixel'), '7.60"');
      expect(parseScreenSize('6.80" 3120x1440'), '6.80"');
      expect(parseScreenSize('16.2 inches'), '16.2"');
    });

    test('parseScreenSizeMm converts phonedb millimetres to inches', () {
      expect(parseScreenSizeMm('159.3 mm'), '6.27"');
      expect(parseScreenSizeMm('0 mm'), isNull);
    });

    test('parseResolution prefers the pixel-labelled figure', () {
      // "4:3" must not be mistaken for a resolution.
      expect(
        parseResolution('7.60 inch 4:3, 2448 x 1848 pixel 404 PPI'),
        (2448, 1848),
      );
      expect(parseResolution('1080x2340'), (1080, 2340));
      expect(parseResolution('no resolution'), (null, null));
    });

    test('parseBattery reads mAh and Wh', () {
      expect(parseBattery('4800 mAh Lithium-Ion, Silicon-Carbon- Anode'),
          '4800 mAh');
      expect(parseBattery('100 Wh'), '100 Wh');
      expect(parseBattery('unknown'), isNull);
    });

    test('parseMonth accepts full names and abbreviations', () {
      expect(parseMonth('September'), 9);
      expect(parseMonth('Mar'), 3);
      expect(parseMonth('xx'), isNull);
    });

    test('parseReleaseDate reads year-first dates', () {
      expect(parseReleaseDate('2026 Mar 12'), DateTime(2026, 3, 12));
      expect(
        parseReleaseDate('Released 2024, September 20'),
        DateTime(2024, 9, 20),
      );
      expect(parseReleaseDate('2024, September'), DateTime(2024, 9));
      expect(parseReleaseDate('nothing'), isNull);
    });

    test('parseUsDate reads the Notebookcheck MM/DD/YYYY form', () {
      expect(parseUsDate('07/22/2026'), DateTime(2026, 7, 22));
      expect(parseUsDate('13/22/2026'), isNull);
    });

    test('parseChipName drops clock and core detail', () {
      expect(
        parseChipName(
          'Qualcomm Snapdragon 8 Elite Gen 5 for Galaxy 8c/8t, '
          '2 x 4.7 GHz Qualcomm Oryon Gen 3 Prime',
        ),
        'Qualcomm Snapdragon 8 Elite Gen 5 for Galaxy',
      );
      expect(parseChipName('Qualcomm Adreno 840'), 'Qualcomm Adreno 840');
    });

    test('isLikelyDeviceImage rejects adverts even with an image extension', () {
      expect(
        isLikelyDeviceImage(
          'https://www.notebookcheck.net/fileadmin/Notebooks/x.jpg',
        ),
        isTrue,
      );
      expect(isLikelyDeviceImage('https://images.amazon.com/thing.jpg'),
          isFalse);
      expect(isLikelyDeviceImage('https://x.test/banner.png'), isFalse);
      expect(isLikelyDeviceImage('https://x.test/page.html'), isFalse);
    });

    test('splitBrandModel keeps multi-word brands intact', () {
      expect(splitBrandModel('Samsung Galaxy Z Fold8'),
          ('Samsung', 'Galaxy Z Fold8'));
      expect(splitBrandModel('Raspberry Pi 5'), ('Raspberry Pi', '5'));
      expect(splitBrandModel('Solo'), ('Solo', null));
    });
  });

  group('parseNotebookcheckSpecs', () {
    late Map<String, String> specs;

    setUpAll(() => specs = parseNotebookcheckSpecs(
          fixture('notebookcheck_detail.html'),
        ));

    test('reads every mapped label', () {
      expect(
        specs.keys,
        containsAll([
          'Processor',
          'Graphics adapter',
          'Memory',
          'Display',
          'Storage',
          'Battery',
          'Operating System',
          'Released',
        ]),
      );
    });

    test('does not truncate a value at the nested specs_indicator', () {
      // div.specs_details nests div.specs_indicator; a naive "</div></div>"
      // match loses everything after it, dropping ", LPDDR5x".
      expect(specs['Memory'], contains('12 GB'));
      expect(specs['Memory'], contains('LPDDR5x'));
    });

    test('yields the values the search result maps onto', () {
      expect(parseChipName(specs['Processor']),
          'Qualcomm Snapdragon 8 Elite Gen 5 for Galaxy');
      expect(specs['Graphics adapter'], 'Qualcomm Adreno 840');
      expect(parseCapacity(specs['Memory']), '12 GB');
      expect(parseCapacity(specs['Storage']), '256 GB');
      expect(parseScreenSize(specs['Display']), '7.60"');
      expect(parseResolution(specs['Display']), (2448, 1848));
      expect(parseBattery(specs['Battery']), '4800 mAh');
      expect(specs['Operating System'], 'Android 17');
      expect(parseUsDate(specs['Released']), DateTime(2026, 7, 22));
    });

    test('returns an empty map when the markup is unrecognised', () {
      expect(parseNotebookcheckSpecs('<html><body>nothing</body></html>'),
          isEmpty);
    });
  });

  group('parsePhonedbSpecs', () {
    late Map<String, String> specs;

    setUpAll(
      () => specs = parsePhonedbSpecs(fixture('phonedb_detail.html')),
    );

    test('reads the datasheet rows', () {
      expect(specs['Brand'], 'Samsung');
      expect(specs['Model'], contains('Galaxy S26'));
      expect(specs['Operating System'], 'Google Android 16 (Baklava)');
    });

    test('yields the values the search result maps onto', () {
      expect(parseReleaseDate(specs['Released']), DateTime(2026, 3, 12));
      expect(parseCapacity(specs['RAM Capacity (converted)']), '12 GB');
      expect(
        parseCapacity(specs['Non-volatile Memory Capacity (converted)']),
        '256 GB',
      );
      expect(parseScreenSizeMm(specs['Display Diagonal']), '6.27"');
      expect(parseResolution(specs['Resolution']), (1080, 2340));
      expect(parseBattery(specs['Nominal Battery Capacity']), '4300 mAh');
      expect(
        parseChipName(specs['CPU']),
        startsWith('Qualcomm Snapdragon 8 Elite Gen 5'),
      );
    });

    test('returns an empty map when the markup is unrecognised', () {
      expect(parsePhonedbSpecs('<html><body>nothing</body></html>'), isEmpty);
    });
  });
}
