import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../utils/formatters.dart';

class ReciboScreen extends StatefulWidget {
  final Map<String, dynamic> venda;

  const ReciboScreen({Key? key, required this.venda}) : super(key: key);

  @override
  State<ReciboScreen> createState() => _ReciboScreenState();
}

class _ReciboScreenState extends State<ReciboScreen> {
  bool isLoading = true;
  String reciboTexto = "";

  // Reduzimos de 48 para 42 colunas (Sweet spot de leitura)
  final int _maxColunas = 42;

  @override
  void initState() {
    super.initState();
    _gerarTalao();
  }

  String _formatarFracao(double valor) {
    if (valor == 0) return "";
    int inteiro = valor.truncate();
    double decimal = valor - inteiro;
    if (decimal == 0) return inteiro.toString();

    String fracaoStr = "";
    if ((decimal - 0.5).abs() < 0.001)
      fracaoStr = "1/2";
    else if ((decimal - 0.25).abs() < 0.001)
      fracaoStr = "1/4";
    else if ((decimal - 0.75).abs() < 0.001)
      fracaoStr = "3/4";
    else
      return valor.toStringAsFixed(2);

    return inteiro == 0 ? fracaoStr : "$inteiro e $fracaoStr";
  }

  Future<void> _gerarTalao() async {
    try {
      final db = await DBHelper().database;
      final int vendaId = widget.venda['id'];

      final clis = await db.query(
        'clientes',
        where: 'id = ?',
        whereArgs: [widget.venda['cliente_id']],
      );
      String nomeCliente = clis.isNotEmpty
          ? clis.first['nome'] as String
          : 'CLIENTE';

      final itens = await db.query(
        'venda_itens',
        where: 'venda_id = ?',
        whereArgs: [vendaId],
      );

      DateTime dtVenda = widget.venda['data_venda'] != null
          ? DateTime.parse(widget.venda['data_venda'])
          : DateTime.now();

      StringBuffer sb = StringBuffer();
      String sepForte = "=" * _maxColunas;
      String sepFraco = "-" * _maxColunas;

      sb.writeln(sepForte);
      sb.writeln(_centralizar("BOI DELIVERY", _maxColunas));
      sb.writeln(_centralizar("RECIBO DE VENDA", _maxColunas));
      sb.writeln(sepForte);
      sb.writeln("NOTA...: ${widget.venda['numero_nota']}");
      sb.writeln("DATA...: ${DateFormat('dd/MM/yyyy').format(dtVenda)}");
      sb.writeln("CLIENTE: $nomeCliente");
      if (widget.venda['eh_saida_avancada'] == 1) {
        sb.writeln("");
        sb.writeln(
          _centralizar("*** SAIDA DE ESTOQUE AVANCADO ***", _maxColunas),
        );
      }

      sb.writeln(sepFraco);
      // ARQUITETURA DE COLUNAS: Total 48 chars
      // QTD (14) Esquerda | PECAS (12) Esquerda | V.UN (9) Direita | TOTAL (13) Direita
      // CABEÇALHO
      String headerInfo =
          "${'QTD(KG)'.padRight(12)}${'PECAS'.padRight(9)}${'V.UN'.padLeft(8)}${'TOTAL'.padLeft(13)}";
      sb.writeln(headerInfo);
      sb.writeln(sepFraco);

      double totalGeral = 0.0;
      for (var item in itens) {
        final prods = await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [item['produto_id']],
        );
        String nomeProd = prods.isNotEmpty
            ? prods.first['nome'] as String
            : 'PRODUTO';

        double kg = (item['quantidade_kg'] as num).toDouble();
        double preco = (item['preco_unitario'] as num).toDouble();
        double sub = (item['subtotal'] as num).toDouble();
        double pDouble =
            double.tryParse(
              item['quantidade_pecas'].toString().replaceAll(',', '.'),
            ) ??
            0.0;

        totalGeral += sub;

        sb.writeln(nomeProd);
        String obs = item['observacao']?.toString().trim() ?? "";
        if (obs.isNotEmpty) sb.writeln("  Lote/Obs: $obs");

        String sKg = AppFormatters.peso(kg);
        String sPc = _formatarFracao(pDouble);
        String sPr = AppFormatters.dinheiro(preco);
        String sSub = AppFormatters.dinheiro(sub);

        // APLICAÇÃO DO ALINHAMENTO MATEMÁTICO (Substitui o existente)
        String linhaValores =
            "${sKg.padRight(12)}${sPc.padRight(9)}${sPr.padLeft(8)}${sSub.padLeft(13)}";
        sb.writeln(linhaValores);
      }

      sb.writeln(sepForte);
      sb.writeln(
        _alinharDuas(
          "TOTAL DA NOTA:",
          "R\$ ${AppFormatters.dinheiro(totalGeral)}",
          _maxColunas,
        ),
      );
      sb.writeln(sepForte);
      sb.writeln("\n\n${_centralizar("-" * 35, _maxColunas)}");
      sb.writeln(_centralizar("ASSINATURA DO CLIENTE", _maxColunas));

      setState(() {
        reciboTexto = sb.toString();
        isLoading = false;
      });
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  String _centralizar(String t, int tam) =>
      t.length >= tam ? t : "${' ' * ((tam - t.length) ~/ 2)}$t";
  String _alinharDuas(String e, String d, int tam) =>
      "$e${' ' * (tam - e.length - d.length)}$d";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nota ${widget.venda['numero_nota']}'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[300],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: FittedBox(
                    fit: BoxFit
                        .scaleDown, // Obriga a encolher se não couber, proibindo a quebra de linha
                    alignment: Alignment.center,
                    child: Text(
                      reciboTexto,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.print),
        label: const Text("IMPRIMIR"),
        backgroundColor: Colors.blueGrey[900],
      ),
    );
  }
}
