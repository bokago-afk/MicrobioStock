import 'package:flutter/material.dart';
import 'package:microbiostock/services/storage_service.dart';
import 'package:microbiostock/views/home_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _loginController = TextEditingController();
  final _senhaController = TextEditingController();
  final StorageService _storage = StorageService();
  bool _senhaVisivel = false;
  bool _estaCarregando = false; // NOVA VARIÁVEL: Para evitar cliques múltiplos

  void _entrar() async {
    // Evita que o usuário clique várias vezes e trave o sistema
    if (_estaCarregando) return;

    String login = _loginController.text.trim();
    String senha = _senhaController.text.trim();

    if (login.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha login e senha"), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _estaCarregando = true);

    try {
      // Tenta autenticar com um tempo limite (opcional, mas recomendado)
      final usuario = await _storage.autenticar(login, senha);

      if (!mounted) return;

      if (usuario != null) {
        // Login sucesso: vai para a Home e remove a tela de login da memória
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const HomeView())
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login ou senha incorretos"), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      // Se der qualquer erro no código do Storage, o app te avisa em vez de travar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro no sistema: $e"), backgroundColor: Colors.black)
        );
      }
    } finally {
      // Sempre volta o estado para "não carregando", mesmo se der erro
      if (mounted) setState(() => _estaCarregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00796B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 40, 
                    backgroundColor: Color(0xFFE0F2F1), 
                    child: Icon(Icons.science, size: 50, color: Color(0xFF00796B))
                  ),
                  const SizedBox(height: 20),
                  const Text("MicrobioStock", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00796B))),
                  const Text("Acesso Restrito", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _loginController, 
                    enabled: !_estaCarregando, // Bloqueia digitação enquanto carrega
                    decoration: const InputDecoration(labelText: "Usuário", prefixIcon: Icon(Icons.person), border: OutlineInputBorder())
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _senhaController, 
                    obscureText: !_senhaVisivel, 
                    enabled: !_estaCarregando, // Bloqueia digitação enquanto carrega
                    decoration: InputDecoration(
                      labelText: "Senha", 
                      prefixIcon: const Icon(Icons.lock), 
                      border: const OutlineInputBorder(), 
                      suffixIcon: IconButton(
                        icon: Icon(_senhaVisivel ? Icons.visibility : Icons.visibility_off), 
                        onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel)
                      )
                    )
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, 
                    height: 50, 
                    child: _estaCarregando 
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00796B))) // Mostra o spinner
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B), 
                            foregroundColor: Colors.white
                          ), 
                          onPressed: _entrar, 
                          child: const Text("ACESSAR SISTEMA", style: TextStyle(fontSize: 16))
                        )
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}