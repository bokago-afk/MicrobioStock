class Usuario {
  final String nome;
  final String login;
  final String senha;
  final String nivel; // 'adm' ou 'user'

  Usuario({
    required this.nome,
    required this.login,
    required this.senha,
    required this.nivel,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'login': login,
      'senha': senha,
      'nivel': nivel,
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      nome: map['nome'] ?? '',
      login: map['login'] ?? '',
      senha: map['senha'] ?? '',
      nivel: map['nivel'] ?? 'user',
    );
  }
}