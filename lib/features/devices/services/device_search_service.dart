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

/// One source's contribution to a search, before merging.
class _SourceResponse {
  final List<DeviceSearchResult> results;
  final DeviceSearchStatus status;

  const _SourceResponse(this.results, this.status);

  const _SourceResponse.failed(this.status) : results = const [];
}

/// Service to search for device specs from online databases.
///
/// Sources, and why these:
/// - **Notebookcheck** covers laptops, tablets, phones and smartwatches, and
///   its device pages carry a complete spec table.
/// - **phonedb** covers phones in more depth, including SKU-level variants,
///   but answers a model it does not carry with a loose full-text match, so
///   its results go through a relevance gate.
///
/// GSMArena was removed: it serves a Cloudflare Turnstile challenge with HTTP
/// 200 to every request, which no HTTP-only client can pass.
class DeviceSearchService {
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

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
  /// Notes: Returns an empty response in store builds. Sources are queried
  /// concurrently over one shared client; one failing source never prevents
  /// another from returning results.
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
      final responses = await Future.wait([
        _searchNotebookcheck(client, trimmed),
        _searchPhonedb(client, trimmed),
      ]);
      const names = ['Notebookcheck', 'PhoneDB'];

      final results = <DeviceSearchResult>[];
      final outcomes = <DeviceSourceOutcome>[];
      for (var i = 0; i < responses.length; i++) {
        results.addAll(responses[i].results);
        outcomes.add(
          DeviceSourceOutcome(
            source: names[i],
            status: responses[i].status,
            resultCount: responses[i].results.length,
          ),
        );
      }
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
  /// no source URL, or when the source is unknown. Adding a source without a
  /// case here silently skips detail fetching for it.
  static Future<DeviceSearchResult> fetchDetail(
    DeviceSearchResult result,
  ) async {
    if (AppFlavor.isStore) return result;
    if (result.sourceUrl == null) return result;

    final client = http.Client();
    try {
      switch (result.source) {
        case 'Notebookcheck':
          return await _fetchNotebookcheckDetail(client, result);
        case 'PhoneDB':
          return await _fetchPhonedbDetail(client, result);
        default:
          return result;
      }
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
      storage: parseCapacity(
        specs['Non-volatile Memory Capacity (converted)'],
      ),
      screenSize: parseScreenSizeMm(specs['Display Diagonal']),
      screenResolutionW: resW,
      screenResolutionH: resH,
      battery: parseBattery(specs['Nominal Battery Capacity']),
      os: specs['Operating System'],
      releaseDate: parseReleaseDate(specs['Released']),
    );
  }
}
