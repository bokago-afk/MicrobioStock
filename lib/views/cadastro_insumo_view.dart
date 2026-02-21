import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:microbiostock/models/insumo_model.dart';
import 'package:microbiostock/models/historico_model.dart';
import 'package:microbiostock/services/storage_service.dart';

class CadastroInsumoView extends StatefulWidget {
  // Parâmetro de Edição: Se vier preenchido, a tela entra no modo "Editar"
  final Insumo? insumoParaEditar;

  const CadastroInsumoView({super.key, this.insumoParaEditar});

  @override
  State<CadastroInsumoView> createState() => _CadastroInsumoViewState();
}

class _CadastroInsumoViewState extends State<CadastroInsumoView> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _loteController = TextEditingController();
  final _fabricanteController = TextEditingController();
  final _qtdController = TextEditingController();
  final _estoqueMinimoController = TextEditingController(); 
  
  DateTime? _dataValidade;
  String? _caminhoPdfSelecionado; 
  bool _carregando = false; // RESTAURADO: Controle de loading
  
  final StorageService _storage = StorageService();
  List<String> _fabricantesSalvos = [];

  bool get isEdicao => widget.insumoParaEditar != null;

  @override
  void initState() {
    super.initState();
    _carregarFabricantes();

    // Lógica de Edição: Preenchemos os campos com os dados antigos
    if (isEdicao) {
      _nomeController.text = widget.insumoParaEditar!.nome;
      _loteController.text = widget.insumoParaEditar!.lote;
      _fabricanteController.text = widget.insumoParaEditar!.fabricante;
      _qtdController.text = widget.insumoParaEditar!.quantidade.toString();
      _estoqueMinimoController.text = widget.insumoParaEditar!.estoqueMinimo.toString();
      _dataValidade = widget.insumoParaEditar!.dataValidade;
      _caminhoPdfSelecionado = widget.insumoParaEditar!.caminhoPdf;
    }
  }

  Future<void> _carregarFabricantes() async {
    final fabs = await _storage.obterFabricantes();
    if (mounted) {
      setState(() {
        _fabricantesSalvos = fabs;
      });
    }
  }

  Future<void> _selecionarData() async {
    final dataEscolhida = await showDatePicker(
      context: context,
      initialDate: _dataValidade ?? DateTime.now(),
      firstDate: DateTime(2000), 
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF00796B))),
          child: child!,
        );
      },
    );

    if (dataEscolhida != null) {
      setState(() {
        _dataValidade = dataEscolhida;
      });
    }
  }

  Future<void> _anexarPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      File arquivoOriginal = File(result.files.single.path!);
      final diretorioApp = await getApplicationDocumentsDirectory();
      String nomeArquivo = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(arquivoOriginal.path)}';
      String novoCaminho = path.join(diretorioApp.path, nomeArquivo);

      await arquivoOriginal.copy(novoCaminho);

      setState(() {
        _caminhoPdfSelecionado = novoCaminho;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento anexado com sucesso!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  void _salvar() async {
    if (!_formKey.currentState!.validate()) return; 

    if (_dataValidade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Por favor, escolha a data de validade!'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_fabricanteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O Fabricante é obrigatório.'), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _carregando = true); // Ativa o loading

    try {
      int qtd = int.tryParse(_qtdController.text) ?? 0;
      int estoqueMin = int.tryParse(_estoqueMinimoController.text) ?? 0;

      final usuarioLogado = await _storage.obterUsuarioLogado();
      final nomeOperador = usuarioLogado?.nome ?? "Sistema";

      final insumoSalvo = Insumo(
        id: widget.insumoParaEditar?.id, // Mantém o ID se for edição
        nome: _nomeController.text.trim(),
        lote: _loteController.text.trim(),
        fabricante: _fabricanteController.text.trim(),
        quantidade: qtd,
        estoqueMinimo: estoqueMin, 
        dataValidade: _dataValidade!,
        caminhoPdf: _caminhoPdfSelecionado, 
      );

      await _storage.salvarInsumo(insumoSalvo);
      
      await _storage.registrarMovimentacao(Historico(
        nomeInsumo: insumoSalvo.nome,
        lote: insumoSalvo.lote,
        quantidade: qtd.toDouble(),
        tipo: isEdicao ? "Edição de Cadastro" : "Entrada Inicial",
        dataHora: DateTime.now(),
        usuario: nomeOperador,
      ));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdicao ? "Cadastro atualizado com sucesso!" : "Insumo cadastrado com sucesso!"), 
            backgroundColor: Colors.green
          )
        );
        Navigator.pop(context, true); 
      }
    } catch (erro) {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $erro'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // RESTAURADO: Fundo leve
      appBar: AppBar(
        title: Text(isEdicao ? "Editar Material" : "Novo Material", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00796B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _carregando // RESTAURADO: Indicador de loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SESSÃO 1: DADOS PRINCIPAIS ---
                    const Text("Dados do Reagente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                    const SizedBox(height: 15),
                    
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(labelText: "Nome do Reagente", border: OutlineInputBorder(), prefixIcon: Icon(Icons.science)),
                      validator: (value) => value == null || value.isEmpty ? "Campo obrigatório" : null,
                    ),
                    const SizedBox(height: 15),
                    
                    TextFormField(
                      controller: _loteController,
                      decoration: const InputDecoration(labelText: "Nº do Lote", border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code)),
                      validator: (value) => value == null || value.isEmpty ? "Informe o lote" : null,
                    ),
                    const SizedBox(height: 15),

                    LayoutBuilder(
                      builder: (context, constraints) => Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) return _fabricantesSalvos;
                          return _fabricantesSalvos.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          if (isEdicao && controller.text.isEmpty) {
                            controller.text = _fabricanteController.text;
                          }
                          controller.addListener(() {
                            _fabricanteController.text = controller.text;
                          });
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: "Fabricante",
                              hintText: "Selecione ou digite...",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.factory),
                            ),
                            validator: (value) => value == null || value.isEmpty ? "Campo obrigatório" : null,
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: constraints.maxWidth,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final String option = options.elementAt(index);
                                    return ListTile(title: Text(option), onTap: () => onSelected(option));
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // --- SESSÃO 2: CONTROLE DE ESTOQUE ---
                    const Text("Controle de Estoque", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                    const SizedBox(height: 15),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtdController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: "Qtd. Atual", border: OutlineInputBorder(), prefixIcon: Icon(Icons.add_box)),
                            validator: (value) {
                              if (value == null || value.isEmpty) return "Obrigatório";
                              if (int.tryParse(value) == null) return "Apenas Nº";
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: TextFormField(
                            controller: _estoqueMinimoController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Mínimo (Alerta)", 
                              border: OutlineInputBorder(), 
                              prefixIcon: Icon(Icons.warning_amber),
                              helperText: "Alerta de compra",
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return "Obrigatório";
                              if (int.tryParse(value) == null) return "Apenas Nº";
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // --- SESSÃO 3: VALIDADE E DOCUMENTAÇÃO ---
                    const Text("Validade e Documentação", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                    const SizedBox(height: 15),

                    // RESTAURADO: Botão de data estilizado
                    InkWell(
                      onTap: _selecionarData,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4), color: Colors.white),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.grey),
                            const SizedBox(width: 10),
                            Text(
                              _dataValidade == null ? "Selecionar Data de Validade *" : "Validade: ${DateFormat('dd/MM/yyyy').format(_dataValidade!)}",
                              style: TextStyle(fontSize: 16, color: _dataValidade == null ? Colors.black54 : Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // RESTAURADO: Botão de PDF estilizado
                    InkWell(
                      onTap: _anexarPdf,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(
                          border: Border.all(color: _caminhoPdfSelecionado == null ? Colors.grey : const Color(0xFF00796B)), 
                          borderRadius: BorderRadius.circular(4), 
                          color: _caminhoPdfSelecionado == null ? Colors.white : const Color(0xFFE0F2F1)
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf, color: _caminhoPdfSelecionado == null ? Colors.grey : const Color(0xFF00796B)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _caminhoPdfSelecionado == null ? "Anexar Nota / Certificado (Opcional)" : "PDF Anexado com Sucesso!",
                                style: TextStyle(fontSize: 16, color: _caminhoPdfSelecionado == null ? Colors.black54 : const Color(0xFF00796B), fontWeight: _caminhoPdfSelecionado == null ? FontWeight.normal : FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                    
                    // RESTAURADO: Botão de Salvar Robusto
                    SizedBox(
                      width: double.infinity,
                      height: 55, // Altura confortável para o toque
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B), 
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        onPressed: _salvar,
                        child: Text(isEdicao ? "ATUALIZAR CADASTRO" : "SALVAR INSUMO", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}