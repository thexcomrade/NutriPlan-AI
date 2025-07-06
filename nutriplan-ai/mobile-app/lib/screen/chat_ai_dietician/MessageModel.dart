class MessageModel {
  /// Unique ID for the message (optional).
  final String? id;

  /// The content of the message text.
  final String message;

  /// Flag indicating whether this message was sent by the user.
  final bool isUserMessage;

  /// Timestamp of when the message was created.
  final DateTime timestamp;

  MessageModel({
    this.id,
    required this.message,
    required this.isUserMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Factory constructor to create a MessageModel from a JSON map.
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String?,
      message: json['message'] as String,
      isUserMessage: json['isUserMessage'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Converts the MessageModel instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'isUserMessage': isUserMessage,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
