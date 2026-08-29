class MemoryFact {
  final int? id;
  final String fact;
  final DateTime createdAt;

  const MemoryFact({
    this.id,
    required this.fact,
    required this.createdAt,
  });

  factory MemoryFact.fromMap(Map<String, dynamic> map) {
    return MemoryFact(
      id: map['id'] as int?,
      fact: map['fact'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'fact': fact,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
