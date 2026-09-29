/// Pure parsing helpers shared by the online device-search sources.
///
/// Everything in this file is network-free and side-effect-free so it can be
/// unit-tested against the saved fixtures under `test/fixtures/`. Scraped
/// markup is the most fragile part of the search feature, so the parsing lives
/// apart from the HTTP plumbing in `device_search_service.dart`.
library;

/// Named HTML entities that show up in the scraped sources.
const _namedEntities = <String, String>{
  'nbsp': ' ',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'rsquo': "'",
  'lsquo': "'",
  'rdquo': '"',
  'ldquo': '"',
  'rsaquo': '›',
  'lsaquo': '‹',
  'ndash': '–',
  'mdash': '—',
  'hellip': '…',
  'deg': '°',
  'times': '×',
  'shy': '',
  'zwj': '',
  'zwnj': '',
};

/// Purpose: Decode the HTML entities that appear in scraped source markup.
/// Inputs: `input` — raw text that may contain named or numeric entities.
/// Returns: The text with entities replaced by the characters they denote.
/// Side effects: None.
/// Notes: Decodes in a single pass so an entity produced by decoding (for
/// example `&amp;nbsp;`) is not decoded a second time. Unknown entities are
/// left verbatim rather than deleted, which is what the previous
/// implementation did and why `12&nbsp;GB` used to collapse to `12GB`.
String decodeEntities(String input) {
  return input.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (m) {
    final body = m.group(1)!;
    if (body.startsWith('#')) {
      final isHex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
      final digits = isHex ? body.substring(2) : body.substring(1);
      final code = int.tryParse(digits, radix: isHex ? 16 : 10);
      if (code == null || code < 0 || code > 0x10FFFF) return m.group(0)!;
      return String.fromCharCode(code);
    }
    return _namedEntities[body.toLowerCase()] ?? m.group(0)!;
  });
}

