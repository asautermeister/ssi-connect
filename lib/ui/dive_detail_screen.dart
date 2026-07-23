import 'package:flutter/material.dart';

import '../models/dive.dart';
import 'qr_screen.dart';

class DiveDetailScreen extends StatelessWidget {
  const DiveDetailScreen({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tauchgang ${dive.diveNumberOfDay}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row(context, 'Datum', _formatDateTime(dive.dateTime)),
          _row(context, 'Tauchgang des Tages', '${dive.diveNumberOfDay}'),
          _row(context, 'Max. Tiefe', _meters(dive.maxDepthMeters)),
          _row(context, 'Ø Tiefe', _meters(dive.avgDepthMeters)),
          _row(context, 'Dauer', _duration(dive.duration)),
          _row(
            context,
            'Wassertemperatur',
            _celsius(dive.waterTemperatureCelsius),
          ),
          _row(context, 'Ort', dive.locationName ?? '–'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => QrScreen(dive: dive))),
        icon: const Icon(Icons.qr_code),
        label: const Text('QR-Code erzeugen'),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  String _meters(double? value) =>
      value == null ? '–' : '${value.toStringAsFixed(1)} m';

  String _celsius(double? value) =>
      value == null ? '–' : '${value.toStringAsFixed(1)} °C';

  String _duration(Duration? duration) {
    if (duration == null) return '–';
    final minutes = duration.inMinutes;
    return '$minutes min';
  }

  String _formatDateTime(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dateTime.day)}.${two(dateTime.month)}.${dateTime.year} '
        '${two(dateTime.hour)}:${two(dateTime.minute)}';
  }
}
