class Insumo {
  final String? id;
  final String nome;          
  final String lote;          
  final DateTime dataValidade; 
  final int quantidade;       
  final int estoqueMinimo;    // Campo para controle de estoque
  final String fabricante;
  final String? caminhoPdf; 

  Insumo({
    this.id,
    required this.nome,
    required this.lote,
    required this.dataValidade,
    required this.quantidade,
    this.estoqueMinimo = 0, // Alterado para opcional (default 0) para evitar erros
    required this.fabricante,
    this.caminhoPdf,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'lote': lote,
      'dataValidade': dataValidade.toIso8601String(),
      'quantidade': quantidade,
      'estoqueMinimo': estoqueMinimo,
      'fabricante': fabricante,
      'caminhoPdf': caminhoPdf,
    };
  }

  factory Insumo.fromMap(Map<String, dynamic> map, String id) {
    return Insumo(
      id: id,
      nome: map['nome'] ?? '',
      lote: map['lote'] ?? '',
      dataValidade: map['dataValidade'] != null 
          ? DateTime.parse(map['dataValidade']) 
          : DateTime.now(),
      quantidade: map['quantidade'] ?? 0,
      estoqueMinimo: map['estoqueMinimo'] ?? 0,
      fabricante: map['fabricante'] ?? '',
      caminhoPdf: map['caminhoPdf'],
    );
  }
}