import 'package:flutter/services.dart';

/// Opens a web page in the system browser.
///
/// A channel of our own rather than `url_launcher`: the only thing needed
/// is "hand this https address to the browser", which is a few lines on
/// each side, and every platform plugin is one more thing that can break
/// the Android build - this project has been bitten by that twice.
abstract final class Browser {
  static const channel = MethodChannel('ssi_connect/browser');

  /// Returns false when nothing could open the page, so the caller can
  /// leave the address on screen to copy by hand.
  static Future<bool> open(Uri url) async {
    // Only web pages: this is not a general intent launcher.
    if (url.scheme != 'https') return false;
    try {
      return await channel.invokeMethod<bool>('open', url.toString()) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
