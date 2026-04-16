import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../database/db_helper.dart';
import '../utils/formatters.dart';

class RelatorioScreen extends StatefulWidget {
  final DateTime dataRelatorio;

  const RelatorioScreen({Key? key, required this.dataRelatorio})
    : super(key: key);

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  bool isLoading = true;
  String reciboTexto = "";

  // Arquitetura de Layout: 48 Colunas
  final int _maxColunas = 48;

  @override
  void initState() {
    super.initState();
    _gerarRelatorio();
  }

  double _parsePecas(String texto) {
    if (texto.isEmpty) return 0.0;
    texto = texto.toLowerCase().replaceAll(',', '.').trim();

    double? valorDireto = double.tryParse(texto);
    if (valorDireto != null) return valorDireto;

    if (texto.contains(" e ")) {
      var partes = texto.split(" e ");
      if (partes.length == 2) {
        double inteiro = double.tryParse(partes[0]) ?? 0.0;
        var fracao = partes[1].split("/");
        if (fracao.length == 2) {
          double num = double.tryParse(fracao[0]) ?? 0.0;
          double den = double.tryParse(fracao[1]) ?? 1.0;
          if (den != 0) return inteiro + (num / den);
        }
      }
    }

    if (texto.contains("/")) {
      var fracao = texto.split("/");
      if (fracao.length == 2) {
        double num = double.tryParse(fracao[0]) ?? 0.0;
        double den = double.tryParse(fracao[1]) ?? 1.0;
        if (den != 0) return num / den;
      }
    }

    return 0.0;
  }

  String _formatarFracao(double valor) {
    if (valor == 0) return "";
    int inteiro = valor.truncate();
    double decimal = valor - inteiro;

    if (decimal == 0) return inteiro.toString();

    String fracaoStr = "";
    if ((decimal - 0.5).abs() < 0.001) {
      fracaoStr = "1/2";
    } else if ((decimal - 0.25).abs() < 0.001) {
      fracaoStr = "1/4";
    } else if ((decimal - 0.75).abs() < 0.001) {
      fracaoStr = "3/4";
    } else {
      return valor.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    }

    if (inteiro == 0) return fracaoStr;
    return "$inteiro e $fracaoStr";
  }

