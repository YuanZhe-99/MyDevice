import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../app/flavor.dart';
import 'device_search_parsers.dart';

/// Why a source returned what it did.
///
/// The previous design collapsed every failure into an empty result list, so a
/// blocked source, a changed page layout and a genuinely unknown device all
/// surfaced as "No results found". That is how GSMArena stayed broken without
/// anyone noticing. Each source now reports which of these happened.
enum DeviceSearchStatus {
  /// The source answered and its markup parsed. `resultCount` may still be 0
  /// when the device is genuinely not in that database.
  ok,

  /// The source served a bot-wall or challenge page instead of content.
  blocked,

  /// The source could not be reached at all: DNS, socket, timeout or 5xx.
  unreachable,

  /// The source answered, but none of the structures the parser anchors on
  /// were present — the page layout changed and the scraper needs updating.
  markupChanged,
}

/// The outcome of querying one source.
class DeviceSourceOutcome {
  final String source;
  final DeviceSearchStatus status;
  final int resultCount;

  /// Purpose: Record how one source responded to a query.
  /// Inputs: `source` name, `status`, and `resultCount`.
  /// Returns: A new `DeviceSourceOutcome` instance.
  /// Side effects: None.
  /// Notes: None.
  const DeviceSourceOutcome({
    required this.source,
    required this.status,
    this.resultCount = 0,
  });

  /// Purpose: Report whether this source failed rather than simply found nothing.
  /// Inputs: None.
  /// Returns: `true` for every status other than `ok`.
  /// Side effects: None.
  /// Notes: An `ok` outcome with `resultCount == 0` is not a failure.
  bool get failed => status != DeviceSearchStatus.ok;
}

/// The combined result of a search across every enabled source.
class DeviceSearchResponse {
  final List<DeviceSearchResult> results;
  final List<DeviceSourceOutcome> outcomes;

  /// Purpose: Hold the merged results and the per-source outcomes.
  /// Inputs: `results` and `outcomes`.
  /// Returns: A new `DeviceSearchResponse` instance.
  /// Side effects: None.
  /// Notes: None.
  const DeviceSearchResponse({required this.results, required this.outcomes});

  /// Purpose: List the sources that failed.
  /// Inputs: None.
  /// Returns: The outcomes whose status is not `ok`.
  /// Side effects: None.
  /// Notes: Used by the dialog to explain an empty result list.
  List<DeviceSourceOutcome> get failures =>
      outcomes.where((o) => o.failed).toList();

  /// Purpose: Report whether every queried source failed.
  /// Inputs: None.
  /// Returns: `true` when at least one source was queried and none succeeded.
  /// Side effects: None.
  /// Notes: Distinguishes "everything is broken" from "nothing matched", which
  /// the user needs to tell apart to know whether retrying is worthwhile.
  bool get allSourcesFailed =>
      outcomes.isNotEmpty && outcomes.every((o) => o.failed);
}

/// A single search result from an online device database.
class DeviceSearchResult {
  final String source;
  final String? sourceUrl;
  final String? name;
  final String? brand;
  final String? model;
  final String? thumbnailUrl;
  final String? imageUrl;
  final String? chipset;
  final String? gpuName;
  final String? ram;
  final String? storage;
  final String? screenSize;
  final int? screenResolutionW;
  final int? screenResolutionH;
  final String? battery;
  final String? os;
  final DateTime? releaseDate;
  final bool detailFetched;

  /// Purpose: Create a search result as a source's search step parsed it.
  /// Inputs: `source` name (must match a registry entry for detail fetching),
  /// plus any fields the search row carried.
  /// Returns: A new `DeviceSearchResult` instance.
  /// Side effects: None.
  /// Notes: `detailFetched` stays false until [withDetail] merges a detail page.
  const DeviceSearchResult({
    required this.source,
    this.sourceUrl,
    this.name,
    this.brand,
    this.model,
    this.thumbnailUrl,
    this.imageUrl,
    this.chipset,
    this.gpuName,
    this.ram,
    this.storage,
    this.screenSize,
    this.screenResolutionW,
    this.screenResolutionH,
    this.battery,
    this.os,
    this.releaseDate,
    this.detailFetched = false,
  });

  /// Purpose: Merge freshly scraped detail fields onto this result.
  /// Inputs: Any detail field; omitted fields keep their existing value.
  /// Returns: A new `DeviceSearchResult` with `detailFetched` set.
  /// Side effects: None.
  /// Notes: Null-coalescing means a detail page that omits a field never wipes
  /// a value already parsed from the search row.
  DeviceSearchResult withDetail({
    String? imageUrl,
    String? chipset,
    String? gpuName,
    String? ram,
    String? storage,
    String? screenSize,
    int? screenResolutionW,
    int? screenResolutionH,
    String? battery,
    String? os,
    DateTime? releaseDate,
  }) => DeviceSearchResult(
    source: source,
    sourceUrl: sourceUrl,
    name: name,
    brand: brand,
    model: model,
    thumbnailUrl: thumbnailUrl,
    imageUrl: imageUrl ?? this.imageUrl,
    chipset: chipset ?? this.chipset,
    gpuName: gpuName ?? this.gpuName,
    ram: ram ?? this.ram,
    storage: storage ?? this.storage,
    screenSize: screenSize ?? this.screenSize,
    screenResolutionW: screenResolutionW ?? this.screenResolutionW,
    screenResolutionH: screenResolutionH ?? this.screenResolutionH,
    battery: battery ?? this.battery,
    os: os ?? this.os,
    releaseDate: releaseDate ?? this.releaseDate,
    detailFetched: true,
  );
}

