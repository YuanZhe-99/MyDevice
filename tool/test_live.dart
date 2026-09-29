// End-to-end run of the online device search against the live sources.
//
// Run with:  dart run tool/test_live.dart [query ...]
//
// Not part of `flutter test` or CI (it makes real network requests). For
// each query it prints every result with its source, then fetches the
// detail page of the first result from each source and prints the fields
// the editor would fill in. `tool/check_sources.dart` is the quicker
// per-source health check.

import 'package:my_device/features/devices/services/device_search_service.dart';

const _defaultQueries = [
  'MacBook Pro 14 M4 Pro',
  'iPhone 16',
  'ThinkPad X1 Carbon',
  'Galaxy S24 Ultra',
  'Steam Deck',
];

/// Purpose: Search each query and fetch one detail page per source.
/// Inputs: Command-line `args` — queries to run instead of the defaults.
/// Returns: None.
/// Side effects: Issues HTTP requests; prints to stdout.
/// Notes: Primarily intended for local validation or one-off tooling.
Future<void> main(List<String> args) async {
  print('Sources: ${DeviceSearchService.sourceNames.join(', ')}');
  for (final query in args.isEmpty ? _defaultQueries : args) {
    print('\n=== $query ===');
    final response = await DeviceSearchService.search(query);
    for (final o in response.outcomes) {
      print('  ${o.source}: ${o.status.name}, ${o.resultCount} result(s)');
    }
    final detailed = <String>{};
    for (final r in response.results) {
      print('  [${r.source}] ${r.name}  ${r.sourceUrl}');
      if (!detailed.add(r.source)) continue;
      final d = await DeviceSearchService.fetchDetail(r);
      print('      detailFetched=${d.detailFetched}');
      for (final (label, value) in [
        ('brand/model', '${d.brand} / ${d.model}'),
        ('chip', d.chipset),
        ('gpu', d.gpuName),
        ('ram', d.ram),
        ('storage', d.storage),
        ('screen', d.screenSize),
        (
          'resolution',
          d.screenResolutionW == null
              ? null
              : '${d.screenResolutionW}x${d.screenResolutionH}',
        ),
        ('battery', d.battery),
        ('os', d.os),
        ('released', d.releaseDate?.toIso8601String().split('T').first),
        ('image', d.imageUrl),
      ]) {
        if (value != null) print('      $label: $value');
      }
    }
  }
}
