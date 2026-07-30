class Affiliate {
  const Affiliate({
    required this.id,
    this.authUserId,
    this.nome,
    this.email,
    required this.sid,
    this.whatsapp,
    this.chavePix,
    this.estrelas = 0,
    this.ciclosCompletos = 0,
    required this.createdAt,
  });

  final String id;
  final String? authUserId;
  final String? nome;
  final String? email;
  final String sid;
  final String? whatsapp;
  final String? chavePix;
  final double estrelas;
  final int ciclosCompletos;
  final DateTime createdAt;

  factory Affiliate.fromJson(Map<String, dynamic> json) {
    return Affiliate(
      id: json['id'] as String,
      authUserId: json['auth_user_id'] as String?,
      nome: json['nome'] as String?,
      email: json['email'] as String?,
      sid: json['sid'] as String,
      whatsapp: json['whatsapp'] as String?,
      chavePix: json['chave_pix'] as String?,
      estrelas: (json['estrelas'] as num?)?.toDouble() ?? 0,
      ciclosCompletos: json['ciclos_completos'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_user_id': authUserId,
      'nome': nome,
      'email': email,
      'sid': sid,
      'whatsapp': whatsapp,
      'chave_pix': chavePix,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Affiliate copyWith({
    String? id,
    String? authUserId,
    String? nome,
    String? email,
    String? sid,
    String? whatsapp,
    String? chavePix,
    double? estrelas,
    int? ciclosCompletos,
    DateTime? createdAt,
  }) {
    return Affiliate(
      id: id ?? this.id,
      authUserId: authUserId ?? this.authUserId,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      sid: sid ?? this.sid,
      whatsapp: whatsapp ?? this.whatsapp,
      chavePix: chavePix ?? this.chavePix,
      estrelas: estrelas ?? this.estrelas,
      ciclosCompletos: ciclosCompletos ?? this.ciclosCompletos,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Affiliate &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          authUserId == other.authUserId &&
          nome == other.nome &&
          email == other.email &&
          sid == other.sid &&
          whatsapp == other.whatsapp &&
          chavePix == other.chavePix &&
          estrelas == other.estrelas &&
          ciclosCompletos == other.ciclosCompletos &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, authUserId, nome, email, sid, whatsapp,
      chavePix, estrelas, ciclosCompletos, createdAt);
}
