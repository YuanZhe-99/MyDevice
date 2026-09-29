import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/services/device_search_parsers.dart';
import 'package:my_device/features/devices/services/device_search_service.dart';

/// Purpose: Read a saved source fixture from `test/fixtures/`.
/// Inputs: `name` — the fixture file name.
/// Returns: The fixture contents as a string.
/// Side effects: Reads a file.
/// Notes: None.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Purpose: Read the lead-section wikitext out of a saved MediaWiki reply.
/// Inputs: `name` — the fixture file name.
/// Returns: The wikitext.
/// Side effects: Reads a file.
/// Notes: None.
String wikitext(String name) =>
    ((jsonDecode(fixture(name)) as Map)['parse'] as Map)['wikitext'] as String;

/// Purpose: Cover the Apple Support and Wikipedia device-search sources.
/// Inputs: None.
/// Returns: None.
/// Side effects: Registers unit tests.
/// Notes: Fixtures are trimmed copies of real pages captured 2026-09-28;
/// no test touches the network.
void main() {
  group('source registry', () {
    test('lists the enabled sources in result order', () {
      expect(DeviceSearchService.sourceNames, [
        'Apple',
        'Notebookcheck',
        'PhoneDB',
        'Wikipedia',
      ]);
    });

    test('sends an honest user agent, not a browser one', () {
      // Cloudflare answers a Chrome agent from Dart's TLS stack with 403.
      expect(DeviceSearchService.userAgent, startsWith('MyDevice'));
      expect(
        DeviceSearchService.headers()['User-Agent'],
        startsWith('MyDevice'),
      );
    });

    test('Apple applies only to Apple product words', () {
      expect(DeviceSearchService.appleFamiliesFor('iPhone 16 Pro'), {'iphone'});
      expect(DeviceSearchService.appleFamiliesFor('MacBook Pro 14'), {'mac'});
      expect(DeviceSearchService.appleFamiliesFor('Apple Watch Ultra 2'), {
        'watch',
      });
      expect(DeviceSearchService.appleFamiliesFor('Apple'), isEmpty);
      expect(DeviceSearchService.appleFamiliesFor('Galaxy S24'), isEmpty);
      expect(DeviceSearchService.appleFamiliesFor('Galaxy Watch 7'), isEmpty);
    });
  });

  group('Apple Support parsers', () {
    test('reads the docs index without duplicates', () {
      final html = fixture('apple_docs_index.html');
      expect(isAppleDocsIndexPage(html), isTrue);
      final entries = parseAppleDocsIndex(html, 'iphone');
      expect(entries.map((e) => e.name), [
        'iPhone 16',
        'iPhone 16 Plus',
        'iPhone 16 Pro',
        'iPhone 16e',
      ]);
      expect(
        entries.first.url,
        'https://support.apple.com/en-us/docs/iphone/301045',
      );
      expect(entries.first.thumbnailUrl, contains('size=240x240'));
      expect(isAppleDocsIndexPage('<html></html>'), isFalse);
    });

    test('accepts the alphanumeric ids of older products', () {
      const html =
          '<a href="https://support.apple.com/en-us/docs/watch/pl293" '
          'class="product column"><div class="product-name">'
          'Apple Watch Series 8</div></a>';
      final entries = parseAppleDocsIndex(html, 'watch');
      expect(entries.single.name, 'Apple Watch Series 8');
      expect(entries.single.url, endsWith('/docs/watch/pl293'));
      // Attribute order does not matter.
      final swapped = parseAppleDocsIndex(
        '<a class="product" href="https://support.apple.com/en-us/docs/'
            'watch/1"><div class="product-name">Apple Watch</div></a>',
        'watch',
      );
      expect(swapped.single.name, 'Apple Watch');
    });

    test('finds the tech specs link on a product docs page', () {
      expect(
        findAppleTechSpecsLink(fixture('apple_docs_page.html')),
        'https://support.apple.com/en-us/121029',
      );
      expect(findAppleTechSpecsLink('<a href="/x">x</a>'), isNull);
    });

    test('splits a tech specs page into sections', () {
      final specs = parseAppleTechSpecs(fixture('apple_specs_iphone.html'));
      expect(specs.title, 'iPhone 16');
      expect(specs.yearIntroduced, 2024);
      expect(specs.imageUrl, endsWith('/tech-specs/iphone-16.png'));
      expect(specs.sections['Capacity'], ['128GB', '256GB', '512GB']);
      expect(appleSection(specs, ['Chip']).first, 'A18 chip');
      expect(
        appleSection(specs, ['Battery and Power', 'Power and Battery']),
        isNotEmpty,
      );
    });

    test('maps an iPhone page onto preset-style fields', () {
      final result = DeviceSearchService.withAppleSpecs(
        const DeviceSearchResult(source: 'Apple', name: 'iPhone 16'),
        parseAppleTechSpecs(fixture('apple_specs_iphone.html')),
      );
      expect(result.detailFetched, isTrue);
      expect(result.chipset, 'Apple A18');
      expect(result.gpuName, 'Apple A18 GPU (5-core)');
      expect(result.storage, '128 GB');
      expect(result.ram, isNull, reason: 'Apple does not publish iPhone RAM');
      expect(result.screenSize, '6.1"');
      expect(result.screenResolutionW, 2556);
      expect(result.screenResolutionH, 1179);
      expect(result.battery, isNull, reason: 'playback hours are not capacity');
      expect(result.os, 'iOS');
      expect(result.releaseDate, isNull, reason: 'a year is not a date');
      expect(result.imageUrl, endsWith('iphone-16.png'));
    });

    test('maps a Mac page, taking the base configuration', () {
      final result = DeviceSearchService.withAppleSpecs(
        const DeviceSearchResult(source: 'Apple', name: 'MacBook Pro'),
        parseAppleTechSpecs(fixture('apple_specs_mac.html')),
      );
      expect(result.chipset, 'Apple M4 Pro');
      expect(result.gpuName, 'Apple M4 Pro GPU (16-core)');
      expect(result.ram, '24 GB');
      expect(result.storage, '512 GB');
      expect(result.screenSize, '14.2"');
      expect(result.screenResolutionW, 3024);
      expect(result.battery, '72.4 Wh');
      expect(result.os, 'macOS');
    });
  });

  group('Wikipedia parsers', () {
    test('extracts a device infobox and rejects a company one', () {
      final deck = extractWikiInfobox(wikitext('wikipedia_steam_deck.json'))!;
      expect(isWikiDeviceInfobox(deck), isTrue);
      final company = extractWikiInfobox(wikitext('wikipedia_company.json'))!;
      expect(isWikiDeviceInfobox(company), isFalse);
      expect(extractWikiInfobox('No infobox here.'), isNull);
    });

    test('cleans list templates, links, refs and variant labels', () {
      expect(
        wikiValueItems(
          "{{ubli\n| '''LCD:''' 16 GB [[LPDDR5]]<ref>x</ref>\n| '''OLED:''' 16 GB [[LPDDR5X|LPDDR5X]]}}",
        ),
        ['16 GB LPDDR5', '16 GB LPDDR5X'],
      );
      expect(wikiValueItems('{{convert|6.1|in|mm}} [[OLED]]'), ['6.1 in OLED']);
      expect(wikiValueItems('{{Start date|2024|9|20}}'), ['2024-09-20']);
      expect(wikiValueItems('4,400 mAh'), ['4400 mAh']);
      expect(wikiValueItems('3.78 V {{nowrap|19.74 [[Watt hour|Wh]]}}'), [
        '3.78 V 19.74 Wh',
      ]);
    });

    test('reads dates, screen sizes and brands', () {
      expect(parseWikiDate('February 25, 2022'), DateTime(2022, 2, 25));
      expect(parseWikiDate('25 February 2022'), DateTime(2022, 2, 25));
      expect(parseWikiDate('2024-09-20'), DateTime(2024, 9, 20));
      expect(parseWikiDate('2024'), isNull);
      expect(parseWikiDate('2024-13-40'), isNull);
      expect(parseWikiScreenSize('7.9-in LCD'), '7.9"');
      expect(parseWikiScreenSize('6.1 in resolution'), '6.1"');
      expect(parseWikiScreenSize('7", 1280x800'), '7"');
      expect(wikiBrand('Valve Corporation'), 'Valve');
      expect(wikiBrand('Samsung Electronics'), 'Samsung');
      expect(wikiBrand('Sony, Foxconn'), 'Sony');
      expect(wikiBrand('Samsung Electronics Co., Ltd.'), 'Samsung');
    });

    test('maps the Steam Deck infobox onto a result', () {
      final infobox = extractWikiInfobox(
        wikitext('wikipedia_steam_deck.json'),
      )!;
      final result = DeviceSearchService.withWikipediaInfobox(
        const DeviceSearchResult(
          source: 'Wikipedia',
          name: 'Steam Deck',
          brand: 'Steam',
          model: 'Deck',
        ),
        infobox,
        imageUrl: 'https://upload.wikimedia.org/x.png',
      );
      expect(result.brand, 'Valve');
      expect(result.model, 'Steam Deck');
      expect(result.chipset, 'AMD "Van Gogh" APU');
      expect(result.ram, '16 GB');
      expect(result.storage, '64 GB');
      expect(result.screenSize, '7"');
      expect(result.screenResolutionW, 1280);
      expect(result.screenResolutionH, 800);
      expect(result.os, 'SteamOS');
      expect(result.releaseDate, DateTime(2022, 2, 25));
      expect(result.imageUrl, 'https://upload.wikimedia.org/x.png');
    });
  });
}
