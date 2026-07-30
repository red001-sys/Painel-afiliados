class RankingEntry {
  const RankingEntry({
    required this.id,
    required this.nome,
    required this.estrelas,
    required this.ciclosCompletos,
  });

  final String id;
  final String nome;
  final double estrelas;
  final int ciclosCompletos;

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      id: json['id'] as String,
      nome: json['nome'] as String,
      estrelas: (json['estrelas'] as num?)?.toDouble() ?? 0,
      ciclosCompletos: json['ciclos_completos'] as int? ?? 0,
    );
  }
}
