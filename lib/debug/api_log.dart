import 'package:flutter/foundation.dart';

/// One recorded HTTP exchange with a Garmin endpoint.
class ApiLogEntry {
  ApiLogEntry({
    required this.timestamp,
    required this.method,
    required this.url,
    this.statusCode,
    this.requestBody,
    this.responseBody,
    this.error,
  });

  final DateTime timestamp;
  final String method;
  final String url;
  final int? statusCode;
  final String? requestBody;
  final String? responseBody;
  final String? error;

  bool get isFailure =>
      error != null || (statusCode != null && statusCode! >= 400);

  /// Plain-text rendering, used for the copy-to-clipboard button so the
  /// details can be pasted into a chat/issue instead of retyped from a
  /// phone screen.
  String toText() {
    final buffer = StringBuffer()
      ..writeln('[${timestamp.toIso8601String()}] $method $url')
      ..writeln('Status: ${statusCode ?? "-"}');
    if (requestBody != null) buffer.writeln('Request: $requestBody');
    if (responseBody != null) buffer.writeln('Response: $responseBody');
    if (error != null) buffer.writeln('Error: $error');
    return buffer.toString();
  }
}

/// In-memory ring buffer of recent Garmin API calls, so failures can be
/// inspected on the device instead of guessing from a status code.
///
/// Deliberately never persisted: the entries contain data from
/// authentication traffic, and this is a debugging aid, not an audit log.
/// Sensitive values are redacted before they get here (see
/// [ApiLogInterceptor]).
class ApiLog extends ChangeNotifier {
  ApiLog._();

  static final ApiLog instance = ApiLog._();

  static const _maxEntries = 60;

  /// Turn off to stop recording (and to hide raw API details in error
  /// messages). Kept on by default while the Garmin integration is still
  /// being validated against real accounts.
  bool enabled = true;

  final List<ApiLogEntry> _entries = [];
  List<ApiLogEntry> get entries => List.unmodifiable(_entries.reversed);

  void add(ApiLogEntry entry) {
    if (!enabled) return;
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  void setEnabled(bool value) {
    enabled = value;
    notifyListeners();
  }

  String allAsText() => entries.map((e) => e.toText()).join('\n');
}