  Future<void> _gerarRelatorio() async {
    final db = await DBHelper().database;
    String dataBusca = DateFormat('yyyy-MM-dd').format(widget.dataRelatorio);

    final clis = await db.query('clientes');
    Map<int, String> clientesMap = {};
    for (var c in clis) {
      clientesMap[c['id'] as int] = c['nome'] as String;
    }

    final vendas = await db.query(
      'vendas',
      where: 'substr(data_venda, 1, 10) = ?',
      whereArgs: [dataBusca],
    );

    if (vendas.isEmpty) {
      setState(() {
        reciboTexto = "Nenhuma movimentacao\nregistrada nesta data.";
        isLoading = false;
      });
      return;
    }

    Map<String, double> mapPesosReis = {};
    Map<String, double> mapPesosMiudos = {};

    double totalPecasReisInteiras = 0.0;
    double totalPecasDianteiro = 0.0;
    double totalPecasTraseiroOuSerrote = 0.0;

    double totalKgCarcacas = 0.0;
    double totalKgMiudos = 0.0;
    double totalGeralKg = 0.0;

    StringBuffer sbDetalhado = StringBuffer();
    String sepForte = "=" * _maxColunas;
    String sepFraco = "-" * _maxColunas;

    // ================= CONSTRUÇÃO DO RELATÓRIO DETALHADO =================
    bool isPrimeiraNota = true; // Controlador do separador

    for (var venda in vendas) {
      // AQUI: Injeta um separador visual forte antes do próximo cliente (exceto no primeiro)
      if (!isPrimeiraNota) {
        sbDetalhado.writeln(sepForte);
        sbDetalhado.writeln("");
      }
      isPrimeiraNota = false;

      String nomeCliente = clientesMap[venda['cliente_id']] ?? 'Desconhecido';
      String numNotaFormatado = venda['numero_nota'].toString().replaceAll(
        'APP-',
        '',
      );

      sbDetalhado.writeln("CLIENTE: $nomeCliente");
      sbDetalhado.writeln("NOTA...: $numNotaFormatado");
      sbDetalhado.writeln(sepFraco);

      String headerInfo =
          "${'QTD(KG)'.padRight(14)}${'PECAS'.padRight(12)}${'V.UN'.padLeft(9)}${'TOTAL'.padLeft(13)}";
      sbDetalhado.writeln(headerInfo);
      sbDetalhado.writeln(sepFraco);

      final itens = await db.query(
        'venda_itens',
        where: 'venda_id = ?',
        whereArgs: [venda['id']],
      );

      for (var item in itens) {
        final produtos = await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [item['produto_id']],
        );
        String nomeProduto = produtos.isNotEmpty
            ? produtos.first['nome'] as String
            : "Desconhecido";
        String nomeLower = nomeProduto.toLowerCase();

        double qtdKg = (item['quantidade_kg'] as num).toDouble();
        String pecasStr = (item['quantidade_pecas'] ?? "").toString();
        double pecasDouble = _parsePecas(pecasStr);

        double precoUnit = (item['preco_unitario'] as num).toDouble();
        double subtotal = (item['subtotal'] as num).toDouble();
        String obs = item['observacao']?.toString().trim() ?? "";
        String obsFormatada = obs.isNotEmpty ? " [Lote: $obs]" : "";

        sbDetalhado.writeln("- $nomeProduto$obsFormatada");

        String sKg = AppFormatters.peso(qtdKg);
        String sPc = _formatarFracao(pecasDouble);
        String sPr = AppFormatters.dinheiro(precoUnit);
        String sSub = AppFormatters.dinheiro(subtotal);

        String linhaValores =
            "${sKg.padRight(14)}${sPc.padRight(12)}${sPr.padLeft(9)}${sSub.padLeft(13)}";
        sbDetalhado.writeln(linhaValores);

        sbDetalhado.writeln("");

        totalGeralKg += qtdKg;
        if (nomeLower.contains('reis') ||
            nomeLower.contains('rês') ||
            nomeLower.contains('res')) {
          mapPesosReis[nomeProduto] =
              (mapPesosReis[nomeProduto] ?? 0.0) + qtdKg;
          totalPecasReisInteiras += pecasDouble;
          totalKgCarcacas += qtdKg;
        } else if (nomeLower.contains('dianteiro') ||
            nomeLower.contains('traseiro') ||
            nomeLower.contains('serrote')) {
          mapPesosReis[nomeProduto] =
              (mapPesosReis[nomeProduto] ?? 0.0) + qtdKg;
          totalKgCarcacas += qtdKg;
          if (nomeLower.contains('dianteiro')) {
            totalPecasDianteiro += pecasDouble;
          } else {
            totalPecasTraseiroOuSerrote += pecasDouble;
          }
        } else {
          mapPesosMiudos[nomeProduto] =
              (mapPesosMiudos[nomeProduto] ?? 0.0) + qtdKg;
          totalKgMiudos += qtdKg;
        }
      }

      double totalDaNota = (venda['valor_total'] as num).toDouble();
      sbDetalhado.writeln(sepFraco);
      sbDetalhado.writeln(
        _alinharDuas(
          "TOTAL DA NOTA:",
          "R\$ ${AppFormatters.dinheiro(totalDaNota)}",
          _maxColunas,
        ),
      );
      sbDetalhado.writeln("");
    }

    // Cálculos de Resumo de Peças
    double paresCompletos = min(
      totalPecasDianteiro,
      totalPecasTraseiroOuSerrote,
    );
    double reisConvertidosDasPecas = paresCompletos / 2.0;

    double totalReisFinal = totalPecasReisInteiras + reisConvertidosDasPecas;
    String textoReisFracao = _formatarFracao(totalReisFinal);

    double sobrasDianteiro = totalPecasDianteiro - paresCompletos;
    double sobrasTraseiro = totalPecasTraseiroOuSerrote - paresCompletos;

    StringBuffer sb = StringBuffer();

    // ================= RESUMO GERAL DA ROTA =================
    sb.writeln(sepForte);
    sb.writeln(_centralizar("BOI DELIVERY", _maxColunas));
    sb.writeln(_centralizar("FECHAMENTO DE ROTA", _maxColunas));
    sb.writeln(sepForte);
    sb.writeln(
      "DATA...: ${DateFormat('dd/MM/yyyy').format(widget.dataRelatorio)}",
    );
    sb.writeln("EMISSAO: ${DateFormat('HH:mm').format(DateTime.now())}");
    sb.writeln(sepFraco);
    sb.writeln("");

