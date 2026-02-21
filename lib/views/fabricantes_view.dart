import 'package:flutter/material.dart';
import 'package:microbiostock/services/storage_service.dart';

class FabricantesView extends StatefulWidget {
  const FabricantesView({super.key});

  @override
  State<FabricantesView> createState() => _FabricantesViewState();
}

class _FabricantesViewState extends State<FabricantesView> {
  final StorageService _storage = StorageService();
  List<String> _fabricantes = [];

  @override
  void initState() {
    super.initState();
    _carregarFabricantes();
  }

  Future<void> _carregarFabricantes() async {
    final fabs = await _storage.obterFabricantes();
    setState(() {
      _fabricantes = fabs;
    });
  }

  // Abre uma janelinha para digitar o nome do novo fabricante
  void _abrirDialogoNovoFabricante() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Novo Fabricante"),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words, // Força a 1ª letra maiúscula
          decoration: const InputDecoration(
            labelText: "Nome da Marca / Fabricante",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.factory),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _storage.salvarFabricante(controller.text);
                _carregarFabricantes(); // Atualiza a lista na hora
                if (mounted) Navigator.pop(ctx); // Fecha a janelinha
              }
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
        title: const Text("Gerenciar Fabricantes", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF00796B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _fabricantes.isEmpty
          ? const Center(child: Text("Nenhum fabricante cadastrado ainda.", style: TextStyle(color: Colors.grey, fontSize: 16)))
          : ListView.builder(
              itemCount: _fabricantes.length,
              itemBuilder: (context, index) {
                final fab = _fabricantes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 1,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2F1), // Verde bem clarinho
                      child: Icon(Icons.factory, color: Color(0xFF00796B)),
                    ),
                    title: Text(fab, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        // Confirmação antes de excluir
                        bool? confirmar = await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Excluir?"),
                            content: Text("Deseja excluir o fabricante '$fab' da sua lista?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text("Excluir", style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirmar == true) {
                          await _storage.deletarFabricante(fab);
                          _carregarFabricantes();
                        }
                      },
                    ),
                  ),
                );
              },
            ),
      // Botão flutuante para adicionar
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00796B),
        onPressed: _abrirDialogoNovoFabricante,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}