import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';

class ImageShareService {
  static Future<void> sharePngBytes(
    BuildContext context,
    Uint8List imageBytes, {
    required String fileName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, fileName));
    await file.writeAsBytes(imageBytes);

    if (!context.mounted) return;

    if (Platform.isAndroid) {
      const channel = MethodChannel('com.yuanzhe.my_device/share');
      await channel.invokeMethod('shareFile', {
        'path': file.path,
        'mimeType': 'image/png',
      });
    } else if (Platform.isIOS) {
      await Share.shareXFiles([XFile(file.path)]);
    } else {
      await _showDesktopPreview(
        context,
        imageBytes,
        file.path,
        l10n,
        fileName: fileName,
      );
    }
  }

  static Future<void> _showDesktopPreview(
    BuildContext context,
    Uint8List imageBytes,
    String tempPath,
    AppLocalizations l10n, {
    required String fileName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: Text(l10n.shareCopy),
                      onPressed: () async {
                        await _copyImageToClipboard(tempPath);
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(l10n.shareCopied)),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.save_alt),
                      label: Text(l10n.shareSaveAs),
                      onPressed: () async {
                        final result = await FilePicker.platform.saveFile(
                          dialogTitle: l10n.shareSaveAs,
                          fileName: fileName,
                          type: FileType.image,
                        );
                        if (result != null) {
                          await File(result).writeAsBytes(imageBytes);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(l10n.shareSaved)),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _copyImageToClipboard(String imagePath) async {
    if (Platform.isWindows) {
      await Process.run('powershell', [
        '-command',
        "Add-Type -AssemblyName System.Drawing; "
            "Add-Type -AssemblyName System.Windows.Forms; "
            "\$img = [System.Drawing.Image]::FromFile('$imagePath'); "
            "[System.Windows.Forms.Clipboard]::SetImage(\$img); "
            "\$img.Dispose()",
      ]);
    } else if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'set the clipboard to (read (POSIX file "$imagePath") as «class PNGf»)',
      ]);
    } else if (Platform.isLinux) {
      await Process.run('xclip', [
        '-selection',
        'clipboard',
        '-target',
        'image/png',
        '-i',
        imagePath,
      ]);
    }
  }
}