    // SECÇÃO 1
    sb.writeln("1. CONVERSAO DE REIS (CASSE)");
    sb.writeln(sepFraco);
    if (totalReisFinal > 0) {
      sb.writeln(
        _alinharDuas("TOTAL VENDIDO:", "$textoReisFracao REIS", _maxColunas),
      );
    } else {
      sb.writeln(_alinharDuas("TOTAL VENDIDO:", "NENHUMA RES", _maxColunas));
    }

    if (sobrasDianteiro > 0 || sobrasTraseiro > 0) {
      sb.writeln("");
      sb.writeln("SOBRAS (PECAS SEM PAR):");
      if (sobrasDianteiro > 0)
        sb.writeln("- ${_formatarFracao(sobrasDianteiro)} DIANTEIRO(S)");
      if (sobrasTraseiro > 0)
        sb.writeln(
          "- ${_formatarFracao(sobrasTraseiro)} TRASEIRO(S)/SERROTE(S)",
        );
    }
    sb.writeln(sepFraco);
    sb.writeln("");

    // SECÇÃO 2
    sb.writeln("2. RESUMO DE KG: CARCACAS BOVINAS");
    sb.writeln(sepFraco);
    if (mapPesosReis.isEmpty) {
      sb.writeln("Nenhuma carcaca movimentada.");
    } else {
      mapPesosReis.forEach((nome, kg) {
        sb.writeln(
          _alinharDuas(nome, "${AppFormatters.peso(kg)} KG", _maxColunas),
        );
      });
      sb.writeln(sepFraco);
      sb.writeln(
        _alinharDuas(
          "SUBTOTAL CARCACAS:",
          "${AppFormatters.peso(totalKgCarcacas)} KG",
          _maxColunas,
        ),
      );
    }
    sb.writeln(sepFraco);
    sb.writeln("");

    // SECÇÃO 3
    sb.writeln("3. RESUMO DE KG: CORTES AVULSOS / MIUDOS");
    sb.writeln(sepFraco);
    if (mapPesosMiudos.isEmpty) {
      sb.writeln("Nenhum corte avulso movimentado.");
    } else {
      mapPesosMiudos.forEach((nome, kg) {
        sb.writeln(
          _alinharDuas(nome, "${AppFormatters.peso(kg)} KG", _maxColunas),
        );
      });
      sb.writeln(sepFraco);
      sb.writeln(
        _alinharDuas(
          "SUBTOTAL MIUDOS:",
          "${AppFormatters.peso(totalKgMiudos)} KG",
          _maxColunas,
        ),
      );
    }

    // FECHAMENTO DO RESUMO (Total Geral)
    sb.writeln(sepForte);
    sb.writeln(
      _alinharDuas(
        "TOTAL GERAL DE PESO:",
        "${AppFormatters.peso(totalGeralKg)} KG",
        _maxColunas,
      ),
    );
    sb.writeln(sepForte);
    sb.writeln("\n\n");

    // ================= ANEXANDO RELATÓRIO DETALHADO =================
    sb.writeln(sepForte);
    sb.writeln(_centralizar("RELATORIO DETALHADO POR CLIENTE", _maxColunas));
    sb.writeln(sepForte);
    sb.writeln("");

    sb.write(sbDetalhado.toString());

    sb.writeln(sepForte);
    sb.writeln("\n\n${_centralizar("-" * 35, _maxColunas)}");
    sb.writeln(_centralizar("ASSINATURA", _maxColunas));
    sb.writeln("");

    setState(() {
      reciboTexto = sb.toString();
      isLoading = false;
    });
  }

  String _alinharDuas(String esquerda, String direita, int max) {
    int espacos = max - esquerda.length - direita.length;
    if (espacos < 1) espacos = 1;
    return "$esquerda${" " * espacos}$direita";
  }

  String _centralizar(String texto, int max) {
    if (texto.length >= max) return texto;
    int padding = (max - texto.length) ~/ 2;
    return "${" " * padding}$texto";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-Visualizacao de Impressao'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[300],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
        label: const Text("TESTAR IMPRESSORA"),
        backgroundColor: Colors.blueGrey[900],
      ),
    );
  }
}
