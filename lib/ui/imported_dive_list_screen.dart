import 'package:flutter/material.dart';

import '../models/dive.dart';
import 'dive_list_tile.dart';

/// Shows dives parsed from a manually imported FIT file - same list look as
/// [DiveListScreen], but backed by a plain in-memory list instead of a
/// live Garmin fetch.
class ImportedDiveListScreen extends StatelessWidget {
  const ImportedDiveListScreen({super.key, required this.dives});

  final List<Dive> dives;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importierte Tauchgänge')),
      body: dives.isEmpty
          ? const Center(child: Text('Keine Tauchgänge gefunden.'))
          : ListView.separated(
              itemCount: dives.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => DiveListTile(dive: dives[index]),
            ),
    );
  }
}
