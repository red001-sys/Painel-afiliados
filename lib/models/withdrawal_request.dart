class WithdrawalRequest {
  const WithdrawalRequest({
    required this.id,
    required this.affiliateId,
    required this.valor,
    required this.status,
    this.chavePixSnapshot,
    required this.createdAt,
    this.paidAt,
    this.affiliateName,
  });

  final String id;
  final String affiliateId;
  final double valor;
  final String status; // pendente | pago | cancelado
  final String? chavePixSnapshot;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? affiliateName; // preenchido só na listagem do admin (join)

  bool get isPending => status == 'pendente';

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    final affiliate = json['affiliates'] as Map<String, dynamic>?;
    return WithdrawalRequest(
      id: json['id'] as String,
      affiliateId: json['affiliate_id'] as String,
      valor: (json['valor'] as num).toDouble(),
      status: json['status'] as String,
      chavePixSnapshot: json['chave_pix_snapshot'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      affiliateName: affiliate?['nome'] as String?,
    );
  }
}
