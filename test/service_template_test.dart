import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_template_service.dart';

/// Purpose: Run regression checks for the built-in service-template catalog.
/// Inputs: None.
/// Returns: None.
/// Side effects: Registers and executes Flutter tests.
/// Notes: Covers catalog metadata and conversion of templates into service instances.
void main() {
  final templates = ServiceTemplateService.loadTemplates();

  /// Purpose: Find one built-in template by its stable ID.
  /// Inputs: `id` — the template identifier to look up.
  /// Returns: The matching `ServiceTemplate`.
  /// Side effects: None.
  /// Notes: Throws when the catalog does not contain exactly one matching entry.
  ServiceTemplate template(String id) =>
      templates.singleWhere((entry) => entry.id == id);

  test('catalog IDs are unique and endpoint ranges are valid', () {
    expect(
      templates.map((entry) => entry.id).toSet(),
      hasLength(templates.length),
    );

    for (final entry in templates) {
      for (final endpoint in entry.endpoints) {
        final port = endpoint.port!;
        expect(port, inInclusiveRange(1, 65535), reason: entry.id);
        expect(
          endpoint.portEnd ?? port,
          inInclusiveRange(port, 65535),
          reason: entry.id,
        );
      }
    }
  });

  test(
    'Moonlight template ID remains stable while describing its Sunshine host',
    () {
      final sunshineHost = template('moonlight');

      expect(sunshineHost.name, 'Sunshine');
      expect(
        sunshineHost.endpoints.map((endpoint) => endpoint.port),
        containsAll([47984, 47989, 47990, 48010]),
      );
      final streaming = sunshineHost.endpoints.singleWhere(
        (endpoint) => endpoint.port == 47998,
      );
      expect(streaming.portEnd, 48000);
      expect(streaming.transport, ServiceTransport.udp);
    },
  );

  test('endpoint protocol and runtime defaults match non-web services', () {
    expect(template('opencode').endpoints.single.port, 4096);
    expect(
      template('postgresql').endpoints.single.protocol,
      ServiceProtocol.tcp,
    );
    expect(template('frp').endpoints.single.protocol, ServiceProtocol.tcp);
    expect(
      template('portainer').endpoints.single.protocol,
      ServiceProtocol.https,
    );
    expect(template('ssh').endpoints.single.protocol, ServiceProtocol.ssh);
    expect(template('ssh').runtime, isNull);
    expect(template('rdp').endpoints.single.protocol, ServiceProtocol.tcp);
    expect(template('rdp').endpoints.single.transport, ServiceTransport.tcpUdp);
    expect(template('rdp').runtime, isNull);
    expect(
      template('wireguard').endpoints.single.transport,
      ServiceTransport.udp,
    );
    expect(template('samba').endpoints.single.transport, ServiceTransport.tcp);
    expect(template('nfs').endpoints.single.transport, ServiceTransport.tcpUdp);
  });

  test(
    'game templates use their service transport and required port ranges',
    () {
      expect(
        template('minecraft').endpoints.single.protocol,
        ServiceProtocol.minecraft,
      );
      expect(
        template('palworld').endpoints.single.transport,
        ServiceTransport.udp,
      );
      expect(
        template('factorio').endpoints.single.transport,
        ServiceTransport.udp,
      );
      expect(template('valheim').endpoints.single.portEnd, 2457);
      expect(
        template('valheim').endpoints.single.transport,
        ServiceTransport.udp,
      );
      expect(
        template('minecraft-bedrock').endpoints.single.transport,
        ServiceTransport.udp,
      );
      expect(template('steamcmd').endpoints, isEmpty);
      expect(template('steamcmd').runtime, isNull);
    },
  );

  test('AdGuard setup, web, and DNS endpoints are represented', () {
    final endpoints = template('adguard-home').endpoints;

    expect(
      endpoints.map((endpoint) => endpoint.port),
      containsAll([53, 80, 3000]),
    );
    expect(
      endpoints.singleWhere((endpoint) => endpoint.port == 53).transport,
      ServiceTransport.tcpUdp,
    );
  });

  test(
    'Jellyfin Compose example does not claim an unconfigured HTTPS endpoint',
    () {
      final jellyfin = template('jellyfin');

      expect(jellyfin.endpoints.map((endpoint) => endpoint.port), [8096]);
      expect(jellyfin.dockerCompose, contains('"8096:8096"'));
      expect(jellyfin.dockerCompose, isNot(contains('8920')));
    },
  );

  test('toService copies template fields and creates new endpoint IDs', () {
    final source = template('jellyfin');
    final first = source.toService('device-a');
    final second = source.toService('device-b');

    expect(first.templateId, source.id);
    expect(first.deviceId, 'device-a');
    expect(first.endpoints.single.id, isNot(source.endpoints.single.id));
    expect(first.endpoints.single.id, isNot(second.endpoints.single.id));
    expect(first.endpoints.single.port, source.endpoints.single.port);
    expect(first.dockerCompose, source.dockerCompose);
  });
}
