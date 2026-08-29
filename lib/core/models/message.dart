class Message {
  final int? id;
  final int conversationId;
  final String role;
  final String content;
  final DateTime time;

  const Message({
    this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.time,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as int?,
      conversationId: map['conversation_id'] as int,
      role: map['role'] as String,
      content: map['message'] as String,
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'conversation_id': conversationId,
      'role': role,
      'message': content,
      'time': time.millisecondsSinceEpoch,
    };
  }
}
