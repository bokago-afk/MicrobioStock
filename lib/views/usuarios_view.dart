import 'package:flutter/material.dart';
import 'package:microbiostock/models/usuario_model.dart';
import 'package:microbiostock/services/storage_service.dart';

class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  final StorageService _storage = StorageService();
  List<Usuario> _usuarios = [];

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  Future<void> _carregarUsuarios() async {
    final lista = await _storage.obterUsuarios();
    setState(() {
      _usuarios = lista;
    });
  }

  void _abrirDialogoUsuario({Usuario? usuarioEdicao}) {
    final nomeController = TextEditingController(text: usuarioEdicao?.nome ?? '');
    final loginController = TextEditingController(text: usuarioEdicao?.login ?? '');
    final senhaController = TextEditingController(text: usuarioEdicao?.senha ?? '');
    String nivelSelecionado = usuarioEdicao?.nivel ?? 'user';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(usuarioEdicao == null ? "Novo Usuário" : "Editar Usuário"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: "Nome Completo"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: loginController,
                decoration: const InputDecoration(labelText: "Login de Acesso"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: senhaController,
                decoration: const InputDecoration(labelText: "Senha / PIN"),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: nivelSelecionado,
                decoration: const InputDecoration(labelText: "Nível de Acesso"),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text("Usuário (Baixa/Leitura)")),
                  DropdownMenuItem(value: 'adm', child: Text("Administrador (Total)")),
                ],
                onChanged: (val) => nivelSelecionado = val!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
            onPressed: () async {
              if (nomeController.text.isEmpty || loginController.text.isEmpty || senhaController.text.isEmpty) return;

              final novoUsuario = Usuario(
                nome: nomeController.text,
                login: loginController.text,
                senha: senhaController.text,
                nivel: nivelSelecionado,
              );

              await _storage.salvarUsuario(novoUsuario);
              _carregarUsuarios();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Salvar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gerenciar Equipe", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF00796B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _usuarios.length,
        itemBuilder: (context, index) {
          final user = _usuarios[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: user.nivel == 'adm' ? Colors.orange[100] : Colors.blue[100],
                child: Icon(
                  user.nivel == 'adm' ? Icons.security : Icons.person,
                  color: user.nivel == 'adm' ? Colors.orange[800] : Colors.blue[800],
                ),
              ),
              title: Text(user.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Login: ${user.login} | Nível: ${user.nivel.toUpperCase()}"),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey),
                onPressed: () => _abrirDialogoUsuario(usuarioEdicao: user),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00796B),
        onPressed: () => _abrirDialogoUsuario(),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}