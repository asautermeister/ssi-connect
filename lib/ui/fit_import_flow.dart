import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../fit/fit_dive_importer.dart';
import '../fit/fit_import_exception.dart';
import 'imported_dive_list_screen.dart';

/// Lets the user pick a .fit file (exported from Garmin Connect) and, on
/// success, opens the resulting dive list. Used both as the primary "no
/// Garmin login needed" entry point and as a fallback when a login attempt
/// fails.
Future<void> pickAndImportFitFile(BuildContext context) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['fit'],
    withData: true,
  );
  if (!context.mounted) return;
  if (result == null || result.files.isEmpty) return;

  final bytes = result.files.single.bytes;
  if (bytes == null) {
    _showError(context, 'Datei konnte nicht gelesen werden.');
    return;
  }

  try {
    final dives = FitDiveImporter.parse(bytes);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImportedDiveListScreen(dives: dives)),
    );
  } on FitImportException catch (e) {
    if (!context.mounted) return;
    _showError(context, e.message);
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
