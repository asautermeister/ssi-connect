import 'dart:io';

import 'package:dio/dio.dart';

/// Whether a Dio failure means "the request never left the device or never
/// found a server", as opposed to "the server answered something we didn't
/// like".
///
/// [DioExceptionType.connectionError] covers the socket-level failures
/// (no route, DNS, connection refused); the timeouts are here too, because
/// a request that times out on a tablet in a boat's dry bag is offline for
/// every practical purpose.
///
/// Lives here rather than next to one API client because both the Garmin
/// and the SSI side need the same distinction, and neither should have to
/// import the other to get it.
bool isOfflineDioError(DioException e) =>
    e.type == DioExceptionType.connectionError ||
    e.type == DioExceptionType.connectionTimeout ||
    e.type == DioExceptionType.sendTimeout ||
    e.type == DioExceptionType.receiveTimeout ||
    e.error is SocketException;
