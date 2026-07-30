class Video {
  const Video({
    required this.id,
    required this.titulo,
    this.descricao,
    required this.videoUrl,
    this.thumbnailUrl,
    this.displayOrder = 0,
    this.ativo = true,
    required this.createdAt,
  });

  final String id;
  final String titulo;
  final String? descricao;
  final String videoUrl;
  final String? thumbnailUrl;
  final int displayOrder;
  final bool ativo;
  final DateTime createdAt;

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      descricao: json['descricao'] as String?,
      videoUrl: json['video_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
      ativo: json['ativo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descricao': descricao,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'display_order': displayOrder,
      'ativo': ativo,
    };
  }

  Video copyWith({
    String? titulo,
    String? descricao,
    String? videoUrl,
    String? thumbnailUrl,
    int? displayOrder,
    bool? ativo,
  }) {
    return Video(
      id: id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      displayOrder: displayOrder ?? this.displayOrder,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt,
    );
  }
}