/// Purpose: Reduce an HTML fragment to its visible text.
/// Inputs: `html` — a fragment that may contain tags and entities.
/// Returns: Tag-free text with entities decoded and whitespace collapsed.
/// Side effects: None.
/// Notes: Tags become a space rather than nothing so `<b>A</b><i>B</i>` reads
/// as `A B` instead of `AB`.
String stripHtml(String html) {
  return decodeEntities(
    html.replaceAll(RegExp(r'<[^>]*>'), ' '),
  ).replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Purpose: Detect a bot-wall or interstitial served in place of real content.
/// Inputs: `body` — the decoded response body.
/// Returns: `true` when the body looks like a challenge page.
/// Side effects: None.
/// Notes: These pages are commonly served with HTTP 200, so a status check
/// alone cannot catch them. This is the exact failure mode that made GSMArena
/// look like "no results" for a long time instead of like a blocked source.
bool looksBlocked(String body) {
  final lower = body.toLowerCase();
  const markers = [
    'challenges.cloudflare.com',
    'turnstile',
    'cf-chl',
    'cf-challenge',
    '__cf_chl',
    'just a moment',
    'verify you are human',
    'enable javascript and cookies to continue',
    'navigator.webdriver',
    'attention required!',
  ];
  return markers.any(lower.contains);
}

// ──── Names ────

/// Purpose: Split a full device name into a brand and the remaining model.
/// Inputs: `name` — a full device name such as `Samsung Galaxy Z Fold8`.
/// Returns: A `(brand, model)` pair; `model` is null when there is no space.
/// Side effects: None.
/// Notes: Multi-word brands (`Raspberry Pi`) are recognised explicitly because
/// a plain first-space split would otherwise strand half the brand in `model`.
(String?, String?) splitBrandModel(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return (null, null);
  const multiWordBrands = [
    'Raspberry Pi',
    'Google Cloud',
    'Amazon Web Services',
    'GL.iNet',
    'Ubiquiti Networks',
  ];
  for (final brand in multiWordBrands) {
    if (trimmed.toLowerCase().startsWith('${brand.toLowerCase()} ')) {
      return (brand, trimmed.substring(brand.length + 1).trim());
    }
  }
  final idx = trimmed.indexOf(' ');
  if (idx == -1) return (trimmed, null);
  return (trimmed.substring(0, idx), trimmed.substring(idx + 1).trim());
}

/// Purpose: Normalise a scraped result title into a plain device name.
/// Inputs: `raw` — a source-specific title.
/// Returns: The name with source boilerplate and SKU noise removed.
/// Side effects: None.
/// Notes: Notebookcheck titles its canonical device pages
/// `<name> - Reviews and Specs`, and phonedb prefixes an OEM code and suffixes
/// region/SIM/capacity qualifiers. Both must be stripped *before*
/// [isReviewArticle] runs, or the newest devices are discarded as articles.
String cleanDeviceName(String raw) {
  var name = stripHtml(raw);
  // Notebookcheck / phonedb page-title boilerplate.
  name = name.replaceAll(
    RegExp(r'\s*[-–]\s*Reviews?\s*(and|&)\s*Specs\s*$', caseSensitive: false),
    '',
  );
  name = name.replaceAll(RegExp(r'\s+specs\s*$', caseSensitive: false), '');
  // phonedb trailing codename, e.g. "(Samsung Q7)".
  name = name.replaceAll(
    RegExp(r'\s*\((?:Samsung|Apple|Google)\s+[^)]*\)\s*$'),
    '',
  );
  // phonedb OEM part number, e.g. "SM-F9660 " or "SM-E566B/DS ".
  name = name.replaceAll(
    RegExp(r'\b(?:SM|SC|GM)-[A-Z0-9]+(?:/[A-Z]+)?\s+'),
    '',
  );
  // phonedb region / SIM / network / capacity qualifiers.
  name = name.replaceAll(
    RegExp(
      r'\s+(?:5G|4G|LTE|TD-LTE|UW|Dual\s+SIM|Single\s+SIM|Global|Standard\s+Edition|Premium\s+Edition|Top\s+Edition)\b',
      caseSensitive: false,
    ),
    '',
  );
  name = name.replaceAll(
    RegExp(r'\s+\d+(?:GB|TB)\b', caseSensitive: false),
    '',
  );
  return name.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Purpose: Decide whether a result title is an editorial article, not a device.
/// Inputs: `name` — a title that has already been through [cleanDeviceName].
/// Returns: `true` when the title reads as a review, comparison or benchmark.
/// Side effects: None.
/// Notes: Run this only on a cleaned name. On a raw Notebookcheck title the
/// `Reviews and Specs` suffix makes every current device look like an article.
bool isReviewArticle(String name) {
  final trimmed = name.trim();
  if (trimmed.length < 3 || trimmed.length > 80) return true;
  return RegExp(
    r'\breviews?\b|\bcomparison\b|\bversus\b|\bvs\.?\b|\bbenchmark\b|\bhands[- ]on\b|\bunboxing\b|\btest[:\s]',
    caseSensitive: false,
  ).hasMatch(trimmed);
}

// ──── Relevance ────

/// Purpose: Split a string into comparable lowercase tokens.
/// Inputs: `value` — any name or query.
/// Returns: Alphanumeric tokens of at least two characters.
/// Side effects: None.
/// Notes: Single characters are dropped so the `Z` in `Galaxy Z Fold8` does not
/// dominate scoring; two-character tokens such as `17` are kept because they
/// carry the model generation.
List<String> tokenize(String value) {
  return RegExp(r'[a-z0-9]+')
      .allMatches(value.toLowerCase())
      .map((m) => m.group(0)!)
      .where((t) => t.length >= 2)
      .toList();
}

/// Purpose: Score how well a result name answers the query.
/// Inputs: `query` — what the user typed; `candidate` — a result name.
/// Returns: The fraction of query tokens present in the candidate, 0.0 to 1.0.
/// Side effects: None.
/// Notes: Returns 0.0 for an empty query so callers do not divide by zero.
double relevanceScore(String query, String candidate) {
  final queryTokens = tokenize(query);
  if (queryTokens.isEmpty) return 0;
  final candidateTokens = tokenize(candidate).toSet();
  final hits = queryTokens.where(candidateTokens.contains).length;
  return hits / queryTokens.length;
}

/// Purpose: Gate out results that do not actually answer the query.
/// Inputs: `query`, `candidate`, and an optional `threshold`.
/// Returns: `true` when the candidate is relevant enough to show.
/// Side effects: None.
/// Notes: phonedb answers an unknown model with a loose full-text match — a
/// search for `Galaxy Z Fold8`, which it does not carry, returns 120 unrelated
/// Galaxy phones. Without this gate those would be shown as if they were hits.
bool isRelevant(String query, String candidate, {double threshold = 1.0}) {
  return relevanceScore(query, candidate) >= threshold;
}

// ──── Values ────

/// Purpose: Read a single storage or memory capacity out of a spec string.
/// Inputs: `raw` — text such as `12 GB , LPDDR5x` or `256 GB UFS 4.0 Flash`.
/// Returns: A normalised `"<value> <unit>"` string, or null.
/// Side effects: None.
/// Notes: Accepts the binary units phonedb reports (`GiB`, `TiB`) and
/// normalises them to the decimal spelling the app stores everywhere else.
String? parseCapacity(String? raw) {
  if (raw == null) return null;
  final match = RegExp(
    r'(\d+(?:\.\d+)?)\s*(TiB|GiB|MiB|TB|GB|MB)',
    caseSensitive: false,
  ).firstMatch(raw);
  if (match == null) return null;
  final unit = match.group(2)!.toUpperCase().replaceAll('I', '');
  return '${match.group(1)} $unit';
}

/// Purpose: Split a combined storage-and-RAM string into its two capacities.
/// Inputs: `raw` — text such as `256GB 12GB RAM` or `8GB RAM`.
/// Returns: A `(ram, storage)` pair; either side may be null.
/// Side effects: None.
/// Notes: Only the first comma-separated variant is read, because these
/// sources list every SKU and the app records a single configuration.
(String? ram, String? storage) parseMemory(String? raw) {
  if (raw == null) return (null, null);
  final segment = raw.split(',').first.trim();

  final full = RegExp(
    r'(\d+)\s*(TB|GB)\s+(\d+)\s*GB\s*RAM',
    caseSensitive: false,
  ).firstMatch(segment);
  if (full != null) {
    return (
      '${full.group(3)} GB',
      '${full.group(1)} ${full.group(2)!.toUpperCase()}',
    );
  }

  final ramOnly = RegExp(
    r'(\d+)\s*(GB|MB)\s*RAM',
    caseSensitive: false,
  ).firstMatch(raw);
  if (ramOnly != null) {
    return ('${ramOnly.group(1)} ${ramOnly.group(2)!.toUpperCase()}', null);
  }

  return (null, null);
}

/// Purpose: Read a screen diagonal expressed in inches.
/// Inputs: `raw` — text such as `7.60 inch 4:3, 2448 x 1848 pixel` or `6.80"`.
/// Returns: The diagonal formatted as `7.60"`, or null.
/// Side effects: None.
/// Notes: None.
String? parseScreenSize(String? raw) {
  if (raw == null) return null;
  final match = RegExp(
    r'([\d.]+)\s*(?:inches|inch|")',
    caseSensitive: false,
  ).firstMatch(raw);
  return match != null ? '${match.group(1)}"' : null;
}

/// Purpose: Read a screen diagonal expressed in millimetres.
/// Inputs: `raw` — text such as `159.3 mm`.
/// Returns: The diagonal converted to inches and formatted as `6.27"`.
/// Side effects: None.
/// Notes: phonedb reports the diagonal in millimetres only, so this is the
/// only way to get a screen size out of that source.
String? parseScreenSizeMm(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'([\d.]+)\s*mm', caseSensitive: false).firstMatch(raw);
  if (match == null) return null;
  final mm = double.tryParse(match.group(1)!);
  if (mm == null || mm <= 0) return null;
  return '${(mm / 25.4).toStringAsFixed(2)}"';
}

/// Purpose: Read a pixel resolution.
/// Inputs: `raw` — text such as `2448 x 1848 pixel` or `1080x2340`.
/// Returns: A `(width, height)` pair, or `(null, null)`.
/// Side effects: None.
/// Notes: Prefers a figure followed by `pixel` when one is present, so a
/// leading aspect ratio or refresh rate cannot be mistaken for a resolution.
(int?, int?) parseResolution(String? raw) {
  if (raw == null) return (null, null);
  final labelled = RegExp(
    r'(\d{3,5})\s*x\s*(\d{3,5})\s*pixel',
    caseSensitive: false,
  ).firstMatch(raw);
  final match =
      labelled ??
      RegExp(
        r'(\d{3,5})\s*x\s*(\d{3,5})',
        caseSensitive: false,
      ).firstMatch(raw);
  if (match == null) return (null, null);
  return (int.parse(match.group(1)!), int.parse(match.group(2)!));
}

/// Purpose: Read a battery capacity in mAh or Wh.
/// Inputs: `raw` — text such as `4800 mAh Lithium-Ion, ...` or `100 Wh`.
/// Returns: A normalised `"4800 mAh"` / `"100 Wh"` string, or null.
/// Side effects: None.
/// Notes: None.
String? parseBattery(String? raw) {
  if (raw == null) return null;
  final mah = RegExp(r'(\d+)\s*mAh', caseSensitive: false).firstMatch(raw);
  if (mah != null) return '${mah.group(1)} mAh';
  final wh = RegExp(r'([\d.]+)\s*Wh', caseSensitive: false).firstMatch(raw);
  if (wh != null) return '${wh.group(1)} Wh';
  return null;
}

/// Purpose: Map an English month name or abbreviation to its number.
/// Inputs: `m` — a month name such as `September` or `Sep`.
/// Returns: 1-12, or null when unrecognised.
/// Side effects: None.
/// Notes: Abbreviations are needed for phonedb, which writes `2026 Mar 12`.
int? parseMonth(String m) {
  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final key = m.trim().toLowerCase();
  if (key.length < 3) return null;
  return months[key.substring(0, 3)];
}

/// Purpose: Read a release date written year-first with a month name.
/// Inputs: `raw` — text such as `2026 Mar 12`, `Released 2024, September 20`.
/// Returns: The parsed date, or null.
/// Side effects: None.
/// Notes: Falls back to the first of the month when no day is present.
DateTime? parseReleaseDate(String? raw) {
  if (raw == null) return null;
  final full = RegExp(r'(\d{4}),?\s+([A-Za-z]+)\s+(\d{1,2})').firstMatch(raw);
  if (full != null) {
    final month = parseMonth(full.group(2)!);
    final day = int.parse(full.group(3)!);
    if (month != null && day >= 1 && day <= 31) {
      return DateTime(int.parse(full.group(1)!), month, day);
    }
  }
  final monthOnly = RegExp(r'(\d{4}),?\s+([A-Za-z]+)').firstMatch(raw);
  if (monthOnly != null) {
    final month = parseMonth(monthOnly.group(2)!);
    if (month != null) return DateTime(int.parse(monthOnly.group(1)!), month);
  }
  return null;
}

/// Purpose: Read a release date written as a US numeric date.
/// Inputs: `raw` — text such as `07/22/2026`.
/// Returns: The parsed date, or null.
/// Side effects: None.
/// Notes: Notebookcheck writes `Released` in MM/DD/YYYY. The month and day are
/// range-checked so a DD/MM/YYYY page cannot silently yield a wrong date.
DateTime? parseUsDate(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(raw);
  if (match == null) return null;
  final month = int.parse(match.group(1)!);
  final day = int.parse(match.group(2)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(int.parse(match.group(3)!), month, day);
}

/// Purpose: Take the leading component of a comma-separated spec string.
/// Inputs: `raw` — text such as `Qualcomm Snapdragon 8 Elite Gen 5 8c/8t, 2 x 4.7 GHz ...`.
/// Returns: The leading component with any trailing core/thread count removed.
/// Side effects: None.
/// Notes: Both sources append clock and core detail after the chip name; the
/// app stores those in dedicated `CpuInfo` fields, not in the model string.
String? parseChipName(String? raw) {
  if (raw == null) return null;
  var name = raw.split(',').first.trim();
  name = name.replaceAll(
    RegExp(r'\s+\d+c\s*/\s*\d+t\s*$', caseSensitive: false),
    '',
  );
  name = name.replaceAll(RegExp(r'\s+\(\s*\)\s*$'), '');
  return name.isEmpty ? null : name;
}

/// Purpose: Decide whether an image URL is a device photo rather than an advert.
/// Inputs: `url` — an absolute or protocol-relative image URL.
/// Returns: `true` when the URL looks like genuine device imagery.
/// Side effects: None.
/// Notes: Rejection wins over acceptance so an advert served with a `.jpg`
/// extension is still filtered out.
bool isLikelyDeviceImage(String url) {
  final lower = url.toLowerCase();
  const rejects = [
    'amazon',
    'amzn',
    'affiliate',
    'banner',
    'advert',
    '/ads/',
    '/ad/',
    'tracking',
    'click.',
    'doubleclick',
    'googlesyndication',
    'adsbygoogle',
  ];
  if (rejects.any(lower.contains)) return false;
  return RegExp(r'\.(jpe?g|png|webp|avif)(\?|$)').hasMatch(lower);
}

// ──── Source-specific page recognition ────

/// Purpose: Confirm a response really is Notebookcheck's device search page.
/// Inputs: `html` — the full response body.
/// Returns: `true` when the search page rendered, with or without matches.
/// Side effects: None.
/// Notes: A query with no matches renders the search page **without** a
/// results table. Without this check the caller cannot tell that apart from a
/// layout change, and would cry wolf on every unknown device — the same
/// conflation of "no results" with "broken" that hid the GSMArena breakage.
bool isNotebookcheckSearchPage(String html) {
  return html.contains('Laptop-Search');
}

/// Purpose: Confirm a response really is phonedb's search-results page.
/// Inputs: `html` — the full response body.
/// Returns: `true` when the results page rendered, with or without matches.
/// Side effects: None.
/// Notes: phonedb states its match count even when that count is zero, so the
/// phrase is a reliable marker that the page itself is intact.
bool isPhonedbResultsPage(String html) {
  return RegExp(r'\d+\s+results?\s+match', caseSensitive: false).hasMatch(html);
}

// ──── Source-specific spec blocks ────

/// Purpose: Read the label/value spec table from a Notebookcheck device page.
/// Inputs: `html` — the full detail-page markup.
/// Returns: A map of spec label to visible value, empty when nothing matched.
/// Side effects: None.
/// Notes: Splits on the literal label div and keeps everything up to the next
/// entry, rather than matching closing tags. Two shapes have to work: most
/// values sit in a `div.specs_details` that nests a `div.specs_indicator`
/// whose closing tags would truncate `Memory` and `Storage` mid-value, while
/// `Released` has no wrapper at all and follows the label directly. Stripping
/// tags across the whole span handles both. An empty map means the markup
/// changed and the caller should report that, not treat it as a device with
/// no specs.
Map<String, String> parseNotebookcheckSpecs(String html) {
  const labelOpen = '<div class="specs">';
  const labelClose = '</div>';
  const elementOpen = '<div class="specs_element">';
  final out = <String, String>{};

  final chunks = html.split(labelOpen);
  for (var i = 1; i < chunks.length; i++) {
    final chunk = chunks[i];
    final labelEnd = chunk.indexOf(labelClose);
    if (labelEnd < 0) continue;
    final label = stripHtml(chunk.substring(0, labelEnd));
    if (label.isEmpty) continue;

    var rest = chunk.substring(labelEnd + labelClose.length);
    final stop = rest.indexOf(elementOpen);
    if (stop >= 0) rest = rest.substring(0, stop);
    if (rest.length > 4000) rest = rest.substring(0, 4000);

    final value = stripHtml(rest);
    if (value.isNotEmpty) out.putIfAbsent(label, () => value);
  }
  return out;
}

/// Purpose: Read the label/value datasheet rows from a phonedb device page.
/// Inputs: `html` — the full detail-page markup.
/// Returns: A map of datasheet label to visible value, empty when nothing matched.
/// Side effects: None.
/// Notes: phonedb renders each row as `<td><strong>label</strong>…</td><td>value</td>`.
/// The first occurrence of a label wins, because the page repeats some labels
/// in its comparison footer.
Map<String, String> parsePhonedbSpecs(String html) {
  final out = <String, String>{};
  final pattern = RegExp(
    r'<td[^>]*>\s*<strong>([^<]+)</strong>.*?</td>\s*<td[^>]*>(.*?)</td>',
    dotAll: true,
  );
  for (final m in pattern.allMatches(html)) {
    final label = stripHtml(m.group(1)!);
    final value = stripHtml(m.group(2)!);
    if (label.isEmpty || value.isEmpty) continue;
    out.putIfAbsent(label, () => value);
  }
  return out;
}

// ──── Apple Support ────

/// One product link on an Apple Support documentation index page.
typedef AppleDocsEntry = ({String name, String url, String? thumbnailUrl});

/// Purpose: Read the product links off an Apple Support docs index page.
/// Inputs: `html` — a page such as `support.apple.com/en-us/docs/iphone`;
/// `family` — the path segment after `docs/` (`iphone`, `mac`, ...).
/// Returns: One entry per product, in page order, without duplicates.
/// Side effects: None.
/// Notes: Each product is an anchor to `docs/FAMILY/ID` (the ID is numeric
/// or, for older products, alphanumeric such as `pl293`) with class
/// `product`, its name in `<div class="product-name">` and a 120 px
/// thumbnail; the thumbnail URL is widened to 240 px.
List<AppleDocsEntry> parseAppleDocsIndex(String html, String family) {
  // Attributes are matched inside each tag, so their order does not matter.
  final anchor = RegExp(r'<a\b([^>]*)>(.*?)</a>', dotAll: true);
  final hrefPattern = RegExp(
    'href="(https://support\\.apple\\.com/[a-z-]+/docs/'
    '${RegExp.escape(family)}/[A-Za-z0-9]+)"',
  );
  final classPattern = RegExp(r'class="product\b');
  final seen = <String>{};
  final entries = <AppleDocsEntry>[];
  for (final m in anchor.allMatches(html)) {
    final attributes = m.group(1)!;
    if (!classPattern.hasMatch(attributes)) continue;
    final url = hrefPattern.firstMatch(attributes)?.group(1);
    if (url == null || !seen.add(url)) continue;
    final body = m.group(2)!;
    final name = RegExp(
      r'<div class="product-name">(.*?)</div>',
      dotAll: true,
    ).firstMatch(body)?.group(1);
    if (name == null) continue;
    final thumb = RegExp(r'<img[^>]*src="([^"]+)"').firstMatch(body)?.group(1);
    entries.add((
      name: stripHtml(name),
      url: url,
      thumbnailUrl: thumb == null
          ? null
          : decodeEntities(thumb).replaceFirst('size=120x120', 'size=240x240'),
    ));
  }
  return entries;
}

/// Purpose: Recognise an Apple Support docs index page.
/// Inputs: `html`.
/// Returns: `true` when the page carries the product grid.
/// Side effects: None.
/// Notes: Separates "no matching product" from a changed layout.
bool isAppleDocsIndexPage(String html) => html.contains('class="product-name"');

/// Purpose: Find the "Tech Specs" link on an Apple product docs page.
/// Inputs: `html` — a page such as `support.apple.com/en-us/docs/iphone/301045`.
/// Returns: The absolute tech-specs URL, or null.
/// Side effects: None.
/// Notes: The link is marked `data-ss-analytics-link-text="tech specs"`.
String? findAppleTechSpecsLink(String html) {
  for (final m in RegExp(r'<a\b[^>]*>', dotAll: true).allMatches(html)) {
    final tag = m.group(0)!;
    if (!tag.toLowerCase().contains('link-text="tech specs"')) continue;
    final href = RegExp(r'href="([^"]+)"').firstMatch(tag)?.group(1);
    if (href == null) continue;
    return href.startsWith('/') ? 'https://support.apple.com$href' : href;
  }
  return null;
}

/// The parts of an Apple tech-specs page the app reads.
typedef AppleTechSpecs = ({
  String? title,
  String? imageUrl,
  int? yearIntroduced,
  Map<String, List<String>> sections,
});

/// Purpose: Split an Apple tech-specs page into titled sections.
/// Inputs: `html` — a page such as `support.apple.com/en-us/121029`.
/// Returns: The page title (without " - Tech Specs"), the product render,
/// the introduction year, and each `<h3>` heading mapped to the text of its
/// list items and paragraphs, in order.
/// Side effects: None.
/// Notes: Headings drop footnote markers (`Capacity<sup>1</sup>` becomes
/// `Capacity`). The render is the first `cdsassets.apple.com` image, which
/// Apple ships on a transparent or white background.
AppleTechSpecs parseAppleTechSpecs(String html) {
  final title = RegExp(
    r'<h1[^>]*>(.*?)</h1>',
    dotAll: true,
  ).firstMatch(html)?.group(1);
  final image = RegExp(
    r'<img[^>]*src="(https://cdsassets\.apple\.com/[^"]+\.(?:png|jpg|jpeg))"',
    caseSensitive: false,
  ).firstMatch(html)?.group(1);
  final year = RegExp(
    r'Year introduced:\s*(\d{4})',
  ).firstMatch(stripHtml(html))?.group(1);

  final sections = <String, List<String>>{};
  final parts = html.split(RegExp(r'<h3\b'));
  for (final part in parts.skip(1)) {
    final end = part.indexOf('</h3>');
    if (end < 0) continue;
    final heading = stripHtml(
      part
          .substring(part.indexOf('>') + 1, end)
          .replaceAll(RegExp(r'<sup>.*?</sup>', dotAll: true), ''),
    );
    if (heading.isEmpty) continue;
    var body = part.substring(end + 5);
    final stop = body.indexOf('<div class="gb-group');
    if (stop >= 0) body = body.substring(0, stop);
    final lines = [
      for (final m in RegExp(
        r'<(li|p)\b[^>]*>(.*?)</\1>',
        dotAll: true,
      ).allMatches(body))
        stripHtml(
          m.group(2)!.replaceAll(RegExp(r'<sup>.*?</sup>', dotAll: true), ''),
        ),
    ].where((l) => l.isNotEmpty).toList();
    sections.putIfAbsent(heading, () => lines);
  }
  return (
    title: title == null
        ? null
        : stripHtml(title).replaceFirst(RegExp(r'\s*-\s*Tech Specs$'), ''),
    imageUrl: image,
    yearIntroduced: year == null ? null : int.parse(year),
    sections: sections,
  );
}

/// Purpose: Pick the lines of the first section whose heading starts with
/// one of the given names.
/// Inputs: `specs`; `names` in priority order, compared case-insensitively.
/// Returns: The section's lines, or an empty list.
/// Side effects: None.
/// Notes: Apple words headings slightly differently across product lines
/// ("Battery and Power" on a Mac, "Power and Battery" on an iPhone).
List<String> appleSection(AppleTechSpecs specs, List<String> names) {
  for (final name in names) {
    final lower = name.toLowerCase();
    for (final entry in specs.sections.entries) {
      if (entry.key.toLowerCase().startsWith(lower)) return entry.value;
    }
  }
  return const [];
}

// ──── Wikipedia ────

/// Purpose: Pull the parameters of a page's first infobox out of wikitext.
/// Inputs: `wikitext` — the lead section of an article.
/// Returns: Lowercased parameter names mapped to their raw values, or null
/// when the page has no infobox.
/// Side effects: None.
/// Notes: Parameters are split on `|` at nesting depth zero, counting both
/// `{{ }}` templates and `[[ ]]` links, so a piped link or a list template
/// inside a value does not end it early.
Map<String, String>? extractWikiInfobox(String wikitext) {
  final start = wikitext.toLowerCase().indexOf('{{infobox');
  if (start < 0) return null;
  var depth = 0;
  var end = -1;
  for (var i = start; i < wikitext.length - 1; i++) {
    final two = wikitext.substring(i, i + 2);
    if (two == '{{') {
      depth++;
      i++;
    } else if (two == '}}') {
      depth--;
      i++;
      if (depth == 0) {
        end = i - 1;
        break;
      }
    }
  }
  if (end < 0) return null;
  final body = wikitext.substring(start + 2, end);

  final parts = <String>[];
  var braces = 0, brackets = 0, from = 0;
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    final next = i + 1 < body.length ? body[i + 1] : '';
    if (c == '{' && next == '{') {
      braces++;
      i++;
    } else if (c == '}' && next == '}') {
      braces--;
      i++;
    } else if (c == '[' && next == '[') {
      brackets++;
      i++;
    } else if (c == ']' && next == ']') {
      brackets--;
      i++;
    } else if (c == '|' && braces == 0 && brackets == 0) {
      parts.add(body.substring(from, i));
      from = i + 1;
    }
  }
  parts.add(body.substring(from));

  final params = <String, String>{};
  for (final part in parts.skip(1)) {
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    final key = part.substring(0, eq).trim().toLowerCase();
    final value = part.substring(eq + 1).trim();
    if (key.isEmpty || value.isEmpty) continue;
    params.putIfAbsent(key, () => value);
  }
  return params;
}

/// Purpose: Turn a raw infobox value into its plain-text items.
/// Inputs: `raw` — wikitext such as `{{ubl|'''LCD:''' 16 GB [[LPDDR5]]|...}}`.
/// Returns: The visible items in order (one per list entry or line), with
/// references, comments, markup and variant labels such as `LCD:` removed.
/// Side effects: None.
/// Notes: Templates are resolved innermost-first. List templates keep their
/// items; `convert` keeps its value and unit; date templates become
/// `YYYY-MM-DD`; `vgrelease` keeps its dates; anything else (prices, icons,
/// "current version" helpers) is dropped rather than guessed at.
List<String> wikiValueItems(String raw) {
  var s = raw
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'<ref[^>/]*/>', caseSensitive: false), '')
      .replaceAll(
        RegExp(r'<ref[^>]*>.*?</ref>', dotAll: true, caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\[\[(?:File|Image):[^\]]*\]\]'), '')
      // Links first: a piped link inside a template would otherwise be cut
      // at its pipe when the template's arguments are split.
      .replaceAllMapped(
        RegExp(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]'),
        (m) => m.group(1)!,
      );

  const lists = {
    'ubl',
    'ubli',
    'unbulleted list',
    'plainlist',
    'plain list',
    'flatlist',
    'hlist',
    'bulleted list',
    'ublist',
  };
  const passThrough = {'nowrap', 'nobr', 'small', 'nowrap begin', 'abbr'};
  final template = RegExp(r'\{\{([^{}]*)\}\}');
  for (var guard = 0; guard < 30 && s.contains('{{'); guard++) {
    final next = s.replaceAllMapped(template, (m) {
      final args = m.group(1)!.split('|');
      final name = args.first.trim().toLowerCase();
      final positional = [
        for (final a in args.skip(1))
          if (!RegExp(r'^\s*[a-z_ -]+\s*=').hasMatch(a)) a.trim(),
      ];
      if (lists.contains(name)) return '\n${positional.join('\n')}\n';
      if (passThrough.contains(name)) {
        return positional.isEmpty ? '' : positional.first;
      }
      if (name == 'nbsp' || name == '!') return ' ';
      if (name == 'br' || name == 'break') return '\n';
      if (name == 'convert' || name == 'cvt') {
        return positional.length >= 2
            ? '${positional[0]} ${positional[1]}'
            : '';
      }
      if (name.startsWith('start date') ||
          name.startsWith('release date') ||
          name == 'dts') {
        final nums = positional.map(int.tryParse).whereType<int>().toList();
        if (nums.isEmpty) return '';
        final y = nums[0];
        final mo = nums.length > 1 ? nums[1] : 1;
        final d = nums.length > 2 ? nums[2] : 1;
        return '$y-${'$mo'.padLeft(2, '0')}-${'$d'.padLeft(2, '0')}';
      }
      if (name == 'vgrelease' || name == 'video game release') {
        return '\n${[for (var i = 1; i < positional.length; i += 2) positional[i]].join('\n')}\n';
      }
      return '';
    });
    if (next == s) break;
    s = next;
  }

  s = s
      .replaceAllMapped(
        RegExp(r'\[https?://\S+\s+([^\]]*)\]'),
        (m) => m.group(1)!,
      )
      .replaceAll(RegExp(r"'{2,}"), '')
      // Thousands separators, so `4,400 mAh` is not read as `400 mAh`.
      .replaceAllMapped(RegExp(r'(\d),(\d{3})\b'), (m) => '${m[1]}${m[2]}')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

  final items = <String>[];
  for (var line in s.split('\n')) {
    line = stripHtml(line)
        .replaceFirst(RegExp(r'^[*#:;\s]+'), '')
        .replaceFirst(RegExp(r'^[A-Za-z0-9+ ]{1,24}:\s+'), '')
        .trim();
    if (line.isNotEmpty) items.add(line);
  }
  return items;
}

