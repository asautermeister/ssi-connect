import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

import '../models/dive.dart';
import 'dive_list_screen.dart';
import 'widgets/error_state.dart';

/// Dives parsed from a manually imported FIT file. Same list body as the
/// Garmin-loaded view - only the source differs.
class ImportedDiveListScreen extends StatelessWidget {
  const ImportedDiveListScreen({super.key, required this.dives});

  final List<Dive> dives;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.importedDives)),
      body: dives.isEmpty
          ? ErrorState(
              icon: Icons.scuba_diving_outlined,
              message: s.noDivesInFile,
            )
          : DiveList(dives: dives),
    );
  }
}
