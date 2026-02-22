import 'package:flutter/foundation.dart';

/// A simple logging service to centralize application logs.
/// This allows for easy toggling of logs and future integration with
/// remote logging services (e.g., Crashlytics, Sentry).
class LogService {
  static const bool _isEnabled = kDebugMode;
  static const String _tag = "[App]";

  /// Log a debug message.
  static void debug(String message, {String? tag}) {
    if (_isEnabled) {
      final timestamp = DateTime.now().toIso8601String();
      final logTag = tag ?? _tag;
      debugPrint('$timestamp $logTag DEBUG: $message');
    }
  }

  /// Log an info message.
  static void info(String message, {String? tag}) {
    if (_isEnabled) {
      final timestamp = DateTime.now().toIso8601String();
      final logTag = tag ?? _tag;
      debugPrint('$timestamp $logTag INFO: $message');
    }
  }

  /// Log an error message.
  static void error(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    // Errors should often be logged even in release mode, but for now we stick to debug logic
    // or use a specific flag.
    final timestamp = DateTime.now().toIso8601String();
    final logTag = tag ?? _tag;
    debugPrint('$timestamp $logTag ERROR: $message');
    if (error != null) {
      debugPrint('$timestamp $logTag ERROR DETAILS: $error');
    }
    if (stackTrace != null) {
      debugPrint('$timestamp $logTag STACK TRACE: $stackTrace');
    }
  }
}
