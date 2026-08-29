class Conversation {
  final int? id;
  final String title;
  final DateTime createdAt;

  const Conversation({
    this.id,
    required this.title,
    required this.createdAt,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as int?,
      title: map['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  Conversation copyWith({String? title}) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
    );
  }
}
