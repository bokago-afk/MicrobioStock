class Historico {
  final String nomeInsumo;
  final String lote;
  final double quantidade;
  final String tipo; // "Entrada" ou "Saída"
  final DateTime dataHora;
  final String usuario; // <--- ADICIONE ESTA LINHA

  Historico({
    required this.nomeInsumo,
    required this.lote,
    required this.quantidade,
    required this.tipo,
    required this.dataHora,
    required this.usuario, // <--- ADICIONE AQUI
  });

  Map<String, dynamic> toMap() {
    return {
      'nomeInsumo': nomeInsumo,
      'lote': lote,
      'quantidade': quantidade,
      'tipo': tipo,
      'dataHora': dataHora.toIso8601String(),
      'usuario': usuario, // <--- E AQUI
    };
  }

  factory Historico.fromMap(Map<String, dynamic> map) {
    return Historico(
      nomeInsumo: map['nomeInsumo'] ?? '',
      lote: map['lote'] ?? '',
      quantidade: (map['quantidade'] ?? 0).toDouble(),
      tipo: map['tipo'] ?? '',
      dataHora: DateTime.parse(map['dataHora']),
      usuario: map['usuario'] ?? 'Sistema', // <--- E AQUI
    );
  }
}