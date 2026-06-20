/// Represents the severity level of a system log.
enum LogLevel { 
  /// Informational messages.
  info, 
  /// Warnings that do not halt the system.
  warning, 
  /// Critical events such as crashes or system failures.
  critical 
}

/// A structured log message emitted by the engine.
class LogMessage {
  /// The actual text content of the log.
  final String text;

  /// The severity [LogLevel] of the log.
  final LogLevel level;

  /// The exact time the log was generated.
  final DateTime timestamp;

  /// Creates a [LogMessage] with the given [text] and an optional severity [level].
  LogMessage(this.text, {this.level = LogLevel.info}) : timestamp = DateTime.now();
}
