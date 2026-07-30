class Sale {
  const Sale({
    required this.id,
    required this.transactionId,
    this.affiliateId,
    required this.affiliateSid,
    this.saleAmount,
    this.commissionAmount,
    this.status,
    this.saleDate,
    this.advertiser,
    this.product,
    this.currency,
    this.orderId,
    this.lockedDate,
    required this.createdAt,
  });

  final String id;
  final String transactionId;
  final String? affiliateId;
  final String affiliateSid;
  final double? saleAmount;
  final double? commissionAmount;
  final String? status;
  final DateTime? saleDate;
  final String? advertiser;
  final String? product;
  final String? currency;
  final String? orderId;
  final DateTime? lockedDate;
  final DateTime createdAt;

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      affiliateId: json['affiliate_id'] as String?,
      affiliateSid: json['affiliate_sid'] as String,
      saleAmount: (json['sale_amount'] as num?)?.toDouble(),
      commissionAmount: (json['commission_amount'] as num?)?.toDouble(),
      status: json['status'] as String?,
      saleDate: json['sale_date'] != null
          ? DateTime.parse(json['sale_date'] as String)
          : null,
      advertiser: json['advertiser'] as String?,
      product: json['product'] as String?,
      currency: json['currency'] as String?,
      orderId: json['order_id'] as String?,
      lockedDate: json['locked_date'] != null
          ? DateTime.parse(json['locked_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'affiliate_id': affiliateId,
      'affiliate_sid': affiliateSid,
      'sale_amount': saleAmount,
      'commission_amount': commissionAmount,
      'status': status,
      'sale_date': saleDate?.toIso8601String(),
      'advertiser': advertiser,
      'product': product,
      'currency': currency,
      'order_id': orderId,
      'locked_date': lockedDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Sale copyWith({
    String? id,
    String? transactionId,
    String? affiliateId,
    String? affiliateSid,
    double? saleAmount,
    double? commissionAmount,
    String? status,
    DateTime? saleDate,
    String? advertiser,
    String? product,
    String? currency,
    String? orderId,
    DateTime? lockedDate,
    DateTime? createdAt,
  }) {
    return Sale(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      affiliateId: affiliateId ?? this.affiliateId,
      affiliateSid: affiliateSid ?? this.affiliateSid,
      saleAmount: saleAmount ?? this.saleAmount,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      status: status ?? this.status,
      saleDate: saleDate ?? this.saleDate,
      advertiser: advertiser ?? this.advertiser,
      product: product ?? this.product,
      currency: currency ?? this.currency,
      orderId: orderId ?? this.orderId,
      lockedDate: lockedDate ?? this.lockedDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sale &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          transactionId == other.transactionId &&
          affiliateId == other.affiliateId &&
          affiliateSid == other.affiliateSid &&
          saleAmount == other.saleAmount &&
          commissionAmount == other.commissionAmount &&
          status == other.status &&
          saleDate == other.saleDate &&
          advertiser == other.advertiser &&
          product == other.product &&
          currency == other.currency &&
          orderId == other.orderId &&
          lockedDate == other.lockedDate &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        transactionId,
        affiliateId,
        affiliateSid,
        saleAmount,
        commissionAmount,
        status,
        saleDate,
        advertiser,
        product,
        currency,
        orderId,
        lockedDate,
        createdAt,
      );
}
