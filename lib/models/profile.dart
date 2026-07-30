class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String role;
  final DateTime createdAt;

  bool get isAdmin => role == 'admin';
  bool get isAffiliate => role == 'affiliate';

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
