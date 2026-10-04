import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../models/network.dart';

class NetworkConfigPage extends StatefulWidget {
  final NetworkDevice assignment;

  /// Purpose: Edit one EasyTier membership's raw configuration.
  /// Inputs: Assignment.
  /// Returns: Editor.
  /// Side effects: None.
  /// Notes: Format is a label; text is never converted or executed.
  const NetworkConfigPage({super.key, required this.assignment});

  /// Purpose: Create editor state.
  /// Inputs: None.
  /// Returns: State.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<NetworkConfigPage> createState() => _NetworkConfigPageState();
}

class _NetworkConfigPageState extends State<NetworkConfigPage> {
  late final TextEditingController _text;
  late String _format;

  /// Purpose: Seed unaltered config text.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Allocates controller.
  /// Notes: Unknown formats fall back to TOML in the editor.
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.assignment.configText ?? '');
    _format = widget.assignment.configFormat == 'yaml' ? 'yaml' : 'toml';
  }

  /// Purpose: Release text controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes controller.
  /// Notes: None.
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Purpose: Read or export a UTF-8 configuration through the file picker.
  /// Inputs: Whether to export.
  /// Returns: Completion.
  /// Side effects: Reads/writes the selected file; displays errors.
  /// Notes: Cancel does not change the draft.
  Future<void> _file(bool export) async {
    final l = AppLocalizations.of(context)!;
    try {
      if (export) {
        final bytes = Uint8List.fromList(utf8.encode(_text.text));
        final path = await FilePicker.platform.saveFile(
          fileName: 'easytier.$_format',
          bytes: bytes,
        );
        if (path != null && !Platform.isAndroid && !Platform.isIOS) {
          await File(path).writeAsBytes(bytes);
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['yaml', 'yml', 'toml'],
          withData: true,
        );
        if (result == null) return;
        final f = result.files.single;
        final text = utf8.decode(f.bytes ?? await File(f.path!).readAsBytes());
        if (mounted) {
          setState(() {
            _text.text = text;
            _format = f.name.toLowerCase().endsWith('.toml') ? 'toml' : 'yaml';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l.networkImportFailed}: $e')));
      }
    }
  }

  /// Purpose: Render raw config actions and editor.
  /// Inputs: Context.
  /// Returns: Widget tree.
  /// Side effects: Save returns the draft to the parent.
  /// Notes: Whitespace is preserved, including whitespace-only content.
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.networkDeviceConfig),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              widget.assignment.copyWith(
                configFormat: _format,
                configText: _text.text,
                clearConfig: _text.text.isEmpty,
              ),
            ),
            child: Text(l.save),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: formMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _format,
                items: const [
                  DropdownMenuItem(value: 'toml', child: Text('TOML')),
                  DropdownMenuItem(value: 'yaml', child: Text('YAML')),
                ],
                onChanged: (v) => setState(() => _format = v ?? 'toml'),
              ),
              Wrap(
                children: [
                  TextButton.icon(
                    onPressed: () => _file(false),
                    icon: const Icon(Icons.file_open),
                    label: Text(l.networkConfigRead),
                  ),
                  TextButton.icon(
                    onPressed: () => _file(true),
                    icon: const Icon(Icons.save_alt),
                    label: Text(l.networkConfigExport),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: _text.text)),
                    icon: const Icon(Icons.copy),
                    label: Text(l.networkConfigCopy),
                  ),
                ],
              ),
              TextField(
                controller: _text,
                minLines: 12,
                maxLines: null,
                style: const TextStyle(fontFamily: 'monospace'),
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l.networkConfigText,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
