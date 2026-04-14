import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../services/api_service.dart';
import 'venda_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> vendas = [];
  Map<int, String> clientesMap = {};
  bool isLoading = true;
  bool isSyncing = false;

  // A Senha Master para o motorista excluir notas (Você pode mudar depois)
  final String senhaExclusao = "1234";

  @override
  void initState() {
    super.initState();
    _carregarVendas();
  }

  Future<void> _carregarVendas() async {
    final db = await DBHelper().database;
    final clis = await db.query('clientes');
    for (var c in clis) {
      clientesMap[c['id'] as int] = c['nome'] as String;
    }
    final vends = await db.query('vendas', orderBy: 'id DESC');
    setState(() {
      vendas = vends;
      isLoading = false;
    });
  }

  // --- 1. SINCRONIZAÇÃO GLOBAL (Botão da Nuvem) ---
  void _sincronizarTodas() async {
    setState(() => isSyncing = true);
    int qtd = await ApiService.enviarVendasPendentes();
    setState(() => isSyncing = false);

    if (qtd > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$qtd nota(s) enviada(s)!"),
          backgroundColor: Colors.green,
        ),
      );
      _carregarVendas();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nenhuma nota pendente ou sem internet."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // --- 2. SINCRONIZAÇÃO INDIVIDUAL ---
  void _sincronizarUnica(Map<String, dynamic> venda) async {
    Navigator.pop(context); // Fecha o menu de opções

    // Mostra um loading rápido na tela
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    bool sucesso = await ApiService.enviarVendaUnica(venda['id']);

    Navigator.pop(context); // Fecha o loading

    if (sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Nota ${venda['numero_nota']} enviada com sucesso!"),
          backgroundColor: Colors.green,
        ),
      );
      _carregarVendas();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro ao enviar. Verifique a internet."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- 3. EXCLUSÃO COM SENHA ---
  void _pedirSenhaParaExcluir(int vendaId) {
    Navigator.pop(context); // Fecha o menu de opções
    TextEditingController senhaCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Exigência de Segurança",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Digite a senha do supervisor para excluir esta nota:"),
            const SizedBox(height: 16),
            TextField(
              controller: senhaCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Senha",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (senhaCtrl.text == senhaExclusao) {
                Navigator.pop(ctx);
                final db = await DBHelper().database;
                await db.delete(
                  'venda_itens',
                  where: 'venda_id = ?',
                  whereArgs: [vendaId],
                ); // Deleta itens
                await db.delete(
                  'vendas',
                  where: 'id = ?',
                  whereArgs: [vendaId],
                ); // Deleta capa
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Nota excluída permanentemente!"),
                    backgroundColor: Colors.red,
                  ),
                );
                _carregarVendas();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Senha incorreta!"),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text("EXCLUIR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 4. MENU INTELIGENTE AO TOCAR NO CARTÃO ---
  void _mostrarOpcoesVenda(Map<String, dynamic> venda) {
    final bool isPendente = venda['status_sincronizacao'] == 'pendente';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Opções: Nota ${venda['numero_nota']}",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 32),

            // Se for pendente, permite Editar, Sincronizar e Excluir
            if (isPendente) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue, size: 32),
                title: const Text(
                  "Editar Nota",
                  style: TextStyle(fontSize: 18),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final atualizou = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VendaScreen(vendaEdicao: venda),
                    ),
                  );
                  if (atualizou == true) _carregarVendas();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.cloud_upload,
                  color: Colors.green,
                  size: 32,
                ),
                title: const Text(
                  "Sincronizar Esta Nota",
                  style: TextStyle(fontSize: 18),
                ),
                onTap: () => _sincronizarUnica(venda),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                  size: 32,
                ),
                title: const Text(
                  "Excluir Nota",
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
                onTap: () => _pedirSenhaParaExcluir(venda['id']),
              ),
            ]
            // Se já foi enviada, só permite ver detalhes para não corromper o ERP
            else ...[
              const Icon(Icons.verified_user, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text(
                "Esta nota já foi enviada para o escritório e não pode ser alterada pelo aplicativo.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Vendas do Dia',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          isSyncing
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Colors.amber),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.cloud_upload,
                    size: 32,
                    color: Colors.amber,
                  ),
                  onPressed: _sincronizarTodas,
                  tooltip: "Enviar Todas as Pendentes",
                ),
          const SizedBox(width: 16),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : vendas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "Nenhuma venda registrada hoje",
                    style: TextStyle(fontSize: 20, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vendas.length,
              itemBuilder: (context, index) {
                final venda = vendas[index];
                final isPendente = venda['status_sincronizacao'] == 'pendente';

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () =>
                        _mostrarOpcoesVenda(venda), // Chama o Menu Inteligente!
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  clientesMap[venda['cliente_id']] ??
                                      'Desconhecido',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isPendente
                                      ? Colors.orange[100]
                                      : Colors.green[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isPendente ? "NÃO ENVIADA" : "SINC. OK",
                                  style: TextStyle(
                                    color: isPendente
                                        ? Colors.orange[800]
                                        : Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, thickness: 1.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Nota: ${venda['numero_nota']}",
                                    style: const TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Data: ${venda['data_venda'].toString().substring(0, 10).split('-').reversed.join('/')}",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "R\$ ${(venda['valor_total'] as num).toStringAsFixed(2).replaceAll('.', ',')}",
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final atualizou = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VendaScreen()),
          );
          if (atualizou == true) _carregarVendas();
        },
        backgroundColor: Colors.blue[700],
        icon: const Icon(Icons.add, size: 32, color: Colors.white),
        label: const Text(
          "NOVA VENDA",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
