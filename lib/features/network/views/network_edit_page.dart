import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../models/network.dart';
import '../services/network_storage.dart';

class NetworkEditPage extends StatefulWidget {
  final Network? network;

  const NetworkEditPage({super.key, this.network});

  @override
  State<NetworkEditPage> createState() => _NetworkEditPageState();
}

class _NetworkEditPageState extends State<NetworkEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _subnetCtrl;
  late final TextEditingController _gatewayCtrl;
  late final TextEditingController _dnsCtrl;
  late final TextEditingController _notesCtrl;
  late NetworkType _type;

  bool get _isEditing => widget.network != null;

  @override
  void initState() {
    super.initState();
    final n = widget.network;
    _nameCtrl = TextEditingController(text: n?.name ?? '');
    _subnetCtrl = TextEditingController(text: n?.subnet ?? '');
    _gatewayCtrl = TextEditingController(text: n?.gateway ?? '');
    _dnsCtrl = TextEditingController(text: n?.dnsServers.join(', ') ?? '');
    _notesCtrl = TextEditingController(text: n?.notes ?? '');
    _type = n?.type ?? NetworkType.lan;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subnetCtrl.dispose();
    _gatewayCtrl.dispose();
    _dnsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _nonEmpty(String value) =>
      value.trim().isEmpty ? null : value.trim();

  String _typeLabel(AppLocalizations l10n, NetworkType type) => switch (type) {
        NetworkType.lan => l10n.networkTypeLan,
        NetworkType.tailscale => l10n.networkTypeTailscale,
        NetworkType.zerotier => l10n.networkTypeZerotier,
        NetworkType.easytier => l10n.networkTypeEasytier,
        NetworkType.wireguard => l10n.networkTypeWireguard,
        NetworkType.other => l10n.networkTypeOther,
      };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final dnsText = _dnsCtrl.text.trim();
    final dnsServers = dnsText.isEmpty
        ? <String>[]
        : dnsText.split(RegExp(r'[,;\s]+')).where((s) => s.isNotEmpty).toList();

    final network = Network(
      id: widget.network?.id,
      name: _nameCtrl.text.trim(),
      type: _type,
      subnet: _nonEmpty(_subnetCtrl.text),
      gateway: _nonEmpty(_gatewayCtrl.text),
      dnsServers: dnsServers,
      notes: _nonEmpty(_notesCtrl.text),
    );

    await NetworkStorage.addOrUpdateNetwork(network);
    AutoSyncService.instance.notifySaved();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editNetwork : l10n.addNetwork),
        actions: [
          TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.networkName),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.networkName : null,
            ),
            const SizedBox(height: 12),

            // Network type dropdown
            DropdownButtonFormField<NetworkType>(
              value: _type,
              decoration: InputDecoration(labelText: l10n.networkType),
              items: NetworkType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(_typeLabel(l10n, t)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _subnetCtrl,
              decoration: InputDecoration(
                labelText: l10n.networkSubnet,
                hintText: l10n.networkSubnetHint,
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _gatewayCtrl,
              decoration: InputDecoration(
                labelText: l10n.networkGateway,
                hintText: l10n.networkGatewayHint,
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _dnsCtrl,
              decoration: InputDecoration(
                labelText: l10n.networkDns,
                hintText: l10n.networkDnsHint,
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: l10n.networkNotes,
                hintText: l10n.networkNotesHint,
              ),
              maxLines: null,
              minLines: 3,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
