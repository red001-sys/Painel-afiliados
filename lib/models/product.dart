class Product {
  const Product({
    required this.id,
    required this.nome,
    this.categoria,
    this.descricao,
    this.cjUrl,
    this.imagemUrl,
    this.preco,
    this.ativo = true,
    required this.createdAt,
  });

  final String id;
  final String nome;
  final String? categoria;
  final String? descricao;
  final String? cjUrl;
  final String? imagemUrl;
  final double? preco;
  final bool ativo;
  final DateTime createdAt;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      nome: json['nome'] as String,
      categoria: json['categoria'] as String?,
      descricao: json['descricao'] as String?,
      cjUrl: json['cj_url'] as String?,
      imagemUrl: json['imagem_url'] as String?,
      preco: (json['preco'] as num?)?.toDouble(),
      ativo: json['ativo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'categoria': categoria,
      'descricao': descricao,
      'cj_url': cjUrl,
      'imagem_url': imagemUrl,
      'preco': preco,
      'ativo': ativo,
    };
  }

  Product copyWith({
    String? nome,
    String? categoria,
    String? descricao,
    String? cjUrl,
    String? imagemUrl,
    double? preco,
    bool? ativo,
  }) {
    return Product(
      id: id,
      nome: nome ?? this.nome,
      categoria: categoria ?? this.categoria,
      descricao: descricao ?? this.descricao,
      cjUrl: cjUrl ?? this.cjUrl,
      imagemUrl: imagemUrl ?? this.imagemUrl,
      preco: preco ?? this.preco,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt,
    );
  }
}
