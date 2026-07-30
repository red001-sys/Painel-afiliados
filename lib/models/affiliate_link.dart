class AffiliateLink {
  const AffiliateLink({
    required this.id,
    required this.affiliateId,
    required this.productId,
    this.cjBaseLink,
    required this.finalLink,
    this.linkName,
    this.displayOrder = 0,
    this.ativo = true,
    required this.createdAt,
    required this.updatedAt,
    this.productName,
    this.productCategoria,
    this.productImagemUrl,
    this.productDescricao,
    this.productPreco,
  });

  final String id;
  final String affiliateId;
  final String productId;
  final String? cjBaseLink;
  final String finalLink;
  final String? linkName;
  final int displayOrder;
  final bool ativo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? productName;
  final String? productCategoria;
  final String? productImagemUrl;
  final String? productDescricao;
  final double? productPreco;

  factory AffiliateLink.fromJson(Map<String, dynamic> json) {
    final products = json['products'] as Map<String, dynamic>?;
    return AffiliateLink(
      id: json['id'] as String,
      affiliateId: json['affiliate_id'] as String,
      productId: json['product_id'] as String,
      cjBaseLink: json['cj_base_link'] as String?,
      finalLink: json['final_link'] as String,
      linkName: json['link_name'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
      ativo: json['ativo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      productName: products?['nome'] as String?,
      productCategoria: products?['categoria'] as String?,
      productImagemUrl: products?['imagem_url'] as String?,
      productDescricao: products?['descricao'] as String?,
      productPreco: (products?['preco'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'affiliate_id': affiliateId,
      'product_id': productId,
      'cj_base_link': cjBaseLink,
      'final_link': finalLink,
      'link_name': linkName,
      'display_order': displayOrder,
      'ativo': ativo,
    };
  }

  AffiliateLink copyWith({
    String? id,
    String? affiliateId,
    String? productId,
    String? cjBaseLink,
    String? finalLink,
    String? linkName,
    int? displayOrder,
    bool? ativo,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? productName,
    String? productCategoria,
    String? productImagemUrl,
    String? productDescricao,
    double? productPreco,
  }) {
    return AffiliateLink(
      id: id ?? this.id,
      affiliateId: affiliateId ?? this.affiliateId,
      productId: productId ?? this.productId,
      cjBaseLink: cjBaseLink ?? this.cjBaseLink,
      finalLink: finalLink ?? this.finalLink,
      linkName: linkName ?? this.linkName,
      displayOrder: displayOrder ?? this.displayOrder,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      productName: productName ?? this.productName,
      productCategoria: productCategoria ?? this.productCategoria,
      productImagemUrl: productImagemUrl ?? this.productImagemUrl,
      productDescricao: productDescricao ?? this.productDescricao,
      productPreco: productPreco ?? this.productPreco,
    );
  }

  String get displayName => linkName ?? productName ?? 'Sem nome';
}