/// One online source of device specs, as the service queries it.
class _Source {
  final String name;

  /// Off keeps the code, parsers and tests but stops querying the source —
  /// the switch for a source that starts blocking or changes beyond repair.
  final bool enabled;

  /// Queried only when every other source found nothing, so a broad source
  /// cannot bury exact answers under product-line articles.
  final bool fallback;

  /// Whether the source can answer this query at all; a source that does
  /// not apply is neither queried nor reported.
  final bool Function(String query) appliesTo;
  final Future<_SourceResponse> Function(http.Client client, String query)
  search;
  final Future<DeviceSearchResult> Function(
    http.Client client,
    DeviceSearchResult result,
  )
  detail;

  /// Purpose: Describe one device-search source for the registry.
  /// Inputs: `name`, `enabled`, `fallback`, `appliesTo`, `search`, `detail`.
  /// Returns: A new `_Source` instance.
  /// Side effects: None.
  /// Notes: Internal to this file; see [DeviceSearchService._sources].
  const _Source({
    required this.name,
    this.enabled = true,
    this.fallback = false,
    required this.appliesTo,
    required this.search,
    required this.detail,
  });
}

/// Purpose: Accept every query.
/// Inputs: `query` (ignored).
/// Returns: Always true.
/// Side effects: None.
/// Notes: The `appliesTo` of general-purpose sources. Internal helper used
/// within this file only.
bool _anyQuery(String query) => true;

/// One source's contribution to a search, before merging.
class _SourceResponse {
  final List<DeviceSearchResult> results;
  final DeviceSearchStatus status;

  /// Purpose: Hold one source's results and the status it reported.
  /// Inputs: `results` and `status`.
  /// Returns: A new `_SourceResponse` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _SourceResponse(this.results, this.status);

  /// Purpose: Report a source that failed before producing any results.
  /// Inputs: `status` — the failure status.
  /// Returns: A `_SourceResponse` with an empty result list.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _SourceResponse.failed(this.status) : results = const [];
}

/// Service to search for device specs from online databases.
///
/// Sources, and why these:
/// - **Apple** (Apple Support documentation) answers only for Apple
///   products, from Apple's own tech-specs pages and product renders.
/// - **Notebookcheck** covers laptops, tablets, phones and smartwatches, and
///   its device pages carry a complete spec table.
/// - **phonedb** covers phones in more depth, including SKU-level variants,
///   but answers a model it does not carry with a loose full-text match, so
///   its results go through a relevance gate.
/// - **Wikipedia** is the general fallback — consoles, handhelds and
///   anything else with its own article — read from the article's infobox.
///
/// GSMArena was removed: it serves a Cloudflare Turnstile challenge with HTTP
/// 200 to every request, which no HTTP-only client can pass.
class DeviceSearchService {
  /// Sent with every request. An honest client name, not a browser's:
  /// Cloudflare (in front of Notebookcheck) rejects a Chrome user agent that
  /// arrives over a non-Chrome TLS handshake with HTTP 403, which is what
  /// made the search look dead in 1.6.0. MediaWiki's API policy also asks
  /// for an identifying agent.
  static const userAgent = 'MyDevice (+https://github.com/YuanZhe-99/MyDevice)';

  /// Every source in the order results are listed.
  static final List<_Source> _sources = [
    _Source(
      name: 'Apple',
      enabled: true,
      appliesTo: (q) => appleFamiliesFor(q).isNotEmpty,
      search: _searchApple,
      detail: _fetchAppleDetail,
    ),
    const _Source(
      name: 'Notebookcheck',
      enabled: true,
      appliesTo: _anyQuery,
      search: _searchNotebookcheck,
      detail: _fetchNotebookcheckDetail,
    ),
    const _Source(
      name: 'PhoneDB',
      enabled: true,
      appliesTo: _anyQuery,
      search: _searchPhonedb,
      detail: _fetchPhonedbDetail,
    ),
    const _Source(
      name: 'Wikipedia',
      enabled: true,
      fallback: true,
      appliesTo: _anyQuery,
      search: _searchWikipedia,
      detail: _fetchWikipediaDetail,
    ),
  ];

  /// Purpose: List the sources a search can query.
  /// Inputs: None.
  /// Returns: The names of the enabled sources, in result order.
  /// Side effects: None.
  /// Notes: Used by tests and the health check.
  static List<String> get sourceNames => [
    for (final s in _sources)
      if (s.enabled) s.name,
  ];

  static const _timeout = Duration(seconds: 15);
  static const _maxResultsPerSource = 8;

