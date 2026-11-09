import 'dart:developer' as developer;

/// Application-wide structured logging service.
class AppLogger {
  AppLogger._();

  /// Logs informational events.
  static void info(String message, [String name = 'IT_PDF']) {
    developer.log(message, name: name, level: 800);
  }

  /// Logs warning events.
  static void warning(String message, [String name = 'IT_PDF']) {
    developer.log(message, name: name, level: 900);
  }

  /// Alias for warning events.
  static void warn(String message, [String name = 'IT_PDF']) => warning(message, name);

  /// Logs error events with error details and stack trace.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String name = 'IT_PDF',
  }) {
    developer.log(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
