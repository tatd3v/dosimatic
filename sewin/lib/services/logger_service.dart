import 'package:flutter/foundation.dart';

class Logger {
  static const String _tag = 'SecWin';

  /// Log a debug message
  static void d(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      // Only log in debug mode
      final buffer = StringBuffer('[$_tag] DEBUG: $message');
      if (error != null) {
        buffer.write(' - Error: $error');
      }
      if (stackTrace != null) {
        buffer.write('\n$stackTrace');
      }
      // ignore: avoid_print
      print(buffer.toString());
    }
  }

  /// Log an info message
  static void i(String message) {
    final buffer = '[$_tag] INFO: $message';
    // In production, you might want to send this to a logging service
    if (kDebugMode) {
      // ignore: avoid_print
      print(buffer);
    }
  }

  /// Log a warning message
  static void w(String message, {dynamic error, StackTrace? stackTrace}) {
    final buffer = StringBuffer('[$_tag] WARNING: $message');
    if (error != null) {
      buffer.write(' - Error: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    // In production, you might want to send this to a logging service
    // ignore: avoid_print
    print(buffer.toString());
  }

  /// Log an error message
  static void e(String message, {dynamic error, StackTrace? stackTrace}) {
    final buffer = StringBuffer('[$_tag] ERROR: $message');
    if (error != null) {
      buffer.write(' - Error: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    // In production, you might want to send this to a logging service
    // ignore: avoid_print
    print(buffer.toString());
  }
}
