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
      // MODO EDIÇÃO
      numeroNota = widget.vendaEdicao!['numero_nota'];
      isSaidaAvancada = widget.vendaEdicao!['eh_saida_avancada'] == 1;

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
      // MODO NOVA VENDA: Gera o número sequencial (APP-001, APP-002...)
      final maxQuery = await db.rawQuery(
        'SELECT MAX(id) as max_id FROM vendas',
      );
      int nextId = ((maxQuery.first['max_id'] as int?) ?? 0) + 1;
      setState(() {
        numeroNota = "APP-${nextId.toString().padLeft(3, '0')}";
      });
    }
  }

  void _calcularTotal() {
    double total = 0;
    for (var item in carrinho) {
      total += item['subtotal'];
    }
    setState(() => totalVenda = total);
  }

  // --- NOVO: PERMITE O MOTORISTA DIGITAR O NÚMERO DO TALÃO DE PAPEL ---
  void _editarNumeroNota() {
    TextEditingController notaCtrl = TextEditingController(text: numeroNota);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar Número da Nota"),
        content: TextField(
          controller: notaCtrl,
          decoration: const InputDecoration(
            labelText: "Ex: TALÃO-550",
            border: OutlineInputBorder(),
          ),
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

  void _abrirSelecaoCliente() {
    if (widget.vendaEdicao != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Não é possível trocar o cliente de uma nota já gerada.",
          ),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        height: 500,
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
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        cli['nome'],
                        style: const TextStyle(
                          fontSize: 20,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        height: 500,
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
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        prod['nome'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "R\$ ${prod['preco'].toStringAsFixed(2).replaceAll('.', ',')} / ${prod['tipo_unidade']}",
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.blue,
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

  // --- ATUALIZADO: AGORA SUPORTA EDIÇÃO DE UM ITEM QUE JÁ ESTÁ NO CARRINHO ---
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
    TextEditingController pecasCtrl = TextEditingController(
      text: itemExistente != null
          ? itemExistente['quantidade_pecas'].toString()
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                  labelText: "Peso (Kg)*",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                ),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pecasCtrl,
                decoration: const InputDecoration(
                  labelText: "Peças/Fração (Opcional)",
                  border: OutlineInputBorder(),
                  hintText: "Ex: 1/2",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: "Preço Unitário (R\$)*",
                  border: OutlineInputBorder(),
                  prefixText: "R\$ ",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: obsCtrl,
                decoration: const InputDecoration(
                  labelText: "Observação (Opcional)",
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              double peso =
                  double.tryParse(pesoCtrl.text.replaceAll(',', '.')) ?? 0;
              double preco =
                  double.tryParse(precoCtrl.text.replaceAll(',', '.')) ?? 0;
              if (peso > 0 && preco > 0) {
                setState(() {
                  final novoItem = {
                    "produto_id": produto['id'],
                    "nome": produto['nome'],
                    "preco_unitario": preco,
                    "quantidade_kg": peso,
                    "quantidade_pecas": pecasCtrl.text,
                    "observacao": obsCtrl.text,
                    "subtotal": peso * preco,
                  };

                  if (indexEdicao != null) {
                    carrinho[indexEdicao] = novoItem; // Edita o existente
                  } else {
                    carrinho.add(novoItem); // Adiciona novo
                  }

                  _calcularTotal();
                });
                Navigator.pop(ctx);
              }
            },
            child: Text(
              indexEdicao != null ? "ATUALIZAR" : "ADICIONAR",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
          content: Text("Cliente e produtos são obrigatórios!"),
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
        await db.update(
          'vendas',
          {
            'numero_nota': numeroNota, // Salva se ele editou a nota
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
        vendaId = await db.insert('vendas', {
          'cliente_id': clienteSelecionado!['id'],
          'numero_nota': numeroNota,
          'data_venda': DateTime.now().toIso8601String(),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Venda salva com sucesso!"),
          backgroundColor: Colors.green,
        ),
      );
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.vendaEdicao != null ? 'Editando Nota' : 'Nova Venda',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          // Botão que permite editar a numeração da nota manualmente
          TextButton.icon(
            onPressed: _editarNumeroNota,
            icon: const Icon(Icons.edit, color: Colors.amber, size: 18),
            label: Text(
              "Nota: $numeroNota",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                InkWell(
                  onTap: _abrirSelecaoCliente,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: clienteSelecionado != null
                          ? Colors.blue[50]
                          : Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_search,
                          size: 40,
                          color: clienteSelecionado != null
                              ? Colors.blue[800]
                              : Colors.blue,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            nomeCliente,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: clienteSelecionado != null
                                  ? Colors.blue[900]
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (clienteSelecionado == null ||
                    clienteSelecionado!['id'] != 1) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text(
                      "Saída de Estoque Avançado (SEA)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
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
          Expanded(
            child: carrinho.isEmpty
                ? const Center(child: Text("Nenhum produto adicionado"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: carrinho.length,
                    itemBuilder: (context, index) {
                      final item = carrinho[index];
                      // Transformamos o Card em um botão clicável para Edição
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            // Abre a janela de configuração, passando os dados atuais para edição
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
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              item['nome'],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "${item['quantidade_kg'].toString().replaceAll('.', ',')} Kg  x  R\$ ${item['preco_unitario'].toStringAsFixed(2).replaceAll('.', ',')}\nObs: ${item['observacao'].isEmpty ? '-' : item['observacao']}\n(Toque para editar o peso)",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 32,
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
        backgroundColor: Colors.green[600],
        icon: const Icon(Icons.add, size: 32, color: Colors.white),
        label: const Text("ADICIONAR PRODUTO"),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
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
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
              width: 200,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _salvarVendaLocal,
                child: const Text(
                  "SALVAR",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
