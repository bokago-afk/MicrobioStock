import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:microbiostock/models/insumo_model.dart';
import 'package:microbiostock/models/historico_model.dart';
import 'package:microbiostock/models/usuario_model.dart';

class StorageService {
  static const String _chaveBancoDeDados = 'estoque_microbiologia';
  static const String _chaveFabricantes = 'lista_fabricantes';
  static const String _chaveHistorico = 'historico_movimentacoes';
  static const String _chaveUsuarios = 'lista_usuarios';
  static const String _chaveSessao = 'usuario_logado';

  // Singleton para evitar múltiplas instâncias abrindo o disco ao mesmo tempo
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // --- GESTÃO DE USUÁRIOS ---

  Future<Usuario?> autenticar(String login, String senha) async {
    try {
      final usuarios = await obterUsuarios();
      final usuarioEncontrado = usuarios.firstWhere(
        (u) => u.login == login && u.senha == senha,
        orElse: () => throw Exception("Não encontrado"),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveSessao, jsonEncode(usuarioEncontrado.toMap()));
      return usuarioEncontrado;
    } catch (e) {
      return null;
    }
  }

  Future<Usuario?> obterUsuarioLogado() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonUsuario = prefs.getString(_chaveSessao);
    if (jsonUsuario == null) return null;
    try {
      return Usuario.fromMap(jsonDecode(jsonUsuario));
    } catch (e) {
      return null;
    }
  }

  Future<void> deslogar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveSessao);
  }

  Future<List<Usuario>> obterUsuarios() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> lista = prefs.getStringList(_chaveUsuarios) ?? [];
    
    if (lista.isEmpty) {
      final admin = Usuario(nome: "Administrador", login: "admin", senha: "123", nivel: "adm");
      await prefs.setStringList(_chaveUsuarios, [jsonEncode(admin.toMap())]);
      return [admin];
    }
    
    return lista.map((e) => Usuario.fromMap(jsonDecode(e))).toList();
  }

  Future<void> salvarUsuario(Usuario user) async {
    final prefs = await SharedPreferences.getInstance();
    List<Usuario> listaAtual = await obterUsuarios();
    listaAtual.removeWhere((u) => u.login == user.login);
    listaAtual.add(user);
    
    List<String> novaLista = listaAtual.map((u) => jsonEncode(u.toMap())).toList();
    await prefs.setStringList(_chaveUsuarios, novaLista);
  }

  // --- HISTÓRICO ---
  
  Future<void> registrarMovimentacao(Historico mov) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> listaHistorico = prefs.getStringList(_chaveHistorico) ?? [];
    
    if (listaHistorico.length > 1000) {
      listaHistorico.removeAt(0); 
    }
    
    listaHistorico.add(jsonEncode(mov.toMap()));
    await prefs.setStringList(_chaveHistorico, listaHistorico);
  }

  Future<List<Historico>> obterHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> lista = prefs.getStringList(_chaveHistorico) ?? [];
    return lista.map((e) => Historico.fromMap(jsonDecode(e))).toList().reversed.toList();
  }

  // --- FABRICANTES ---
  
  Future<List<String>> obterFabricantes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_chaveFabricantes) ?? [];
  }

  Future<void> salvarFabricante(String fabricante) async {
    final nome = fabricante.trim();
    if (nome.isEmpty) return; 
    final prefs = await SharedPreferences.getInstance();
    List<String> fabricantes = await obterFabricantes();
    if (!fabricantes.any((f) => f.toLowerCase() == nome.toLowerCase())) {
      fabricantes.add(nome);
      fabricantes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await prefs.setStringList(_chaveFabricantes, fabricantes);
    }
  }

  // --- MÉTODO RECOLOCADO AQUI: deletarFabricante ---
  Future<void> deletarFabricante(String fabricante) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> fabricantes = await obterFabricantes();
    fabricantes.removeWhere((f) => f == fabricante);
    await prefs.setStringList(_chaveFabricantes, fabricantes);
  }

  // --- INSUMOS ---

  Future<List<Insumo>> obterInsumos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> listaString = prefs.getStringList(_chaveBancoDeDados) ?? [];
    
    return listaString.map((item) {
      final mapa = jsonDecode(item);
      return Insumo.fromMap(mapa, mapa['id']?.toString() ?? '');
    }).toList();
  }

  Future<void> salvarInsumo(Insumo insumo) async {
    final prefs = await SharedPreferences.getInstance();
    List<Insumo> listaAtual = await obterInsumos();
    
    await salvarFabricante(insumo.fabricante);

    String id = insumo.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    int index = listaAtual.indexWhere((item) => item.id == id);
    
    Map<String, dynamic> dados = insumo.toMap();
    dados['id'] = id;

    if (index >= 0) {
      listaAtual[index] = Insumo.fromMap(dados, id);
    } else {
      listaAtual.add(Insumo.fromMap(dados, id));
    }

    List<String> novaLista = listaAtual.map((item) {
      Map<String, dynamic> m = item.toMap();
      m['id'] = item.id;
      return jsonEncode(m);
    }).toList();

    await prefs.setStringList(_chaveBancoDeDados, novaLista);
  }

  Future<void> deletarInsumo(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<Insumo> listaAtual = await obterInsumos();
    listaAtual.removeWhere((item) => item.id == id);
    
    List<String> novaLista = listaAtual.map((item) {
      Map<String, dynamic> m = item.toMap();
      m['id'] = item.id;
      return jsonEncode(m);
    }).toList();
    
    await prefs.setStringList(_chaveBancoDeDados, novaLista);
  }
}