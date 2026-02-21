import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/insumo_model.dart';
import 'storage_service.dart';

class FormularioView extends StatefulWidget {
  const FormularioView({super.key});

  @override
  State<FormularioView> createState() => _FormularioViewState();
}

class _FormularioViewState extends State<FormularioView> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storage = StorageService();

  // Controladores de texto para ler o que você digita
  final _nomeController = TextEditingController();
  final _loteController = TextEditingController();
  final _fabricanteController = TextEditingController();
  final _quantidadeController = TextEditingController();
  
  DateTime? _dataValidadeSelecionada;

  // Função para abrir o calendário nativo do celular
  Future<void> _selecionarData() async {
    final dataEscolhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), // Impede de cadastrar algo que já venceu hoje
      lastDate: DateTime(2035),
    );

    if (dataEscolhida != null) {
      setState(() {
        _dataValidadeSelecionada = dataEscolhida;
      });
    }
  }

  // Função para salvar no banco de dados e voltar
  Future<void> _salvar() async {
    if (_formKey.currentState!.validate() && _dataValidadeSelecionada != null) {
      final novoInsumo = Insumo(
        nome: _nomeController.text,
        lote: _loteController.text,
        fabricante: _fabricanteController.text,
        quantidade: int.parse(_quantidadeController.text),
        dataValidade: _dataValidadeSelecionada!,
      );

      await _storage.salvarInsumo(novoInsumo);
      
      if (mounted) {
        Navigator.pop(context, true); // Volta para a tela principal
      }
    } else if (_dataValidadeSelecionada == null) {
      // Alerta se esquecer de colocar a validade
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione a data de validade.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Insumo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00796B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Reagente / Meio de Cultura', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _loteController,
                      decoration: const InputDecoration(labelText: 'Lote', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _quantidadeController,
                      decoration: const InputDecoration(labelText: 'Qtd', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? '?' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _fabricanteController,
                decoration: const InputDecoration(labelText: 'Fabricante', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 15),
              // Botão gigante do Calendário
              InkWell(
                onTap: _selecionarData,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data de Validade', border: OutlineInputBorder()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dataValidadeSelecionada == null 
                            ? 'Toque para abrir o calendário' 
                            : DateFormat('dd/MM/yyyy').format(_dataValidadeSelecionada!),
                        style: TextStyle(fontSize: 16, color: _dataValidadeSelecionada == null ? Colors.grey[600] : Colors.black),
                      ),
                      const Icon(Icons.calendar_today, color: Color(0xFF00796B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _salvar,
                child: const Text('SALVAR NO ESTOQUE', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}