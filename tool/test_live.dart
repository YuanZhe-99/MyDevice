import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_device/features/devices/services/device_search_service.dart';

void main() async {
  print('=== Search: iPhone 15 Pro ===');
  try {
    final results = await DeviceSearchService.search('iPhone 15 Pro');
    print('Total results: ${results.length}');
    for (final r in results) {
      print('  [${r.source}] ${r.name}');
      if (r.chipset != null) print('    CPU: ${r.chipset}');
      if (r.gpuName != null) print('    GPU: ${r.gpuName}');
      if (r.screenSize != null) print('    Screen: ${r.screenSize}');
      if (r.screenResolutionW != null) print('    Res: ${r.screenResolutionW}x${r.screenResolutionH}');
      print('    URL: ${r.sourceUrl}');
    }
  } catch (e) {
    print('Error: $e');
  }

  print('\n=== Search: ThinkPad X1 Carbon ===');
  try {
    final results = await DeviceSearchService.search('ThinkPad X1 Carbon');
    print('Total results: ${results.length}');
    for (final r in results.take(10)) {
      print('  [${r.source}] ${r.name}');
      if (r.chipset != null) print('    CPU: ${r.chipset}');
      if (r.gpuName != null) print('    GPU: ${r.gpuName}');
      if (r.screenSize != null) print('    Screen: ${r.screenSize}');
      if (r.screenResolutionW != null) print('    Res: ${r.screenResolutionW}x${r.screenResolutionH}');
    }
  } catch (e) {
    print('Error: $e');
  }

  print('\n=== Search: Galaxy S24 Ultra ===');
  try {
    final results = await DeviceSearchService.search('Galaxy S24 Ultra');
    print('Total results: ${results.length}');
    for (final r in results) {
      print('  [${r.source}] ${r.name}');
      if (r.chipset != null) print('    CPU: ${r.chipset}');
      if (r.gpuName != null) print('    GPU: ${r.gpuName}');
      if (r.screenSize != null) print('    Screen: ${r.screenSize}');
    }
  } catch (e) {
    print('Error: $e');
  }

  // Test fetchDetail on a Notebookcheck result
  print('\n=== Fetch Detail: Notebookcheck ===');
  try {
    final results = await DeviceSearchService.search('ThinkPad X1 Carbon');
    final nbResults = results.where((r) => r.source == 'Notebookcheck').toList();
    if (nbResults.isNotEmpty) {
      print('Fetching detail for: ${nbResults[0].name}');
      final detail = await DeviceSearchService.fetchDetail(nbResults[0]);
      print('  Image: ${detail.imageUrl}');
      print('  CPU: ${detail.chipset}');
      print('  GPU: ${detail.gpuName}');
      print('  Screen: ${detail.screenSize}');
      print('  Res: ${detail.screenResolutionW}x${detail.screenResolutionH}');
      print('  detailFetched: ${detail.detailFetched}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
