// Liveness check for the online device-search sources.
//
// Run with:  dart run tool/check_sources.dart [query]
//
// This is deliberately NOT part of `flutter test` or CI: it makes real network
// requests to third-party sites, so it would be flaky as a gate and unkind as
// a scheduled job. It exists so scraper rot is one command away from being
// visible, instead of being discovered by a user seeing an empty result list.
//
// Exit code 0 when every source is OK, 1 otherwise.

import 'dart:convert';
import 'dart:io';

import 'package:my_device/features/devices/services/device_search_service.dart';

// The app's own user agent, so this check sees what the app sees. A
// browser user agent sent from Dart gets HTTP 403 from Notebookcheck's
// Cloudflare front, which is what made the search look dead in 1.6.0.
const _userAgent = DeviceSearchService.userAgent;

const _blockMarkers = [
  'challenges.cloudflare.com',
  'turnstile',
  'cf-chl',
  '__cf_chl',
  'just a moment',
  'verify you are human',
  'navigator.webdriver',
];

/// Purpose: Report one source's health in a fixed shape.
/// Inputs: `source`, `status`, and a human-readable `detail`.
/// Returns: A new `_Check` instance.
/// Side effects: None.
/// Notes: Primarily intended for local validation or one-off tooling.
class _Check {
  final String source;
  final String status;
  final String detail;
  const _Check(this.source, this.status, this.detail);

  bool get ok => status == 'OK';
}

/// Purpose: Fetch a URL and classify the response for a source check.
/// Inputs: `client`, `url`, an optional `body` for POST, and `anchors` that
/// must be present for the markup to be considered unchanged.
/// Returns: `Future<_Check>`.
/// Side effects: Performs a network request.
/// Notes: Primarily intended for local validation or one-off tooling.
Future<_Check> _probe(
  HttpClient client,
  String source,
  Uri url, {
  Map<String, String>? body,
  required List<String> anchors,
}) async {
  try {
    final request = body == null
        ? await client.getUrl(url)
        : await client.postUrl(url);
    request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    request.headers.set(HttpHeaders.acceptHeader, 'text/html');
    request.headers.set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
    request.followRedirects = true;
    if (body != null) {
      final encoded = body.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}='
                '${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&');
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
      request.write(encoded);
    }

    final response = await request.close().timeout(const Duration(seconds: 20));
    final html = await response
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();

    if (response.statusCode == 403) {
      return _Check(source, 'BLOCKED', 'HTTP 403');
    }
    if (response.statusCode != 200) {
      return _Check(source, 'UNREACHABLE', 'HTTP ${response.statusCode}');
    }

    final lower = html.toLowerCase();
    final marker = _blockMarkers.where(lower.contains).firstOrNull;
    if (marker != null) {
      // The important case: a challenge page served as HTTP 200.
      return _Check(source, 'BLOCKED', 'bot-wall marker "$marker" in a 200');
    }

    final missing = anchors.where((a) => !html.contains(a)).toList();
    if (missing.isNotEmpty) {
      return _Check(
        source,
        'MARKUP-CHANGED',
        'missing anchor(s): ${missing.join(", ")}',
      );
    }

    return _Check(source, 'OK', '${html.length} bytes, all anchors present');
  } on Object catch (e) {
    return _Check(source, 'UNREACHABLE', e.toString().split('\n').first);
  }
}

/// Purpose: Probe every configured source and print a health table.
/// Inputs: Optional command-line `args`; `args[0]` overrides the test query.
/// Returns: None.
/// Side effects: Performs network requests; writes to stdout; sets `exitCode`.
/// Notes: Primarily intended for local validation or one-off tooling.
Future<void> main(List<String> args) async {
  final query = args.isNotEmpty ? args.first : 'Galaxy Z Fold7';
  final client = HttpClient();
  stdout.writeln('Checking device-search sources with query: "$query"\n');

  final checks = <_Check>[];

  checks.add(
    await _probe(
      client,
      'Notebookcheck search',
      Uri.parse(
        'https://www.notebookcheck.net/Laptop-Search.8223.0.html'
        '?model=${Uri.encodeComponent(query)}',
      ),
      anchors: ['<tr class="odd"', 'notebookcheck.net/'],
    ),
  );

  checks.add(
    await _probe(
      client,
      'Notebookcheck detail',
      Uri.parse(
        'https://www.notebookcheck.net/'
        'Samsung-Galaxy-Z-Fold8-Reviews-and-Specs.1352160.0.html',
      ),
      anchors: [
        '<div class="specs">',
        '<div class="specs_details">',
        'application/ld+json',
      ],
    ),
  );

  checks.add(
    await _probe(
      client,
      'PhoneDB search',
      Uri.parse('https://phonedb.net/index.php?m=device&s=list'),
      body: {'search_exp': query, 'search_header': ''},
      anchors: ['<div class="content_block">', 'm=device&id='],
    ),
  );

  checks.add(
    await _probe(
      client,
      'PhoneDB detail',
      Uri.parse('https://phonedb.net/index.php?m=device&id=25757'),
      anchors: ['<strong>Brand</strong>', '<strong>Released</strong>'],
    ),
  );

  checks.add(
    await _probe(
      client,
      'Apple docs index',
      Uri.parse('https://support.apple.com/en-us/docs/iphone'),
      anchors: ['class="product-name"', '/docs/iphone/'],
    ),
  );

  checks.add(
    await _probe(
      client,
      'Apple docs page',
      Uri.parse('https://support.apple.com/en-us/docs/iphone/301045'),
      anchors: ['link-text="tech specs"'],
    ),
  );

  checks.add(
    await _probe(
      client,
      'Apple tech specs',
      Uri.parse('https://support.apple.com/en-us/121029'),
      anchors: ['<h1', '<h3', 'cdsassets.apple.com', 'Year introduced'],
    ),
  );

  checks.add(
    await _probe(
      client,
      'Wikipedia search',
      Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&list=search'
        '&srsearch=${Uri.encodeQueryComponent(query)}&srlimit=8'
        '&srnamespace=0&format=json&formatversion=2',
      ),
      anchors: ['"search":', '"title":'],
    ),
  );

  checks.add(
    await _probe(
      client,
      'Wikipedia infobox',
      Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=parse&page=Steam_Deck'
        '&prop=wikitext&section=0&redirects=1&format=json&formatversion=2',
      ),
      anchors: ['{{Infobox', '| cpu'],
    ),
  );

  client.close();

  final width = checks
      .map((c) => c.source.length)
      .reduce((a, b) => a > b ? a : b);
  for (final check in checks) {
    stdout.writeln(
      '${check.source.padRight(width)}  '
      '${check.status.padRight(15)}  ${check.detail}',
    );
  }

  final failed = checks.where((c) => !c.ok).toList();
  stdout.writeln();
  if (failed.isEmpty) {
    stdout.writeln('All ${checks.length} checks OK.');
  } else {
    stdout.writeln('${failed.length} of ${checks.length} checks FAILED.');
    stdout.writeln(
      'A MARKUP-CHANGED result means device_search_parsers.dart needs updating '
      'and the fixtures under test/fixtures/ need recapturing.',
    );
    exitCode = 1;
  }
}
