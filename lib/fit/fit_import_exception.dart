/// Thrown when a selected file can't be turned into any dives - either it's
/// not a valid FIT file, or it doesn't contain diving data.
class FitImportException implements Exception {
  FitImportException(this.message);
  final String message;

  @override
  String toString() => 'FitImportException: $message';
}
