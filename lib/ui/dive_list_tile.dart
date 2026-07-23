import 'package:flutter/material.dart';

import '../models/dive.dart';
import 'dive_detail_screen.dart';

/// One row in a dive list (fetched from Garmin or FIT-imported) - shared so
/// both list screens render dives identically.
class DiveListTile extends StatelessWidget {
  const DiveListTile({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(_formatDate(dive.dateTime)),
      subtitle: Text('Tauchgang ${dive.diveNumberOfDay} des Tages'),
      trailing: Text(
        dive.maxDepthMeters != null
            ? '${dive.maxDepthMeters!.toStringAsFixed(1)} m'
            : '–',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => DiveDetailScreen(dive: dive))),
    );
  }

  String _formatDate(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dateTime.day)}.${two(dateTime.month)}.${dateTime.year} '
        '${two(dateTime.hour)}:${two(dateTime.minute)}';
  }
}