  /// Purpose: Build the headers every scraped request sends.
  /// Inputs: `accept` — the Accept header value.
  /// Returns: A header map.
  /// Side effects: None.
  /// Notes: Kept in one place so the user agent cannot drift between the page
  /// fetch and the image download that follows it.
  static Map<String, String> headers({String accept = 'text/html'}) => {
    'User-Agent': userAgent,
    'Accept': accept,
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Purpose: Search every enabled source for devices matching a query.
  /// Inputs: `query` — the user's search text.
  /// Returns: `Future<DeviceSearchResponse>` with merged results and per-source outcomes.
  /// Side effects: Issues HTTP requests to the configured sources.
  /// Notes: Returns an empty response in store builds. Enabled sources
  /// that apply to the query are queried concurrently over one shared
  /// client; one failing source never prevents another from returning
  /// results. Fallback sources (Wikipedia) run afterwards, only when the
  /// others found nothing.
  static Future<DeviceSearchResponse> search(String query) async {
    if (AppFlavor.isStore) {
      return const DeviceSearchResponse(results: [], outcomes: []);
    }
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const DeviceSearchResponse(results: [], outcomes: []);
    }

    final client = http.Client();
    try {
      final results = <DeviceSearchResult>[];
      final outcomes = <DeviceSourceOutcome>[];
      Future<void> run(Iterable<_Source> sources) async {
        final active = sources
            .where((s) => s.enabled && s.appliesTo(trimmed))
            .toList();
        final responses = await Future.wait([
          for (final s in active) s.search(client, trimmed),
        ]);
        for (var i = 0; i < responses.length; i++) {
          results.addAll(responses[i].results);
          outcomes.add(
            DeviceSourceOutcome(
              source: active[i].name,
              status: responses[i].status,
              resultCount: responses[i].results.length,
            ),
          );
        }
      }

      await run(_sources.where((s) => !s.fallback));
      if (results.isEmpty) await run(_sources.where((s) => s.fallback));
      return DeviceSearchResponse(results: results, outcomes: outcomes);
    } finally {
      client.close();
    }
  }

  /// Purpose: Fetch the full detail page for a chosen search result.
  /// Inputs: `result` — a result returned by [search].
  /// Returns: `Future<DeviceSearchResult>`, enriched when the fetch succeeded.
  /// Side effects: Issues an HTTP request to the result's source.
  /// Notes: Returns the input unchanged in store builds, when the result has
  /// no source URL, when the source is unknown or disabled, or when the
  /// fetch fails.
  static Future<DeviceSearchResult> fetchDetail(
    DeviceSearchResult result,
  ) async {
    if (AppFlavor.isStore) return result;
    if (result.sourceUrl == null) return result;

    final client = http.Client();
    try {
      final source = _sources
          .where((s) => s.enabled && s.name == result.source)
          .firstOrNull;
      if (source == null) return result;
      return await source.detail(client, result);
    } catch (_) {
      return result;
    } finally {
      client.close();
    }
  }