/// Purpose: Read the first value of the first present infobox parameter.
/// Inputs: `infobox`; `keys` in priority order.
/// Returns: The first plain-text item, or null.
/// Side effects: None.
/// Notes: Infoboxes name the same thing differently (`soc`,
/// `system_on_chip`, `cpu`), so callers pass every spelling they accept.
String? wikiField(Map<String, String> infobox, List<String> keys) {
  for (final key in keys) {
    final raw = infobox[key];
    if (raw == null) continue;
    final items = wikiValueItems(raw);
    if (items.isNotEmpty) return items.first;
  }
  return null;
}

/// Purpose: Read every item of the first present infobox parameter.
/// Inputs: `infobox`; `keys` in priority order.
/// Returns: The items joined with `, `, or null.
/// Side effects: None.
/// Notes: For values whose useful part is not the first item — a display
/// listed as panel type, then size, then resolution.
String? wikiFieldText(Map<String, String> infobox, List<String> keys) {
  for (final key in keys) {
    final raw = infobox[key];
    if (raw == null) continue;
    final items = wikiValueItems(raw);
    if (items.isNotEmpty) return items.join(', ');
  }
  return null;
}

/// Purpose: Read a screen diagonal in inches from infobox text.
/// Inputs: `raw` — text such as `6.1 in`, `7.9-in LCD` or `7", 1280×800`.
/// Returns: The diagonal formatted as `7.9"`, or null.
/// Side effects: None.
/// Notes: Wikipedia abbreviates the unit (`in`), which [parseScreenSize]
/// does not accept because `in` is an ordinary word on other sources.
String? parseWikiScreenSize(String? raw) {
  if (raw == null) return null;
  final match = RegExp(
    r'(\d+(?:\.\d+)?)\s*-?\s*(?:inches|inch|in\b|")',
    caseSensitive: false,
  ).firstMatch(raw);
  return match == null ? null : '${match.group(1)}"';
}

