import 'package:flutter/foundation.dart';

/// Enum to define who sent the message.
enum SenderType {
  user,
  ai,
}

/// Enum to define the delivery status of the message.
enum MessageStatus {
  sent,
  delivered,
  read,
}

/// Enum to define the type of message content.
enum MessageType {
  text,
  image,
  audio,
  video,
  file,
}

/// A model representing a message in the AI Dietician chat.
class ChatMessage {
  /// Unique identifier for the message
  final String id;

  /// Textual or media content
  final String content;

  /// Sender type (user or AI)
  final SenderType sender;

  /// Time when message was sent
  final DateTime timestamp;

  /// Delivery status (sent, delivered, read)
  final MessageStatus status;

  /// Type of the message (text, image, etc.)
  final MessageType messageType;

  /// Optional URL or file path for media messages
  final String? mediaUrl;

  ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.messageType = MessageType.text,
    this.mediaUrl,
  });

  /// Converts a JSON map into a ChatMessage instance
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      sender: SenderType.values.firstWhere(
        (e) => describeEnum(e) == json['sender'],
        orElse: () => SenderType.ai,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      status: MessageStatus.values.firstWhere(
        (e) => describeEnum(e) == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      messageType: MessageType.values.firstWhere(
        (e) => describeEnum(e) == json['messageType'],
        orElse: () => MessageType.text,
      ),
      mediaUrl: json['mediaUrl'],
    );
  }

  /// Converts a ChatMessage instance to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'sender': describeEnum(sender),
      'timestamp': timestamp.toIso8601String(),
      'status': describeEnum(status),
      'messageType': describeEnum(messageType),
      'mediaUrl': mediaUrl,
    };
  }

  /// Creates a copy of this message with optional field overrides
  ChatMessage copyWith({
    String? id,
    String? content,
    SenderType? sender,
    DateTime? timestamp,
    MessageStatus? status,
    MessageType? messageType,
    String? mediaUrl,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, sender: ${describeEnum(sender)}, type: ${describeEnum(messageType)}, content: $content, time: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChatMessage &&
            id == other.id &&
            content == other.content &&
            sender == other.sender &&
            timestamp == other.timestamp &&
            status == other.status &&
            messageType == other.messageType &&
            mediaUrl == other.mediaUrl;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      content.hashCode ^
      sender.hashCode ^
      timestamp.hashCode ^
      status.hashCode ^
      messageType.hashCode ^
      mediaUrl.hashCode;
}