  /// Purpose: Classify a transport-level failure.
  /// Inputs: `error` — the thrown object.
  /// Returns: The matching `DeviceSearchStatus`.
  /// Side effects: None.
  /// Notes: Everything that is not a recognised network fault is reported as
  /// `unreachable` rather than swallowed.
  static DeviceSearchStatus _classifyError(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException ||
        error is HandshakeException) {
      return DeviceSearchStatus.unreachable;
    }
    return DeviceSearchStatus.unreachable;
  }

  // ──── Notebookcheck ────

  /// Purpose: Search Notebookcheck's device database.
  /// Inputs: `client` and the `query` text.
  /// Returns: `Future<_SourceResponse>` with results and a status.
  /// Side effects: Issues one HTTP GET.
  /// Notes: Uses the hyphenated `Laptop-Search` path; the underscored form
  /// 301-redirects. Internal helper used within this file only.
  static Future<_SourceResponse> _searchNotebookcheck(
    http.Client client,
    String query,
  ) async {
    final url = Uri.parse(
      'https://www.notebookcheck.net/Laptop-Search.8223.0.html'
      '?model=${Uri.encodeComponent(query)}',
    );

    final String html;
    try {
      final resp = await client.get(url, headers: headers()).timeout(_timeout);
      if (resp.statusCode != 200) {
        return _SourceResponse.failed(
          resp.statusCode == 403
              ? DeviceSearchStatus.blocked
              : DeviceSearchStatus.unreachable,
        );
      }
      html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    } catch (e) {
      return _SourceResponse.failed(_classifyError(e));
    }

    if (looksBlocked(html)) {
      return _SourceResponse.failed(DeviceSearchStatus.blocked);
    }

    final rowPattern = RegExp(
      r'<tr[^>]*class="[^"]*(?:odd|even)[^"]*"[^>]*>(.*?)</tr>',
      dotAll: true,
    );
    final rows = rowPattern.allMatches(html).toList();
    if (rows.isEmpty) {
      // Zero matches renders the search page with no results table. Only a
      // missing search page means the markup actually changed.
      return _SourceResponse(
        const [],
        isNotebookcheckSearchPage(html)
            ? DeviceSearchStatus.ok
            : DeviceSearchStatus.markupChanged,
      );
    }

    final linkPattern = RegExp(
      r'<a[^>]*href="(https?://www\.notebookcheck\.net/[^"]+)"[^>]*>([^<]+)</a>',
    );

    final results = <DeviceSearchResult>[];
    final seen = <String>{};

    for (final rowMatch in rows) {
      if (results.length >= _maxResultsPerSource) break;
      final row = rowMatch.group(1)!;

      final linkMatch = linkPattern.firstMatch(row);
      if (linkMatch == null) continue;

      final href = linkMatch.group(1)!;
      final name = cleanDeviceName(linkMatch.group(2)!);
      if (name.isEmpty) continue;
      if (isReviewArticle(name)) continue;
      if (!isRelevant(query, name)) continue;
      if (!seen.add(name.toLowerCase())) continue;

      // Inline specs follow the <br/> as "GPU, CPU, screen" resolution, weight".
      String? gpuName, chipset, screenSize;
      int? resW, resH;
      final brIdx = row.indexOf('<br/>');
      if (brIdx > 0) {
        final parts = stripHtml(
          row.substring(brIdx + 5),
        ).split(',').map((s) => s.trim()).toList();
        if (parts.isNotEmpty) gpuName = parts[0];
        if (parts.length > 1) chipset = parts[1];
        for (final part in parts) {
          final size = parseScreenSize(part);
          final (w, h) = parseResolution(part);
          if (size != null && w != null) {
            screenSize = size;
            resW = w;
            resH = h;
            break;
          }
        }
      }

      final (brand, model) = splitBrandModel(name);
      results.add(
        DeviceSearchResult(
          source: 'Notebookcheck',
          sourceUrl: href,
          name: name,
          brand: brand,
          model: model,
          chipset: chipset,
          gpuName: gpuName,
          screenSize: screenSize,
          screenResolutionW: resW,
          screenResolutionH: resH,
        ),
      );
    }

    return _SourceResponse(results, DeviceSearchStatus.ok);
  }

  /// Purpose: Read a Notebookcheck device page for full specs and an image.
  /// Inputs: `client` and the `result` to enrich.
  /// Returns: `Future<DeviceSearchResult>`.
  /// Side effects: Issues one HTTP GET.
  /// Notes: The spec table is the whole point of this fetch — the previous
  /// implementation read only the JSON-LD image and threw the table away, so
  /// RAM, storage, battery, OS and release date never arrived. Internal
  /// helper used within this file only.
  static Future<DeviceSearchResult> _fetchNotebookcheckDetail(
    http.Client client,
    DeviceSearchResult result,
  ) async {
    final resp = await client
        .get(Uri.parse(result.sourceUrl!), headers: headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) return result;

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    if (looksBlocked(html)) return result;

    final specs = parseNotebookcheckSpecs(html);
    final display = specs['Display'];
    final (resW, resH) = parseResolution(display);

    return result.withDetail(
      imageUrl: _jsonLdImage(html),
      chipset: parseChipName(specs['Processor']),
      gpuName: parseChipName(specs['Graphics adapter']),
      ram: parseCapacity(specs['Memory']),
      storage: parseCapacity(specs['Storage']),
      screenSize: parseScreenSize(display),
      screenResolutionW: resW,
      screenResolutionH: resH,
      battery: parseBattery(specs['Battery']),
      os: specs['Operating System'],
      releaseDate: parseUsDate(specs['Released']),
    );
  }

  /// Purpose: Pull a product image URL out of a page's JSON-LD blocks.
  /// Inputs: `html` — the full page markup.
  /// Returns: The image URL, or null.
  /// Side effects: None.
  /// Notes: Accepts both the object and bare-string forms of `image`, and
  /// filters the result through `isLikelyDeviceImage`. Internal helper used
  /// within this file only.
  static String? _jsonLdImage(String html) {
    final blocks = RegExp(
      r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
      dotAll: true,
    ).allMatches(html);

    for (final block in blocks) {
      try {
        final data = jsonDecode(block.group(1)!);
        if (data is! Map<String, dynamic>) continue;
        if (data['@type'] != 'Product') continue;
        final img = data['image'];
        final url = img is Map<String, dynamic>
            ? img['url'] as String?
            : (img is String ? img : null);
        if (url != null && isLikelyDeviceImage(url)) return url;
      } catch (_) {
        // Not valid JSON, or not a Product block — try the next one.
      }
    }
    return null;
  }

  // ──── phonedb ────

  /// Purpose: Search phonedb's device database.
  /// Inputs: `client` and the `query` text.
  /// Returns: `Future<_SourceResponse>` with results and a status.
  /// Side effects: Issues one HTTP POST.
  /// Notes: phonedb's only working text search is the `search_exp` POST; its
  /// `filter=` and `model=` query parameters are ignored and return the
  /// site's "latest devices" list instead. Results run through the relevance
  /// gate and are deduplicated by cleaned name, which collapses the many
  /// region and capacity SKUs of one phone into a single entry. Internal
  /// helper used within this file only.
  static Future<_SourceResponse> _searchPhonedb(
    http.Client client,
    String query,
  ) async {
    final url = Uri.parse('https://phonedb.net/index.php?m=device&s=list');

    final String html;
    try {
      final resp = await client
          .post(
            url,
            headers: {
              ...headers(),
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'search_exp': query, 'search_header': ''},
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        return _SourceResponse.failed(
          resp.statusCode == 403
              ? DeviceSearchStatus.blocked
              : DeviceSearchStatus.unreachable,
        );
      }
      html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    } catch (e) {
      return _SourceResponse.failed(_classifyError(e));
    }

    if (looksBlocked(html)) {
      return _SourceResponse.failed(DeviceSearchStatus.blocked);
    }

    final blocks = html.split('<div class="content_block">');
    if (blocks.length < 2) {
      // phonedb states "0 results match" on a perfectly healthy page.
      return _SourceResponse(
        const [],
        isPhonedbResultsPage(html)
            ? DeviceSearchStatus.ok
            : DeviceSearchStatus.markupChanged,
      );
    }

    final titlePattern = RegExp(
      r'<a[^>]*title="([^"]+)"[^>]*href="(index\.php\?m=device&(?:amp;)?id=\d+[^"]*)"',
    );
    final thumbPattern = RegExp(r'<img[^>]*src="(img/[^"]+)"');

    final results = <DeviceSearchResult>[];
    final seen = <String>{};

    for (final block in blocks.skip(1)) {
      if (results.length >= _maxResultsPerSource) break;

      final titleMatch = titlePattern.firstMatch(block);
      if (titleMatch == null) continue;

      final name = cleanDeviceName(titleMatch.group(1)!);
      if (name.isEmpty) continue;
      if (isReviewArticle(name)) continue;
      if (!isRelevant(query, name)) continue;
      if (!seen.add(name.toLowerCase())) continue;

      final href = titleMatch.group(2)!.replaceAll('&amp;', '&');
      final thumb = thumbPattern.firstMatch(block)?.group(1);
      final (brand, model) = splitBrandModel(name);

      results.add(
        DeviceSearchResult(
          source: 'PhoneDB',
          sourceUrl: 'https://phonedb.net/$href',
          name: name,
          brand: brand,
          model: model,
          thumbnailUrl: thumb != null ? 'https://phonedb.net/$thumb' : null,
        ),
      );
    }

    return _SourceResponse(results, DeviceSearchStatus.ok);
  }

  /// Purpose: Read a phonedb datasheet page for full specs.
  /// Inputs: `client` and the `result` to enrich.
  /// Returns: `Future<DeviceSearchResult>`.
  /// Side effects: Issues one HTTP GET.
  /// Notes: phonedb gives the screen diagonal in millimetres and capacities in
  /// binary units, so both go through converting parsers. Internal helper used
  /// within this file only.
  static Future<DeviceSearchResult> _fetchPhonedbDetail(
    http.Client client,
    DeviceSearchResult result,
  ) async {
    final resp = await client
        .get(Uri.parse(result.sourceUrl!), headers: headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) return result;

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    if (looksBlocked(html)) return result;

    final specs = parsePhonedbSpecs(html);
    final (resW, resH) = parseResolution(specs['Resolution']);

    return result.withDetail(
      imageUrl: result.thumbnailUrl,
      chipset: parseChipName(specs['CPU']),
      gpuName: parseChipName(specs['Graphical Controller']),
      ram: parseCapacity(specs['RAM Capacity (converted)']),
      storage: parseCapacity(specs['Non-volatile Memory Capacity (converted)']),
      screenSize: parseScreenSizeMm(specs['Display Diagonal']),
      screenResolutionW: resW,
      screenResolutionH: resH,
      battery: parseBattery(specs['Nominal Battery Capacity']),
      os: specs['Operating System'],
      releaseDate: parseReleaseDate(specs['Released']),
    );
  }

  // ──── Apple Support ────

  /// Apple Support documentation families, keyed by a word that picks them.
  static const _appleFamilies = {
    'iphone': 'iphone',
    'ipad': 'ipad',
    'mac': 'mac',
    'macbook': 'mac',
    'imac': 'mac',
    'watch': 'watch',
    'airpods': 'airpods',
  };

  /// Purpose: Tell which Apple Support families a query asks about.
  /// Inputs: `query`.
  /// Returns: The `docs/<family>` segments to read; empty for a non-Apple
  /// query.
  /// Side effects: None.
  /// Notes: Keyed on the product word, not on "Apple", so "Apple Watch" and
  /// "MacBook Pro" both work and a bare "Apple" does not fetch every index.
  static Set<String> appleFamiliesFor(String query) {
    final tokens = RegExp(
      r'[a-z]+',
    ).allMatches(query.toLowerCase()).map((m) => m.group(0)!);
    final words = tokens.toSet();
    return {
      for (final t in words)
        // "Watch" alone is not Apple's: "Galaxy Watch 7" must not query it.
        if (_appleFamilies[t] != null &&
            (t != 'watch' || words.contains('apple')))
          _appleFamilies[t]!,
    };
  }

  /// Purpose: Search Apple's support documentation for Apple products.
  /// Inputs: `client` and the `query` text.
  /// Returns: `Future<_SourceResponse>`; empty and `ok` for a non-Apple query.
  /// Side effects: Issues one HTTP GET per matching product family.
  /// Notes: Apple has no search endpoint for specs, but each family's docs
  /// index lists every model. The word "Apple" is ignored for relevance,
  /// Wi-Fi / Wi-Fi + Cellular variants collapse into one entry, and the
  /// closest names (fewest extra words) come first. Internal helper used
  /// within this file only.
  static Future<_SourceResponse> _searchApple(
    http.Client client,
    String query,
  ) async {
    final families = appleFamiliesFor(query);
    if (families.isEmpty) {
      return const _SourceResponse([], DeviceSearchStatus.ok);
    }
    final relevanceQuery = query.replaceAll(
      RegExp(r'\bapple\b', caseSensitive: false),
      ' ',
    );
    final found = <(DeviceSearchResult, int)>[];
    var status = DeviceSearchStatus.ok;
    for (final family in families) {
      final String html;
      try {
        final resp = await client
            .get(
              Uri.parse('https://support.apple.com/en-us/docs/$family'),
              headers: headers(),
            )
            .timeout(_timeout);
        if (resp.statusCode != 200) {
          status = resp.statusCode == 403
              ? DeviceSearchStatus.blocked
              : DeviceSearchStatus.unreachable;
          continue;
        }
        html = utf8.decode(resp.bodyBytes, allowMalformed: true);
      } catch (e) {
        status = _classifyError(e);
        continue;
      }
      if (!isAppleDocsIndexPage(html)) {
        status = DeviceSearchStatus.markupChanged;
        continue;
      }
      final seen = <String>{};
      for (final entry in parseAppleDocsIndex(html, family)) {
        final name = entry.name
            .replaceFirst(
              RegExp(r'\s+Wi-Fi(\s*\+\s*Cellular)?$', caseSensitive: false),
              '',
            )
            .trim();
        if (!isRelevant(relevanceQuery, name)) continue;
        if (!seen.add(name.toLowerCase())) continue;
        final extra = tokenize(name).length - tokenize(relevanceQuery).length;
        found.add((
          DeviceSearchResult(
            source: 'Apple',
            sourceUrl: entry.url,
            name: name,
            brand: 'Apple',
            model: name,
            thumbnailUrl: entry.thumbnailUrl,
          ),
          extra,
        ));
      }
    }
    if (found.isEmpty && status != DeviceSearchStatus.ok) {
      return _SourceResponse.failed(status);
    }
    // List.sort is not stable; the index keeps page order among equals.
    final order = {for (var i = 0; i < found.length; i++) found[i].$1: i};
    found.sort((a, b) {
      final byExtra = a.$2.compareTo(b.$2);
      return byExtra != 0 ? byExtra : order[a.$1]!.compareTo(order[b.$1]!);
    });
    return _SourceResponse([
      for (final f in found.take(_maxResultsPerSource)) f.$1,
    ], DeviceSearchStatus.ok);
  }

  /// Purpose: Read an Apple product's tech-specs page.
  /// Inputs: `client` and the `result` to enrich.
  /// Returns: `Future<DeviceSearchResult>`.
  /// Side effects: Issues two HTTP GETs (docs page, then its tech specs).
  /// Notes: Chip names are written the way the bundled presets spell them
  /// (`Apple A18`, `Apple M4 Pro GPU (16-core)`), so the editor can match a
  /// preset. The base configuration is used where Apple lists several.
  /// Apple states only the introduction year, which is not a release date,
  /// so none is set. Internal helper used within this file only.
  static Future<DeviceSearchResult> _fetchAppleDetail(
    http.Client client,
    DeviceSearchResult result,
  ) async {
    final docs = await client
        .get(Uri.parse(result.sourceUrl!), headers: headers())
        .timeout(_timeout);
    if (docs.statusCode != 200) return result;
    final link = findAppleTechSpecsLink(
      utf8.decode(docs.bodyBytes, allowMalformed: true),
    );
    if (link == null) return result;
    final resp = await client
        .get(Uri.parse(link), headers: headers())
        .timeout(_timeout);
    if (resp.statusCode != 200) return result;
    final specs = parseAppleTechSpecs(
      utf8.decode(resp.bodyBytes, allowMalformed: true),
    );
    return withAppleSpecs(result, specs);
  }

  /// Purpose: Map a parsed Apple tech-specs page onto a search result.
  /// Inputs: `result` — the chosen result; `specs` — the parsed page.
  /// Returns: The enriched result.
  /// Side effects: None.
  /// Notes: Public for tests. Apple writes non-breaking hyphens
  /// (`6.1‑inch`, `2556‑by‑1179`), which are normalised first. Battery is
  /// read only when Apple states a capacity (`72.4-watt-hour`); phones list
  /// playback hours instead, which are not a capacity.
  static DeviceSearchResult withAppleSpecs(
    DeviceSearchResult result,
    AppleTechSpecs specs,
  ) {
    String norm(String s) => s.replaceAll('‑', '-').replaceAll(' ', ' ');
    List<String> section(List<String> names) =>
        appleSection(specs, names).map(norm).toList();

    final chipLines = section(['Chip']);
    String? chipset;
    for (final line in chipLines) {
      final m = RegExp(
        r'^(?:Apple\s+)?(.+?)\s+chip\b',
        caseSensitive: false,
      ).firstMatch(line);
      if (m != null) {
        chipset = 'Apple ${m.group(1)!.trim()}';
        break;
      }
    }
    String? gpuName;
    for (final line in chipLines) {
      final m = RegExp(
        r'(\d+)-core GPU',
        caseSensitive: false,
      ).firstMatch(line);
      if (m != null) {
        gpuName = chipset == null ? null : '$chipset GPU (${m.group(1)}-core)';
        break;
      }
    }

    String? firstCapacity(List<String> lines) {
      for (final line in lines) {
        final c = parseCapacity(line);
        if (c != null) return c;
      }
      return null;
    }

    final memoryLines = section(['Memory']);
    final ram = firstCapacity(
      memoryLines.where((l) => l.toLowerCase().contains('memory')).toList(),
    );
    final storage = firstCapacity(section(['Storage', 'Capacity']));

    final display = section(['Display']).join(', ');
    final size = RegExp(
      r'(\d+(?:\.\d+)?)-inch',
      caseSensitive: false,
    ).firstMatch(display)?.group(1);
    final res = RegExp(
      r'(\d{3,5})-by-(\d{3,5})',
      caseSensitive: false,
    ).firstMatch(display);

    final power = section([
      'Battery and Power',
      'Power and Battery',
      'Battery',
    ]);
    String? battery;
    for (final line in power) {
      final wh = RegExp(
        r'(\d+(?:\.\d+)?)-watt-hour',
        caseSensitive: false,
      ).firstMatch(line);
      if (wh != null) {
        battery = '${wh.group(1)} Wh';
        break;
      }
      battery ??= parseBattery(line);
    }

    final osLines = section(['Operating System']);
    final os = osLines.isEmpty ? null : osLines.first;

    return result.withDetail(
      imageUrl: specs.imageUrl,
      chipset: chipset,
      gpuName: gpuName,
      ram: ram,
      storage: storage,
      screenSize: size == null ? null : '$size"',
      screenResolutionW: res == null ? null : int.parse(res.group(1)!),
      screenResolutionH: res == null ? null : int.parse(res.group(2)!),
      battery: battery,
      os: os != null && os.length <= 40 ? os : null,
    );
  }

  // ──── Wikipedia ────

  static const _wikipediaApi = 'https://en.wikipedia.org/w/api.php';

  /// Purpose: Search English Wikipedia for an article about the device.
  /// Inputs: `client` and the `query` text.
  /// Returns: `Future<_SourceResponse>` with article titles as results.
  /// Side effects: Issues one HTTP GET to the MediaWiki API.
  /// Notes: A title counts when it contains every query word, or when every
  /// word of a title of at least two words is in the query — so
  /// "Steam Deck OLED" finds the "Steam Deck" article. Disambiguation
  /// suffixes such as "(smartphone)" are dropped from the name. Internal
  /// helper used within this file only.
  static Future<_SourceResponse> _searchWikipedia(
    http.Client client,
    String query,
  ) async {
    final url = Uri.parse(_wikipediaApi).replace(
      queryParameters: {
        'action': 'query',
        'list': 'search',
        'srsearch': query,
        'srlimit': '$_maxResultsPerSource',
        'srnamespace': '0',
        'format': 'json',
        'formatversion': '2',
      },
    );
    final Map<String, dynamic> json;
    try {
      final resp = await client
          .get(url, headers: headers(accept: 'application/json'))
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        return _SourceResponse.failed(
          resp.statusCode == 403
              ? DeviceSearchStatus.blocked
              : DeviceSearchStatus.unreachable,
        );
      }
      json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      return _SourceResponse.failed(DeviceSearchStatus.markupChanged);
    } catch (e) {
      return _SourceResponse.failed(_classifyError(e));
    }
    final hits = (json['query'] as Map<String, dynamic>?)?['search'];
    if (hits is! List) {
      return _SourceResponse.failed(DeviceSearchStatus.markupChanged);
    }
    final results = <DeviceSearchResult>[];
    for (final hit in hits) {
      if (hit is! Map || hit['title'] is! String) continue;
      final title = hit['title'] as String;
      // MediaWiki capitalises the first letter: "IPhone 16" is iPhone 16.
      final name = title
          .replaceFirst(RegExp(r'\s*\([^)]*\)$'), '')
          .replaceFirstMapped(
            RegExp(r'^I(Phone|Pad|Pod|Mac)\b'),
            (m) => 'i${m[1]}',
          )
          .trim();
      final titleWords = tokenize(name);
      final relevant =
          isRelevant(query, name) ||
          (titleWords.length >= 2 && isRelevant(name, query));
      if (!relevant) continue;
      final (brand, model) = splitBrandModel(name);
      results.add(
        DeviceSearchResult(
          source: 'Wikipedia',
          sourceUrl:
              'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}',
          name: name,
          brand: brand,
          model: model,
        ),
      );
    }
    return _SourceResponse(results, DeviceSearchStatus.ok);
  }

  /// Purpose: Read a Wikipedia article's infobox and lead image.
  /// Inputs: `client` and the `result` to enrich.
  /// Returns: `Future<DeviceSearchResult>`; unchanged when the article has
  /// no device infobox.
  /// Side effects: Issues two HTTP GETs to the MediaWiki API.
  /// Notes: Only the lead section's wikitext is fetched. The image is the
  /// page image rendered at 800 px, which turns an SVG original into a PNG
  /// the app can decode. Internal helper used within this file only.
  static Future<DeviceSearchResult> _fetchWikipediaDetail(
    http.Client client,
    DeviceSearchResult result,
  ) async {
    final title = Uri.decodeComponent(
      Uri.parse(result.sourceUrl!).pathSegments.last,
    );
    final parse = await client
        .get(
          Uri.parse(_wikipediaApi).replace(
            queryParameters: {
              'action': 'parse',
              'page': title,
              'prop': 'wikitext',
              'section': '0',
              'redirects': '1',
              'format': 'json',
              'formatversion': '2',
            },
          ),
          headers: headers(accept: 'application/json'),
        )
        .timeout(_timeout);
    if (parse.statusCode != 200) return result;
    final wikitext =
        ((jsonDecode(utf8.decode(parse.bodyBytes)) as Map)['parse']
            as Map?)?['wikitext'];
    if (wikitext is! String) return result;
    final infobox = extractWikiInfobox(wikitext);
    if (infobox == null || !isWikiDeviceInfobox(infobox)) return result;

    String? imageUrl;
    try {
      final images = await client
          .get(
            Uri.parse(_wikipediaApi).replace(
              queryParameters: {
                'action': 'query',
                'titles': title,
                'prop': 'pageimages',
                'piprop': 'thumbnail',
                'pithumbsize': '800',
                'redirects': '1',
                'format': 'json',
                'formatversion': '2',
              },
            ),
            headers: headers(accept: 'application/json'),
          )
          .timeout(_timeout);
      if (images.statusCode == 200) {
        final pages =
            ((jsonDecode(utf8.decode(images.bodyBytes)) as Map)['query']
                as Map?)?['pages'];
        if (pages is List && pages.isNotEmpty && pages.first is Map) {
          imageUrl =
              ((pages.first as Map)['thumbnail'] as Map?)?['source'] as String?;
        }
      }
    } catch (_) {
      // The specs are still worth returning without an image.
    }
    return withWikipediaInfobox(result, infobox, imageUrl: imageUrl);
  }

  /// Purpose: Map a Wikipedia infobox onto a search result.
  /// Inputs: `result`; `infobox` from [extractWikiInfobox]; `imageUrl`.
  /// Returns: The enriched result.
  /// Side effects: None.
  /// Notes: Public for tests. Each field accepts the parameter names the
  /// common device infoboxes use. Where a product has variants (an LCD and
  /// an OLED model) the first listed one is read. The maker comes from
  /// `developer` before `manufacturer`, which is often a contract
  /// manufacturer such as Foxconn.
  static DeviceSearchResult withWikipediaInfobox(
    DeviceSearchResult result,
    Map<String, String> infobox, {
    String? imageUrl,
  }) {
    final display = wikiFieldText(infobox, [
      'display',
      'screen',
    ])?.replaceAll('×', 'x');
    final (resW, resH) = parseResolution(display);
    final brand = wikiBrand(
      wikiField(infobox, ['developer', 'brand', 'manufacturer']),
    );
    final name = result.name ?? '';
    final model =
        brand != null &&
            name.toLowerCase().startsWith('${brand.toLowerCase()} ')
        ? name.substring(brand.length + 1)
        : name;
    return DeviceSearchResult(
      source: result.source,
      sourceUrl: result.sourceUrl,
      name: result.name,
      brand: brand ?? result.brand,
      model: brand != null ? model : result.model,
      thumbnailUrl: result.thumbnailUrl,
    ).withDetail(
      imageUrl: imageUrl,
      chipset: parseChipName(
        wikiField(infobox, ['soc', 'system_on_chip', 'cpu', 'processor']),
      ),
      gpuName: parseChipName(wikiField(infobox, ['gpu', 'graphics'])),
      ram: parseCapacity(wikiField(infobox, ['memory', 'ram'])),
      storage: parseCapacity(wikiField(infobox, ['storage'])),
      screenSize: parseWikiScreenSize(display),
      screenResolutionW: resW,
      screenResolutionH: resH,
      battery: parseBattery(wikiFieldText(infobox, ['battery', 'power'])),
      os: wikiField(infobox, ['os', 'operating_system', 'operatingsystem']),
      releaseDate: parseWikiDate(
        wikiField(infobox, [
          'released',
          'releasedate',
          'release_date',
          'first_release',
          'release',
          'introduced',
        ]),
      ),
    );
  }
}
