import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../services/api_service.dart';
import 'venda_screen.dart';
import 'relatorio_screen.dart';
import '../main.dart';

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
  final String _pinAutorizado = "2024";

  final ValueNotifier<DateTime> dataSelecionadaNotifier = ValueNotifier(
    DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _carregarDadosBase();
    dataSelecionadaNotifier.addListener(_carregarVendasDaData);
  }

  @override
  void dispose() {
    dataSelecionadaNotifier.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosBase() async {
    final db = await DBHelper().database;
    final clis = await db.query('clientes');
    for (var c in clis) {
      clientesMap[c['id'] as int] = c['nome'] as String;
    }
    _carregarVendasDaData();
  }

  Future<void> _carregarVendasDaData() async {
    setState(() => isLoading = true);
    final db = await DBHelper().database;

    String dataFormatada = DateFormat(
      'yyyy-MM-dd',
    ).format(dataSelecionadaNotifier.value);

    final vends = await db.query(
      'vendas',
      where: 'substr(data_venda, 1, 10) = ?',
      whereArgs: [dataFormatada],
      orderBy: 'id DESC',
    );

    setState(() {
      vendas = vends;
      isLoading = false;
    });
  }

  void _selecionarData(BuildContext context) async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: dataSelecionadaNotifier.value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida != null && escolhida != dataSelecionadaNotifier.value) {
      dataSelecionadaNotifier.value = escolhida;
    }
  }

  // --- SISTEMA DE SEGURANÇA LOCAL (PIN) ---
  Future<bool> _solicitarPinAcesso() async {
    String pinDigitado = "";

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 48,
                          color: Colors.blueGrey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Acesso Restrito",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Digite o PIN para Autorizar",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  content: SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index < pinDigitado.length
                                      ? Colors.blue
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: Colors.blue,
                                    width: 2,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: List.generate(12, (index) {
                            String tecla;
                            if (index == 9)
                              tecla = "C";
                            else if (index == 10)
                              tecla = "0";
                            else if (index == 11)
                              tecla = "<";
                            else
                              tecla = "${index + 1}";

                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  if (tecla == "C") {
                                    pinDigitado = "";
                                  } else if (tecla == "<") {
                                    if (pinDigitado.isNotEmpty) {
                                      pinDigitado = pinDigitado.substring(
                                        0,
                                        pinDigitado.length - 1,
                                      );
                                    }
                                  } else if (pinDigitado.length < 4) {
                                    pinDigitado += tecla;
                                    if (pinDigitado.length == 4) {
                                      if (pinDigitado == _pinAutorizado) {
                                        Navigator.pop(ctx, true);
                                      } else {
                                        pinDigitado = "";
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text("PIN Incorreto!"),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                });
                              },
                              child: Container(
                                width: 70,
                                height: 70,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: tecla == "C" || tecla == "<"
                                      ? Colors.grey.withOpacity(0.2)
                                      : Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: tecla == "<"
                                    ? const Icon(
                                        Icons.backspace_outlined,
                                        size: 28,
                                      )
                                    : Text(
                                        tecla,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text(
                        "CANCELAR",
                        style: TextStyle(color: Colors.red, fontSize: 18),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  // --- FUNÇÕES DE SINCRONIZAÇÃO PROTEGIDAS ---
  void _sincronizarTodasProtegido() async {
    bool autorizado = await _solicitarPinAcesso();
    if (!autorizado) return;

    setState(() => isSyncing = true);
    int qtd = await ApiService.enviarVendasPendentes();
    setState(() => isSyncing = false);

    if (qtd > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$qtd nota(s) enviada(s) com sucesso!"),
            backgroundColor: Colors.green,
          ),
        );
      }
      _carregarVendasDaData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nenhuma nota pendente ou sem conexão."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _sincronizarUnicaProtegida(Map<String, dynamic> venda) async {
    bool autorizado = await _solicitarPinAcesso();
    if (!autorizado) return;

    setState(() => isSyncing = true);
    bool sucesso = await ApiService.enviarVendaUnica(venda['id']);
    setState(() => isSyncing = false);

    if (sucesso) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nota sincronizada individualmente!"),
            backgroundColor: Colors.green,
          ),
        );
      }
      _carregarVendasDaData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erro ao enviar. Tente novamente."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _excluirNotaComProtecao(int idVenda) async {
    bool autorizado = await _solicitarPinAcesso();
    if (!autorizado) return;

    final db = await DBHelper().database;
    await db.delete('venda_itens', where: 'venda_id = ?', whereArgs: [idVenda]);
    await db.delete('vendas', where: 'id = ?', whereArgs: [idVenda]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nota excluída localmente!"),
          backgroundColor: Colors.red,
        ),
      );
    }
    _carregarVendasDaData();
  }

  void _mostrarOpcoesVenda(Map<String, dynamic> venda) {
    final bool isPendente = venda['status_sincronizacao'] == 'pendente';

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Nota ${venda['numero_nota']}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 32),
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
                    if (atualizou == true) _carregarVendasDaData();
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
                    style: TextStyle(color: Colors.green, fontSize: 18),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _sincronizarUnicaProtegida(venda);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever,
                    color: Colors.red,
                    size: 32,
                  ),
                  title: const Text(
                    "Excluir",
                    style: TextStyle(color: Colors.red, fontSize: 18),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _excluirNotaComProtecao(venda['id']);
                  },
                ),
              ] else ...[
                const Icon(Icons.verified_user, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                const Text(
                  "Esta nota já foi transmitida ao ERP.\nPara alterações, contate o escritório.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.print),
                    label: const Text("REIMPRIMIR TALÃO"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primaryColor),
            child: const SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.local_shipping, size: 48, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    "Operador de Rota",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Tablet: TB-Logistica-01",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Forçar Sincronização Base'),
            subtitle: const Text('Atualizar Produtos e Clientes'),
            onTap: () async {
              Navigator.pop(context);
              bool autorizado = await _solicitarPinAcesso();
              if (autorizado) {
                setState(() => isSyncing = true);
                await ApiService.sincronizarDados();
                setState(() => isSyncing = false);
                _carregarDadosBase();
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1),
            title: const Text('Cadastro de Emergência'),
            subtitle: const Text('Novo Cliente Offline'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Módulo de Relatórios'),
            subtitle: const Text('Romaneios e Fechamento'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RelatorioScreen(
                    dataRelatorio: dataSelecionadaNotifier.value,
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sair', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text('Boi Delivery'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) {
              return IconButton(
                icon: Icon(
                  mode == ThemeMode.light ? Icons.dark_mode : Icons.light_mode,
                ),
                onPressed: () => themeNotifier.value = mode == ThemeMode.light
                    ? ThemeMode.dark
                    : ThemeMode.light,
              );
            },
          ),
          isSyncing
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.amber,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.cloud_upload,
                    color: Colors.amber,
                    size: 28,
                  ),
                  onPressed: _sincronizarTodasProtegido,
                  tooltip: "Enviar Vendas Pendentes",
                ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ValueListenableBuilder<DateTime>(
                  valueListenable: dataSelecionadaNotifier,
                  builder: (context, data, _) {
                    final bool isHoje =
                        DateFormat('yyyy-MM-dd').format(data) ==
                        DateFormat('yyyy-MM-dd').format(DateTime.now());
                    return Text(
                      isHoje
                          ? "Vendas de Hoje"
                          : "Vendas de ${DateFormat('dd/MM/yyyy').format(data)}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () => _selecionarData(context),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text("PERÍODO"),
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : vendas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          "Nenhuma venda nesta data.",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: vendas.length,
                    itemBuilder: (context, index) {
                      final venda = vendas[index];
                      final isPendente =
                          venda['status_sincronizacao'] == 'pendente';
                      return Card(
                        child: InkWell(
                          onTap: () => _mostrarOpcoesVenda(venda),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        clientesMap[venda['cliente_id']] ??
                                            'Cliente Desconhecido',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isPendente
                                            ? Colors.orange.withOpacity(0.2)
                                            : Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isPendente
                                                ? Icons.cloud_off
                                                : Icons.cloud_done,
                                            size: 16,
                                            color: isPendente
                                                ? Colors.orange
                                                : Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isPendente ? "PENDENTE" : "ENVIADO",
                                            style: TextStyle(
                                              color: isPendente
                                                  ? Colors.orange
                                                  : Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Nota: ${venda['numero_nota']}",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "R\$ ${(venda['valor_total'] as num).toStringAsFixed(2).replaceAll('.', ',')}",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final atualizou = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VendaScreen()),
          );
          if (atualizou == true) _carregarVendasDaData();
        },
        icon: const Icon(Icons.add),
        label: const Text("NOVA VENDA"),
      ),
    );
  }
}
