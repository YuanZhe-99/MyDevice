import 'dart:io';
import '../models/network.dart';
import '../../devices/models/device.dart';

/// Pure CSV parser and assignment mapper for Tailscale admin exports.
class TailscaleCsv {
  /// Purpose: Suggest inventory matches before user review.
  /// Inputs: Row, inventory and target-network assignments.
  /// Returns: Match reason and candidate IDs.
  /// Side effects: None.
  /// Notes: Only exact or separator-normalized equality qualifies; ambiguity stays visible.
  static ({String reason, List<String> ids}) match(
    Map<String, String> row,
    List<Device> devices,
    List<NetworkDevice> assignments,
  ) {
    final active = devices.where((d) => d.isInService).toList();
    final node = assignments
        .where((a) => a.tailscale['Device ID'] == row['Device ID'])
        .map((a) => a.deviceId)
        .toSet();
    if (node.isNotEmpty) {
      return (
        reason: 'id',
        ids: active.where((d) => node.contains(d.id)).map((d) => d.id).toList(),
      );
    }
    final name = row['Device name']!.trim().toLowerCase();
    final exact = active
        .where(
          (d) =>
              d.name.trim().toLowerCase() == name ||
              assignments.any(
                (a) =>
                    a.deviceId == d.id &&
                    a.hostname?.trim().toLowerCase() == name,
              ),
        )
        .map((d) => d.id)
        .toList();
    if (exact.isNotEmpty) return (reason: 'name', ids: exact);
    final normalized = name.replaceAll(RegExp(r'[\s_.-]+'), '');
    final ids = active
        .where(
          (d) =>
              d.name.trim().toLowerCase().replaceAll(RegExp(r'[\s_.-]+'), '') ==
                  normalized ||
              assignments.any(
                (a) =>
                    a.deviceId == d.id &&
                    a.hostname?.trim().toLowerCase().replaceAll(
                          RegExp(r'[\s_.-]+'),
                          '',
                        ) ==
                        normalized,
              ),
        )
        .map((d) => d.id)
        .toList();
    return (reason: ids.isEmpty ? 'none' : 'normalized', ids: ids);
  }

  /// Purpose: Parse quoted CSV into rows keyed by original column name.
  /// Inputs: UTF-8 decoded export text.
  /// Returns: Rows preserving blank and unknown columns.
  /// Side effects: None.
  /// Notes: Rejects malformed quoting, duplicate headers/IDs and wrong row widths.
  static List<Map<String, String>> parse(String text) {
    text = text.replaceFirst(RegExp(r'^\uFEFF'), '');
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    var closed = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        if (field.isNotEmpty || closed) {
          throw FormatException('Unexpected quote at character ${i + 1}');
        }
        quoted = true;
      } else if (c == ',' || c == '\n' || c == '\r') {
        row.add(field.toString());
        field = StringBuffer();
        closed = false;
        if (c != ',') {
          if (row.any((v) => v.isNotEmpty)) rows.add(row);
          row = [];
          if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        }
      } else {
        if (closed) {
          throw FormatException(
            'Text after closing quote at character ${i + 1}',
          );
        }
        field.write(c);
      }
    }
    if (quoted) throw const FormatException('Unclosed quoted field');
    if (field.isNotEmpty || row.isNotEmpty || closed) {
      row.add(field.toString());
      rows.add(row);
    }
    if (rows.isEmpty) throw const FormatException('Empty CSV');
    final headers = rows.removeAt(0).map((v) => v.trim()).toList();
    if (headers.toSet().length != headers.length ||
        headers.any((v) => v.isEmpty)) {
      throw const FormatException('Duplicate or empty column name');
    }
    for (final key in ['Device name', 'Device ID', 'Tailscale IPs']) {
      if (!headers.contains(key)) throw FormatException('Missing column: $key');
    }
    final result = <Map<String, String>>[];
    final ids = <String>{};
    for (var i = 0; i < rows.length; i++) {
      final values = rows[i];
      if (values.length != headers.length) {
        throw FormatException(
          'Row ${i + 2}: expected ${headers.length} columns, got ${values.length}',
        );
      }
      final record = {
        for (var c = 0; c < headers.length; c++) headers[c]: values[c],
      };
      final id = record['Device ID']!.trim();
      if (id.isEmpty || record['Device name']!.trim().isEmpty || !ids.add(id)) {
        throw FormatException(
          'Row ${i + 2}: empty name/ID or duplicate Device ID',
        );
      }
      for (final key in ['Created', 'Last seen', 'Key expiry']) {
        final value = record[key]?.trim() ?? '';
        if (value.isNotEmpty &&
            (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value) ||
                DateTime.tryParse(value) == null)) {
          throw FormatException('Row ${i + 2}: invalid timestamp in $key');
        }
      }
      for (final key in [
        'Exit node',
        'Subnet router',
        'Ephemeral',
        'Shared in',
        'Tailscale SSH',
        'Funnel',
      ]) {
        final value = record[key]?.trim().toLowerCase() ?? '';
        if (value.isNotEmpty && value != 'true' && value != 'false') {
          throw FormatException('Row ${i + 2}: invalid boolean in $key');
        }
      }
      for (final ip in addresses(record)) {
        if (InternetAddress.tryParse(ip) == null) {
          throw FormatException('Row ${i + 2}: invalid IP address $ip');
        }
      }
      result.add(record);
    }
    return result;
  }

  /// Purpose: Split addresses only after parsing the quoted CSV cell.
  /// Inputs: One record.
  /// Returns: Ordered unique IPv4/IPv6 addresses.
  /// Side effects: None.
  /// Notes: Empty address lists are valid.
  static List<String> addresses(Map<String, String> row) =>
      (row['Tailscale IPs'] ?? '')
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList();

  /// Purpose: Map a row to a network membership preserving manual/future fields.
  /// Inputs: Row, target network/device, optional existing assignment.
  /// Returns: Updated assignment.
  /// Side effects: None.
  /// Notes: Blank Exit node retains existing value; raw CSV retains the blank.
  static NetworkDevice assignment(
    Map<String, String> row,
    String networkId,
    String deviceId, {
    NetworkDevice? existing,
    Set<String>? selectedColumns,
  }) {
    final ips = addresses(row);
    final selected = selectedColumns ?? row.keys.toSet();
    final imported = {
      for (final e in row.entries)
        if (selected.contains(e.key) || e.key == 'Device ID') e.key: e.value,
    };
    final exit = selected.contains('Exit node')
        ? row['Exit node']?.trim().toLowerCase()
        : null;
    return (existing ?? NetworkDevice(networkId: networkId, deviceId: deviceId))
        .copyWith(
          addressMode: selected.contains('Tailscale IPs')
              ? AddressMode.static_
              : null,
          ipAddress: selected.contains('Tailscale IPs')
              ? ips.where((v) => !v.contains(':')).firstOrNull ??
                    ips.firstOrNull
              : null,
          clearIpAddress: selected.contains('Tailscale IPs') && ips.isEmpty,
          ipAddresses: selected.contains('Tailscale IPs') ? ips : null,
          hostname: selected.contains('Device name')
              ? row['Device name']!.trim()
              : null,
          isExitNode: exit == 'true'
              ? true
              : exit == 'false'
              ? false
              : null,
          tailscale: {...?existing?.tailscale, ...imported},
        );
  }
}
