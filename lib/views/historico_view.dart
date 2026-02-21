import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:microbiostock/models/historico_model.dart';
import 'package:microbiostock/services/storage_service.dart';
// PACOTES PARA IMPRESSÃO (PDF)
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HistoricoView extends StatefulWidget {
  const HistoricoView({super.key});

  @override
  State<HistoricoView> createState() => _HistoricoViewState();
}

class _HistoricoViewState extends State<HistoricoView> {
  final StorageService _storage = StorageService();
  
  // --- NOVAS VARIÁVEIS PARA O FILTRO ---
  List<Historico> _listaAgrupadaOriginal = []; // Guarda tudo
  List<Historico> _listaExibida = []; // Mostra na tela (filtrada)
  DateTime? _dataInicio;
  DateTime? _dataFim;
  
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final lista = await _storage.obterHistorico();
      List<Historico> agrupada = [];
      
      if (lista.isNotEmpty) {
        lista.sort((a, b) => b.dataHora.compareTo(a.dataHora));
        agrupada.add(lista.first);

        for (int i = 1; i < lista.length; i++) {
          final atual = lista[i];
          final ultimoAdicionado = agrupada.last;

          String dataAtual = DateFormat('yyyyMMdd').format(atual.dataHora);
          String dataUltimo = DateFormat('yyyyMMdd').format(ultimoAdicionado.dataHora);

          if (atual.nomeInsumo == ultimoAdicionado.nomeInsumo &&
              atual.lote == ultimoAdicionado.lote &&
              atual.tipo == ultimoAdicionado.tipo &&
              dataAtual == dataUltimo) {
            
            final novoItemSomado = Historico(
              nomeInsumo: ultimoAdicionado.nomeInsumo,
              lote: ultimoAdicionado.lote,
              quantidade: ultimoAdicionado.quantidade + atual.quantidade,
              tipo: ultimoAdicionado.tipo,
              dataHora: ultimoAdicionado.dataHora,
              usuario: ultimoAdicionado.usuario, // Mantém o usuário do grupo
            );
            
            agrupada[agrupada.length - 1] = novoItemSomado;
          } else {
            agrupada.add(atual);
          }
        }
      }

      if (mounted) {
        setState(() {
          _listaAgrupadaOriginal = agrupada;
          _listaExibida = agrupada; // Inicialmente, mostra tudo
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar dados: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- NOVA FUNÇÃO: SELECIONAR PERÍODO ---
  Future<void> _selecionarPeriodo() async {
    final DateTimeRange? selecionado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      helpText: 'SELECIONE O PERÍODO DO RELATÓRIO',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
      saveText: 'SALVAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00796B), 
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selecionado != null) {
      setState(() {
        _dataInicio = selecionado.start;
        // Ajusta para o último segundo do dia final
        _dataFim = DateTime(selecionado.end.year, selecionado.end.month, selecionado.end.day, 23, 59, 59);

        // Filtra a lista original para exibir apenas os itens do período
        _listaExibida = _listaAgrupadaOriginal.where((item) {
          return item.dataHora.isAfter(_dataInicio!.subtract(const Duration(seconds: 1))) &&
                 item.dataHora.isBefore(_dataFim!.add(const Duration(seconds: 1)));
        }).toList();
      });
    }
  }

  // --- NOVA FUNÇÃO: LIMPAR O FILTRO ---
  void _limparFiltro() {
    setState(() {
      _dataInicio = null;
      _dataFim = null;
      _listaExibida = List.from(_listaAgrupadaOriginal); // Volta a mostrar tudo
    });
  }

  // --- FUNÇÃO DE IMPRESSÃO ATUALIZADA PARA USAR A LISTA FILTRADA ---
  Future<void> _imprimirRelatorio() async {
    final pdf = pw.Document();
    final dataHoje = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    String subtitulo = "Todo o período";
    if (_dataInicio != null && _dataFim != null) {
      subtitulo = "Período filtrado: ${DateFormat('dd/MM/yyyy').format(_dataInicio!)} a ${DateFormat('dd/MM/yyyy').format(_dataFim!)}";
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Relatorio de Movimentacoes', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text('MicrobioStock', style: pw.TextStyle(fontSize: 15, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(subtitulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.Text('Gerado em: $dataHoje', style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 20),
            
            // TABELA DO PDF USANDO A LISTA EXIBIDA
            pw.Table.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              headers: ['Data', 'Insumo / Lote', 'Qtd.', 'Responsavel'],
              data: _listaExibida.map((item) {
                final data = DateFormat('dd/MM HH:mm').format(item.dataHora);
                final nomeLote = "${item.nomeInsumo}\n(${item.lote})";
                
                final ehEntradaPdf = item.tipo.toLowerCase().contains("entrada");
                final qtd = ehEntradaPdf ? "+${item.quantidade}" : "-${item.quantidade}";
                
                final responsavel = item.usuario; 
                return [data, nomeLote, qtd, responsavel];
              }).toList(),
            ),
            
            pw.SizedBox(height: 50),
            pw.Divider(indent: 100, endIndent: 100),
            pw.Center(child: pw.Text('Assinatura do Responsavel', style: const pw.TextStyle(fontSize: 10))),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Relatorio_${DateFormat('ddMMyyyy').format(DateTime.now())}.pdf'
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Histórico de Uso", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00796B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // --- NOVO BOTÃO: CALENDÁRIO ---
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: "Filtrar por data",
            onPressed: _selecionarPeriodo,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _listaExibida.isEmpty ? null : _imprimirRelatorio,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)))
          : Column(
              children: [
                // --- NOVA FAIXA DE FILTRO ATIVO ---
                if (_dataInicio != null && _dataFim != null)
                  Container(
                    color: const Color(0xFFE0F2F1),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt, color: Color(0xFF00796B), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Exibindo de ${DateFormat('dd/MM/yy').format(_dataInicio!)} a ${DateFormat('dd/MM/yy').format(_dataFim!)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                          ),
                        ),
                        InkWell(
                          onTap: _limparFiltro,
                          child: const Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Text("Limpar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    ),
                  ),

                // --- LISTA DE RESULTADOS USANDO A LISTA EXIBIDA ---
                Expanded(
                  child: _listaExibida.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 10, bottom: 20),
                          itemCount: _listaExibida.length,
                          itemBuilder: (context, index) {
                            final item = _listaExibida[index];
                            
                            final ehEntrada = item.tipo.toLowerCase().contains("entrada");

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: ehEntrada ? Colors.green[50] : Colors.red[50],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    ehEntrada ? Icons.add_circle_outline : Icons.remove_circle_outline,
                                    color: ehEntrada ? Colors.green[700] : Colors.red[700],
                                  ),
                                ),
                                title: Text(item.nomeInsumo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text("Lote: ${item.lote}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                    Text(DateFormat('dd/MM/yyyy • HH:mm').format(item.dataHora), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                    Text("Por: ${item.usuario}", style: const TextStyle(color: Color(0xFF00796B), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      ehEntrada ? "+${item.quantidade}" : "-${item.quantidade}",
                                      style: TextStyle(
                                        color: ehEntrada ? Colors.green[800] : Colors.red[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(item.tipo, style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text("Nenhuma movimentação encontrada.", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}