/// Purpose: Reduce an infobox maker field to a brand name.
/// Inputs: `raw` — text such as `Valve Corporation` or `Samsung Electronics`.
/// Returns: The first maker with corporate suffixes removed, or null.
/// Side effects: None.
/// Notes: None.
String? wikiBrand(String? raw) {
  if (raw == null) return null;
  // Split on "/" and on commas that separate makers, not on the comma
  // inside "Co., Ltd.".
  final first = raw
      .split(RegExp(r'/|,(?!\s*Ltd)', caseSensitive: false))
      .first
      .trim();
  final suffix = RegExp(
    r'\s+(Corporation|Corp\.?|Inc\.?|Electronics|Co\.?,?\s*Ltd\.?|Co\.?|'
    r'Ltd\.?|Limited|Company|Computer|Technology|Group|Holdings)$',
    caseSensitive: false,
  );
  // Suffixes stack ("Samsung Electronics Co., Ltd."), so strip repeatedly.
  var brand = first;
  for (var previous = ''; previous != brand;) {
    previous = brand;
    brand = brand.replaceFirst(suffix, '').trim();
  }
  return brand.isEmpty ? null : brand;
}

/// Purpose: Tell whether an infobox describes a device rather than a
/// company, person or product line.
/// Inputs: `infobox`.
/// Returns: True when it carries at least one hardware parameter.
/// Side effects: None.
/// Notes: A redirect such as "Framework Laptop 13" lands on the company
/// article, whose `Infobox company` must not be read as specs.
bool isWikiDeviceInfobox(Map<String, String> infobox) => const [
  'cpu',
  'soc',
  'system_on_chip',
  'processor',
  'memory',
  'storage',
  'display',
].any(infobox.containsKey);

