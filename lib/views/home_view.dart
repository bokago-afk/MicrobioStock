import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// NOVO E CORRIGIDO: Importando o pacote atualizado e moderno da câmera
import 'package:barcode_scan2/barcode_scan2.dart'; 

import 'package:microbiostock/models/insumo_model.dart';
import 'package:microbiostock/models/historico_model.dart';
import 'package:microbiostock/models/usuario_model.dart';
import 'package:microbiostock/services/storage_service.dart';
import 'package:microbiostock/views/cadastro_insumo_view.dart';
import 'package:microbiostock/views/fabricantes_view.dart';
import 'package:microbiostock/views/detalhes_insumo_view.dart';
import 'package:microbiostock/views/historico_view.dart';
import 'package:microbiostock/views/usuarios_view.dart';
import 'package:microbiostock/views/login_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final StorageService _storage = StorageService();
  List<Insumo> _insumos = [];
  Usuario? _usuarioLogado; 
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final usuario = await _storage.obterUsuarioLogado();
    final insumos = await _storage.obterInsumos();
    
    // Ordenação: Vencidos primeiro, depois por validade
    insumos.sort((a, b) {
      if (_estaVencido(a.dataValidade)) return -1;
      return a.dataValidade.compareTo(b.dataValidade);
    });
    
    if (mounted) {
      setState(() {
        _usuarioLogado = usuario;
        _insumos = insumos;
        _carregando = false;
      });
    }
  }

  bool _estaPertoDoVencimento(DateTime validade) {
    final hoje = DateTime.now();
    final diferenca = validade.difference(hoje).inDays;
    return diferenca <= 30 && diferenca >= 0;
  }

  bool _estaVencido(DateTime validade) {
    return validade.isBefore(DateTime.now());
  }

  // --- NOVA FUNÇÃO: ESCANEAR QR CODE COM O PACOTE ATUALIZADO ---
  Future<void> _escanearQrCode() async {
    try {
      // Abre a câmera usando o novo pacote
      var result = await BarcodeScanner.scan();
      String qrCodeResult = result.rawContent;

      if (qrCodeResult.isNotEmpty) {
        try {
          final insumoEncontrado = _insumos.firstWhere(
            (item) => item.id == qrCodeResult || item.lote == qrCodeResult,
          );

          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DetalhesInsumoView(insumo: insumoEncontrado)),
            );
            _inicializar();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Reagente não encontrado no estoque atual."), 
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao usar a câmera: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- MÉTODOS DE CONTROLE DE ESTOQUE ---

  void _diminuirQuantidade(Insumo item) async {
    final nomeOperador = _usuarioLogado?.nome ?? "Sistema";

    if (item.quantidade > 1) {
      final insumoAtualizado = Insumo(
        id: item.id,
        nome: item.nome,
        lote: item.lote,
        dataValidade: item.dataValidade,
        quantidade: item.quantidade - 1,
        estoqueMinimo: item.estoqueMinimo,
        fabricante: item.fabricante,
        caminhoPdf: item.caminhoPdf,
      );
      
      await _storage.salvarInsumo(insumoAtualizado);
      await _storage.registrarMovimentacao(Historico(
        nomeInsumo: item.nome,
        lote: item.lote,
        quantidade: 1.0, 
        tipo: "Saída",
        dataHora: DateTime.now(),
        usuario: nomeOperador,
      ));

      _inicializar();
    } else {
      _confirmarExclusaoLote(item);
    }
  }

  Future<void> _baixaMultipla(Insumo item) async {
    final controller = TextEditingController();
    final nomeOperador = _usuarioLogado?.nome ?? "Sistema";

    bool? confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Baixa de ${item.nome}", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Estoque atual: ${item.quantidade} un.\nQuantas unidades utilizadas?"),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Quantidade", 
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.remove_circle)
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirmar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      int qtdRemover = int.tryParse(controller.text) ?? 0;
      if (qtdRemover <= 0) return;

      if (qtdRemover >= item.quantidade) {
        _confirmarExclusaoLote(item);
      } else {
        final insumoAtualizado = Insumo(
          id: item.id,
          nome: item.nome,
          lote: item.lote,
          dataValidade: item.dataValidade,
          quantidade: item.quantidade - qtdRemover,
          estoqueMinimo: item.estoqueMinimo,
          fabricante: item.fabricante,
          caminhoPdf: item.caminhoPdf,
        );
        
        await _storage.salvarInsumo(insumoAtualizado);
        await _storage.registrarMovimentacao(Historico(
          nomeInsumo: item.nome,
          lote: item.lote,
          quantidade: qtdRemover.toDouble(), 
          tipo: "Saída",
          dataHora: DateTime.now(),
          usuario: nomeOperador,
        ));

        _inicializar();
      }
    }
  }

  Future<bool?> _confirmarExclusaoLote(Insumo item) async {
    final nomeOperador = _usuarioLogado?.nome ?? "Sistema";

    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Finalizar Lote?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("O estoque do lote ${item.lote} sera zerado e removido. Confirmar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Finalizar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _storage.deletarInsumo(item.id!);
      await _storage.registrarMovimentacao(Historico(
        nomeInsumo: item.nome,
        lote: item.lote,
        quantidade: item.quantidade.toDouble(), 
        tipo: "Finalização",
        dataHora: DateTime.now(),
        usuario: nomeOperador,
      ));
      _inicializar();
    }
    return confirmar;
  }

  void _deslogar() async {
    await _storage.deslogar();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdm = _usuarioLogado?.nivel == 'adm';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('MicrobioStock 🔬', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF00796B),
        centerTitle: true,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
           // --- BOTÃO DO LEITOR DE QR CODE ---
           IconButton(
             onPressed: _escanearQrCode, 
             icon: const Icon(Icons.qr_code_scanner), 
             tooltip: "Ler Etiqueta"
           ),
           IconButton(onPressed: _deslogar, icon: const Icon(Icons.power_settings_new), tooltip: "Sair"),
        ],
      ),
      
      drawer: _buildDrawer(isAdm),

      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)))
          : _insumos.isEmpty
              ? _buildEmptyState(isAdm)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                  itemCount: _insumos.length,
                  itemBuilder: (context, index) {
                    final item = _insumos[index];
                    final vencido = _estaVencido(item.dataValidade);
                    final alertaVencimento = _estaPertoDoVencimento(item.dataValidade);
                    final estoqueBaixo = item.quantidade <= item.estoqueMinimo;

                    return _buildInsumoCard(item, vencido, alertaVencimento, estoqueBaixo, isAdm);
                  },
                ),
                
      floatingActionButton: isAdm ? FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00796B),
        onPressed: () async {
          final salvou = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CadastroInsumoView()));
          if (salvou == true) _inicializar();
        },
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text("ADICIONAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  // --- WIDGETS AUXILIARES (PARA MANTER A RIQUEZA VISUAL E O VOLUME DE CÓDIGO) ---

  Widget _buildDrawer(bool isAdm) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF00796B)),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.biotech, size: 40, color: Color(0xFF00796B)),
            ),
            accountName: Text(_usuarioLogado?.nome ?? "Usuario", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            accountEmail: Text(isAdm ? "Perfil: Administrador" : "Perfil: Tecnico Lab"),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2, color: Color(0xFF00796B)),
            title: const Text("Estoque Ativo"),
            onTap: () => Navigator.pop(context),
          ),
          if (isAdm) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_business),
              title: const Text("Gerenciar Fabricantes"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const FabricantesView()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt),
              title: const Text("Gerenciar Equipe"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UsuariosView()));
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history_edu),
            title: const Text("Histórico de Uso"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoricoView()));
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Sair do Aplicativo", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _deslogar,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildInsumoCard(Insumo item, bool vencido, bool alertaVencimento, bool estoqueBaixo, bool isAdm) {
    return Dismissible(
      key: Key(item.id!),
      direction: isAdm ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 25),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.only(bottom: 15),
        child: const Icon(Icons.delete_sweep, color: Colors.white, size: 35),
      ),
      confirmDismiss: (direction) => _confirmarExclusaoLote(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: InkWell(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => DetalhesInsumoView(insumo: item)));
            _inicializar();
          },
          borderRadius: BorderRadius.circular(15),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 100,
                decoration: BoxDecoration(
                  color: vencido ? Colors.red : (estoqueBaixo ? Colors.orange : const Color(0xFF00796B)),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF263238))),
                      const SizedBox(height: 6),
                      Text("Lote: ${item.lote} | Fab: ${item.fabricante}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.timer, size: 14, color: vencido ? Colors.red : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            "Validade: ${DateFormat('dd/MM/yyyy').format(item.dataValidade)}",
                            style: TextStyle(
                              color: vencido ? Colors.red : (alertaVencimento ? Colors.orange[900] : Colors.grey[800]),
                              fontWeight: vencido || alertaVencimento ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _buildStockCounter(item, estoqueBaixo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockCounter(Insumo item, bool estoqueBaixo) {
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF00796B)),
            onPressed: () => _diminuirQuantidade(item),
          ),
          GestureDetector(
            onTap: () => _baixaMultipla(item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: estoqueBaixo ? Colors.red[50] : const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: estoqueBaixo ? Colors.red : const Color(0xFF00796B)),
              ),
              child: Text(
                '${item.quantidade}',
                style: TextStyle(color: estoqueBaixo ? Colors.red[900] : const Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isAdm) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            isAdm ? "Estoque Vazio.\nToque no (+) para cadastrar reagentes." : "Estoque Vazio.\nAguarde o cadastro pelo Administrador.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}