import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class VendaScreen extends StatefulWidget {
  final Map<String, dynamic>? vendaEdicao;
  const VendaScreen({Key? key, this.vendaEdicao}) : super(key: key);
  @override
  State<VendaScreen> createState() => _VendaScreenState();
}

class _VendaScreenState extends State<VendaScreen> {
  Map<String, dynamic>? clienteSelecionado;
  String nomeCliente = "Toque para selecionar o cliente";
  String numeroNota = "Carregando...";
  bool isSaidaAvancada = false;
  double totalVenda = 0.0;
  DateTime dataVenda = DateTime.now(); // NOVO: Estado da Data

  List<Map<String, dynamic>> produtosAtivos = [];
  List<Map<String, dynamic>> clientesAtivos = [];
  List<Map<String, dynamic>> carrinho = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosOffline();
  }

  Future<void> _carregarDadosOffline() async {
    final db = await DBHelper().database;
    final prods = await db.query('produtos');
    final clis = await db.query('clientes');
    setState(() {
      produtosAtivos = prods;
      clientesAtivos = clis;
    });

    if (widget.vendaEdicao != null) {
      numeroNota = widget.vendaEdicao!['numero_nota'];
      isSaidaAvancada = widget.vendaEdicao!['eh_saida_avancada'] == 1;

      // NOVO: Carrega a data salva no banco caso esteja em edição
      if (widget.vendaEdicao!['data_venda'] != null) {
        dataVenda = DateTime.parse(widget.vendaEdicao!['data_venda']);
      }

      final cli = clis.firstWhere(
        (c) => c['id'] == widget.vendaEdicao!['cliente_id'],
      );
      setState(() {
        clienteSelecionado = cli;
        nomeCliente = cli['nome'] as String;
      });

      final itensDb = await db.query(
        'venda_itens',
        where: 'venda_id = ?',
        whereArgs: [widget.vendaEdicao!['id']],
      );
      List<Map<String, dynamic>> carrinhoCarregado = [];
      for (var item in itensDb) {
        final p = prods.firstWhere((prod) => prod['id'] == item['produto_id']);
        carrinhoCarregado.add({
          "produto_id": item['produto_id'],
          "nome": p['nome'],
          "preco_unitario": item['preco_unitario'],
          "quantidade_kg": item['quantidade_kg'],
          "quantidade_pecas": item['quantidade_pecas'] ?? "",
          "observacao": item['observacao'] ?? "",
          "subtotal": item['subtotal'],
        });
      }
      setState(() {
        carrinho = carrinhoCarregado;
        _calcularTotal();
      });
    } else {
      final maxQuery = await db.rawQuery(
        'SELECT MAX(id) as max_id FROM vendas',
      );
      int nextId = ((maxQuery.first['max_id'] as int?) ?? 0) + 1;
      setState(() => numeroNota = "APP-${nextId.toString().padLeft(3, '0')}");
    }
  }

  void _calcularTotal() {
    double total = 0;
    for (var item in carrinho) total += item['subtotal'];
    setState(() => totalVenda = total);
  }

  void _editarNumeroNota() {
    TextEditingController notaCtrl = TextEditingController(text: numeroNota);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar Número da Nota"),
        content: TextField(
          controller: notaCtrl,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () {
              if (notaCtrl.text.trim().isNotEmpty) {
                setState(() => numeroNota = notaCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text("SALVAR"),
          ),
        ],
      ),
    );
  }

  // NOVO: Método para exibir o calendário e alterar a data
  Future<void> _escolherData() async {
    final DateTime? escolhida = await showDatePicker(
      context: context,
      initialDate: dataVenda,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: "DATA DA VENDA",
      cancelText: "CANCELAR",
      confirmText: "CONFIRMAR",
    );
    if (escolhida != null && escolhida != dataVenda) {
      setState(() {
        dataVenda = escolhida;
      });
    }
  }

  void _abrirSelecaoCliente() {
    if (widget.vendaEdicao != null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Selecione o Cliente",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: clientesAtivos.length,
                itemBuilder: (c, i) {
                  final cli = clientesAtivos[i];
                  return Card(
                    child: ListTile(
                      title: Text(
                        cli['nome'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      onTap: () {
                        setState(() {
                          clienteSelecionado = cli;
                          nomeCliente = cli['nome'];
                          if (cli['id'] == 1) isSaidaAvancada = false;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirSelecaoProduto() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Qual produto?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: produtosAtivos.length,
                itemBuilder: (c, i) {
                  final prod = produtosAtivos[i];
                  return Card(
                    child: ListTile(
                      title: Text(
                        prod['nome'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "R\$ ${prod['preco'].toStringAsFixed(2).replaceAll('.', ',')} / ${prod['tipo_unidade']}",
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _configurarProduto(prod);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _configurarProduto(
    Map<String, dynamic> produto, {
    int? indexEdicao,
    Map<String, dynamic>? itemExistente,
  }) {
    TextEditingController pesoCtrl = TextEditingController(
      text: itemExistente != null
          ? itemExistente['quantidade_kg'].toString()
          : "",
    );
    TextEditingController precoCtrl = TextEditingController(
      text: itemExistente != null
          ? itemExistente['preco_unitario'].toStringAsFixed(2)
          : produto['preco'].toStringAsFixed(2),
    );
    TextEditingController obsCtrl = TextEditingController(
      text: itemExistente != null ? itemExistente['observacao'] : "",
    );

    // --- NOVA LÓGICA DE VALIDAÇÃO: REIS VS OUTROS ---
    bool isReis =
        produto['id'] == 1 ||
        produto['nome'].toString().toLowerCase().contains('reis');
    double stepVal = isReis ? 0.5 : 1.0; // Reis salta de 0.5, outros de 1 em 1
    double minVal = isReis
        ? 0.0
        : 1.0; // Reis pode ter 0 peças, outros obrigam a 1

    double pecasDouble = minVal; // Inicializa com o mínimo permitido

    // Carrega valor existente, se houver (em caso de edição)
    if (itemExistente != null && itemExistente['quantidade_pecas'] != "") {
      String pStr = itemExistente['quantidade_pecas'].toString().replaceAll(
        ',',
        '.',
      );
      pecasDouble = double.tryParse(pStr) ?? minVal;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                indexEdicao != null
                    ? "Editar: ${produto['nome']}"
                    : "Configurar: ${produto['nome']}",
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: pesoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Peso Total (Kg)*",
                        prefixIcon: Icon(Icons.scale),
                      ),
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 24),

                    // --- STEPPER TÁTIL INTELIGENTE ---
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isReis
                            ? "Quantidade de Peças (Múltiplos de 1/2)"
                            : "Quantidade de Peças (Obrigatório Mínimo 1)",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (pecasDouble - stepVal >= minVal) {
                                setDialogState(() => pecasDouble -= stepVal);
                              } else if (pecasDouble > minVal) {
                                setDialogState(() => pecasDouble = minVal);
                              }
                            },
                            icon: Icon(
                              Icons.remove_circle_outline,
                              size: 40,
                              // Fica cinza se já atingiu o mínimo
                              color: pecasDouble > minVal
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                          ),
                          Text(
                            pecasDouble == 0
                                ? "Nenhuma"
                                : (pecasDouble % 1 == 0
                                      ? pecasDouble.toInt().toString()
                                      : pecasDouble.toString()),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setDialogState(() => pecasDouble += stepVal);
                            },
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 40,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // -----------------------------------
                    const SizedBox(height: 24),
                    TextField(
                      controller: precoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Preço Unitário (R\$)*",
                        prefixText: "R\$ ",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: obsCtrl,
                      decoration: const InputDecoration(
                        labelText: "Observação (Lote/Letra)",
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "CANCELAR",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    double peso =
                        double.tryParse(pesoCtrl.text.replaceAll(',', '.')) ??
                        0;
                    double preco =
                        double.tryParse(precoCtrl.text.replaceAll(',', '.')) ??
                        0;

                    // VALIDAÇÕES DE REGRA DE NEGÓCIO DE PREENCHIMENTO
                    if (peso <= 0 || preco <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "O Peso e o Preço são obrigatórios e maiores que zero!",
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return; // Impede que o modal feche
                    }

                    if (!isReis && pecasDouble < 1.0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Para este produto é obrigatório informar pelo menos 1 peça!",
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return; // Impede que o modal feche
                    }

                    setState(() {
                      final novoItem = {
                        "produto_id": produto['id'],
                        "nome": produto['nome'],
                        "preco_unitario": preco,
                        "quantidade_kg": peso,
                        "quantidade_pecas": pecasDouble > 0
                            ? pecasDouble.toString()
                            : "",
                        "observacao": obsCtrl.text.trim(),
                        "subtotal": peso * preco,
                      };
                      if (indexEdicao != null) {
                        carrinho[indexEdicao] = novoItem;
                      } else {
                        carrinho.add(novoItem);
                      }
                      _calcularTotal();
                    });
                    Navigator.pop(
                      ctx,
                    ); // Só fecha o modal se tudo estiver correto
                  },
                  child: Text(indexEdicao != null ? "ATUALIZAR" : "ADICIONAR"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removerItem(int index) {
    setState(() {
      carrinho.removeAt(index);
      _calcularTotal();
    });
  }

  Future<void> _salvarVendaLocal() async {
    if (clienteSelecionado == null || carrinho.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cliente e produtos obrigatórios!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      final db = await DBHelper().database;
      int vendaId;

      if (widget.vendaEdicao != null) {
        vendaId = widget.vendaEdicao!['id'];
        // NOVO: Atualiza a data_venda no update também
        await db.update(
          'vendas',
          {
            'numero_nota': numeroNota,
            'data_venda': dataVenda.toIso8601String(),
            'valor_total': totalVenda,
            'eh_saida_avancada': isSaidaAvancada ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [vendaId],
        );
        await db.delete(
          'venda_itens',
          where: 'venda_id = ?',
          whereArgs: [vendaId],
        );
      } else {
        // NOVO: Salva a data_venda com a escolhida pelo usuário
        vendaId = await db.insert('vendas', {
          'cliente_id': clienteSelecionado!['id'],
          'numero_nota': numeroNota,
          'data_venda': dataVenda.toIso8601String(),
          'valor_total': totalVenda,
          'eh_saida_avancada': isSaidaAvancada ? 1 : 0,
          'status_sincronizacao': 'pendente',
        });
      }
      for (var item in carrinho) {
        await db.insert('venda_itens', {
          'venda_id': vendaId,
          'produto_id': item['produto_id'],
          'quantidade_kg': item['quantidade_kg'],
          'quantidade_pecas': item['quantidade_pecas'],
          'preco_unitario': item['preco_unitario'],
          'observacao': item['observacao'],
          'subtotal': item['subtotal'],
        });
      }
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao salvar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.vendaEdicao != null ? 'Editando Nota' : 'Nova Venda',
        ),
        actions: [
          TextButton.icon(
            onPressed: _editarNumeroNota,
            icon: const Icon(Icons.edit, color: Colors.amber, size: 18),
            label: Text(
              "Nota: $numeroNota",
              style: const TextStyle(fontSize: 16, color: Colors.amber),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  InkWell(
                    onTap: _abrirSelecaoCliente,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: clienteSelecionado != null
                            ? primaryColor.withOpacity(0.1)
                            : Theme.of(context).dividerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 36,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              nomeCliente,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // NOVO: Botão/Lista para escolher a data da venda
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.calendar_month, color: primaryColor),
                    title: Text(
                      "Data da Venda: ${dataVenda.day.toString().padLeft(2, '0')}/${dataVenda.month.toString().padLeft(2, '0')}/${dataVenda.year}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: const Icon(Icons.edit, color: Colors.grey),
                    onTap: _escolherData,
                  ),

                  if (clienteSelecionado == null ||
                      clienteSelecionado!['id'] != 1) ...[
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Saída de Estoque Avançado (SEA)",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: isSaidaAvancada,
                      activeColor: Colors.green,
                      onChanged: (bool value) =>
                          setState(() => isSaidaAvancada = value),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: carrinho.isEmpty
                ? const Center(
                    child: Text(
                      "Nenhum produto adicionado",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: carrinho.length,
                    itemBuilder: (context, index) {
                      final item = carrinho[index];

                      // Transforma "1.5" em "1 e 1/2 PC" para a visualização no carrinho
                      String pecasVisuais = "";
                      if (item['quantidade_pecas'] != "") {
                        double p =
                            double.tryParse(item['quantidade_pecas']) ?? 0;
                        if (p > 0) {
                          if (p == 0.5)
                            pecasVisuais = " (1/2 PC)";
                          else if (p % 1 == 0.5)
                            pecasVisuais = " (${p.truncate()} e 1/2 PC)";
                          else
                            pecasVisuais = " (${p.toInt()} PC)";
                        }
                      }

                      return Card(
                        child: InkWell(
                          onTap: () {
                            final prodFake = {
                              "id": item['produto_id'],
                              "nome": item['nome'],
                              "preco": item['preco_unitario'],
                            };
                            _configurarProduto(
                              prodFake,
                              indexEdicao: index,
                              itemExistente: item,
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['nome'],
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${item['quantidade_kg'].toString().replaceAll('.', ',')} Kg$pecasVisuais  x  R\$ ${item['preco_unitario'].toStringAsFixed(2).replaceAll('.', ',')} \nLote/Obs: ${item['observacao'].isEmpty ? '-' : item['observacao']}",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "R\$ ${item['subtotal'].toStringAsFixed(2).replaceAll('.', ',')}",
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 28,
                                  ),
                                  onPressed: () => _removerItem(index),
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
        onPressed: _abrirSelecaoProduto,
        icon: const Icon(Icons.add),
        label: const Text("PRODUTO"),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Total da Venda",
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    "R\$ ${totalVenda.toStringAsFixed(2).replaceAll('.', ',')}",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 60,
              width: 180,
              child: ElevatedButton(
                onPressed: _salvarVendaLocal,
                child: const Text("SALVAR"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
