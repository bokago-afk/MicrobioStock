import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart'; // Para abrir o PDF anexado
import 'package:microbiostock/models/insumo_model.dart';
import 'package:microbiostock/models/historico_model.dart';
import 'package:microbiostock/services/storage_service.dart';
// IMPORTANTE: Importamos a tela de cadastro para o botão Editar
import 'package:microbiostock/views/cadastro_insumo_view.dart';

// --- NOVAS IMPORTAÇÕES PARA GERAR O PDF E QR CODE ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DetalhesInsumoView extends StatefulWidget {
  final Insumo insumo;

  const DetalhesInsumoView({super.key, required this.insumo});

  @override
  State<DetalhesInsumoView> createState() => _DetalhesInsumoViewState();
}

class _DetalhesInsumoViewState extends State<DetalhesInsumoView> {
  final StorageService _storage = StorageService();
  late Insumo _insumo;

  @override
  void initState() {
    super.initState();
    _insumo = widget.insumo;
  }

  // --- LÓGICA DE MOVIMENTAÇÃO (CORRIGIDA COM .toDouble()) ---
  void _processarMovimentacao(int qtdInformada, bool ehEntrada) async {
    final usuarioLogado = await _storage.obterUsuarioLogado();
    final nomeOperador = usuarioLogado?.nome ?? "Sistema";

    // O erro acontecia aqui: convertendo int para double explicitamente
    final novaMovimentacao = Historico(
      nomeInsumo: _insumo.nome,
      lote: _insumo.lote,
      quantidade: qtdInformada.toDouble(), // <--- CORREÇÃO DO ERRO AQUI
      tipo: ehEntrada ? "Entrada" : "Saída",
      dataHora: DateTime.now(),
      usuario: nomeOperador,
    );

    int novaQtd = ehEntrada 
        ? _insumo.quantidade + qtdInformada 
        : _insumo.quantidade - qtdInformada;

    if (novaQtd < 0) novaQtd = 0;

    // Criando a cópia atualizada do Insumo
    final insumoAtualizado = Insumo(
      id: _insumo.id,
      nome: _insumo.nome,
      lote: _insumo.lote,
      dataValidade: _insumo.dataValidade,
      quantidade: novaQtd,
      estoqueMinimo: _insumo.estoqueMinimo,
      fabricante: _insumo.fabricante,
      caminhoPdf: _insumo.caminhoPdf,
    );

    await _storage.salvarInsumo(insumoAtualizado);
    await _storage.registrarMovimentacao(novaMovimentacao);

    if (mounted) {
      setState(() {
        _insumo = insumoAtualizado;
      });
      Navigator.pop(context); // Fecha o diálogo de input
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Estoque atualizado por $nomeOperador"), 
          backgroundColor: Colors.green
        ),
      );
    }
  }

  void _abrirDialogoAjuste(bool ehEntrada) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(ehEntrada ? "Entrada de Estoque" : "Baixa de Estoque"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Quantidade",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancelar")
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
            onPressed: () {
              int? valor = int.tryParse(controller.text);
              if (valor != null && valor > 0) {
                _processarMovimentacao(valor, ehEntrada);
              }
            },
            child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- NOVA FUNÇÃO: GERAR ETIQUETA QR CODE ---
  Future<void> _imprimirEtiqueta() async {
    final pdf = pw.Document();
    
    // Tamanho padrão de etiqueta de laboratório/farmácia: 60mm x 40mm
    final formatoEtiqueta = PdfPageFormat(60 * PdfPageFormat.mm, 40 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: formatoEtiqueta,
        build: (pw.Context context) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Lado Esquerdo: Textos da Etiqueta
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text("MicrobioStock", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text(_insumo.nome, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text("Lote: ${_insumo.lote}", style: const pw.TextStyle(fontSize: 8)),
                    pw.Text("Val: ${DateFormat('dd/MM/yyyy').format(_insumo.dataValidade)}", style: const pw.TextStyle(fontSize: 8)),
                  ]
                )
              ),
              // Lado Direito: QR Code gerado nativamente
              pw.Container(
                height: 30 * PdfPageFormat.mm,
                width: 30 * PdfPageFormat.mm,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  // O dado que o QR Code vai armazenar
                  data: _insumo.id ?? _insumo.lote,
                  drawText: false,
                )
              )
            ]
          );
        }
      )
    );

    // Abre a tela de impressão do celular
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Etiqueta_${_insumo.nome}.pdf'
    );
  }

  // --- FUNÇÕES DE STATUS (DESIGN ORIGINAL) ---
  String _statusValidade() {
    final hoje = DateTime.now();
    final diferenca = _insumo.dataValidade.difference(hoje).inDays;
    if (_insumo.dataValidade.isBefore(hoje)) return "VENCIDO";
    if (diferenca <= 30) return "Vence em $diferenca dias";
    return "Válido";
  }

  Color _corStatus() {
    final hoje = DateTime.now();
    final diferenca = _insumo.dataValidade.difference(hoje).inDays;
    if (_insumo.dataValidade.isBefore(hoje)) return Colors.red;
    if (diferenca <= 30) return Colors.orange;
    return Colors.green;
  }

  void _abrirPdf(BuildContext context) {
    if (_insumo.caminhoPdf != null) {
      OpenFilex.open(_insumo.caminhoPdf!).then((result) {
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erro ao abrir PDF: ${result.message}"), 
              backgroundColor: Colors.red
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool estoqueBaixo = _insumo.quantidade <= _insumo.estoqueMinimo;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalhes do Lote", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF00796B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // --- NOVO: BOTÃO DE IMPRIMIR ETIQUETA QR CODE ---
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: Colors.white),
            tooltip: "Imprimir Etiqueta",
            onPressed: _imprimirEtiqueta,
          ),
          // --- BOTÃO DE EDITAR (PRESERVADO) ---
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: "Editar Cadastro",
            onPressed: () async {
              final editou = await Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => CadastroInsumoView(insumoParaEditar: _insumo)
                )
              );
              
              if (editou == true) {
                // Se o usuário salvar a edição, recarrega o insumo do banco
                final insumosAtualizados = await _storage.obterInsumos();
                final insumoRecarregado = insumosAtualizados.firstWhere((i) => i.id == _insumo.id);
                setState(() {
                  _insumo = insumoRecarregado;
                });
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // --- ALERTA VISUAL DE ESTOQUE BAIXO (PRESERVADO) ---
            if (estoqueBaixo)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red[50], 
                  borderRadius: BorderRadius.circular(10), 
                  border: Border.all(color: Colors.red, width: 2)
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        "ALERTA: Estoque Crítico!\nO nível está abaixo ou igual ao mínimo de segurança (${_insumo.estoqueMinimo} un).", 
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)
                      )
                    ),
                  ],
                ),
              ),

            // CARTÃO DE CABEÇALHO (PRESERVADO)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2), 
                    blurRadius: 10, 
                    offset: const Offset(0, 5)
                  )
                ],
                border: Border(left: BorderSide(color: _corStatus(), width: 6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _insumo.nome, 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF004D40))
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _corStatus().withOpacity(0.1), 
                          borderRadius: BorderRadius.circular(20)
                        ),
                        child: Text(
                          _statusValidade(), 
                          style: TextStyle(color: _corStatus(), fontWeight: FontWeight.bold)
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${_insumo.quantidade} un.", 
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w900, 
                          color: estoqueBaixo ? Colors.red : const Color(0xFF00796B)
                        )
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // BOTÕES DE AÇÃO (PRESERVADO)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _abrirDialogoAjuste(true),
                    icon: const Icon(Icons.add),
                    label: const Text("ENTRADA"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, 
                      foregroundColor: Colors.white, 
                      padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _abrirDialogoAjuste(false),
                    icon: const Icon(Icons.remove),
                    label: const Text("BAIXA"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, 
                      foregroundColor: Colors.white, 
                      padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // INFORMAÇÕES TÉCNICAS (PRESERVADO)
            const Text("Informações Técnicas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            _ItemDetalhe(icone: Icons.qr_code, titulo: "Lote", valor: _insumo.lote),
            _ItemDetalhe(icone: Icons.factory, titulo: "Fabricante", valor: _insumo.fabricante),
            _ItemDetalhe(icone: Icons.notifications_active, titulo: "Estoque Mínimo", valor: "${_insumo.estoqueMinimo} un."),
            _ItemDetalhe(icone: Icons.calendar_today, titulo: "Validade", valor: DateFormat('dd/MM/yyyy').format(_insumo.dataValidade)),

            const SizedBox(height: 30),

            // DOCUMENTAÇÃO PDF (PRESERVADO)
            const Text("Documentação", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            if (_insumo.caminhoPdf != null)
              InkWell(
                onTap: () => _abrirPdf(context),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1), 
                    borderRadius: BorderRadius.circular(10), 
                    border: Border.all(color: const Color(0xFF00796B))
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Color(0xFF00796B), size: 30),
                      SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          "Nota Fiscal / Certificado", 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))
                        )
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF00796B)),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(Icons.no_sim, color: Colors.grey[500]), 
                    const SizedBox(width: 10), 
                    Text("Nenhum documento anexado.", style: TextStyle(color: Colors.grey[600]))
                  ]
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// WIDGET DE ITEM (PRESERVADO)
class _ItemDetalhe extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String valor;
  const _ItemDetalhe({required this.icone, required this.titulo, required this.valor});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), 
        side: BorderSide(color: Colors.grey.shade200)
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE0F2F1), 
          child: Icon(icone, color: const Color(0xFF00796B), size: 20)
        ),
        title: Text(titulo, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        subtitle: Text(
          valor, 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)
        ),
      ),
    );
  }
}