/// Purpose: Read a release date from infobox text.
/// Inputs: `raw` — text such as `2024-09-20`, `February 25, 2022` or
/// `25 February 2022`.
/// Returns: The first date found, or null.
/// Side effects: None.
/// Notes: A bare year is ignored; a year alone is not a release date.
DateTime? parseWikiDate(String? raw) {
  if (raw == null) return null;
  final iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (iso != null) {
    final month = int.parse(iso.group(2)!);
    final day = int.parse(iso.group(3)!);
    // DateTime would roll an impossible date over into the next month.
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return DateTime(int.parse(iso.group(1)!), month, day);
    }
    return null;
  }
  final mdy = RegExp(r'([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})').firstMatch(raw);
  if (mdy != null) {
    final month = parseMonth(mdy.group(1)!);
    if (month != null) {
      return DateTime(
        int.parse(mdy.group(3)!),
        month,
        int.parse(mdy.group(2)!),
      );
    }
  }
  final dmy = RegExp(r'(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})').firstMatch(raw);
  if (dmy != null) {
    final month = parseMonth(dmy.group(2)!);
    if (month != null) {
      return DateTime(
        int.parse(dmy.group(3)!),
        month,
        int.parse(dmy.group(1)!),
      );
    }
  }
  final my = RegExp(r'([A-Za-z]+)\s+(\d{4})').firstMatch(raw);
  if (my != null) {
    final month = parseMonth(my.group(1)!);
    if (month != null) return DateTime(int.parse(my.group(2)!), month);
  }
  return null;
}
