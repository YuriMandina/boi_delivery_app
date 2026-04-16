import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../database/db_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _gerarRelatorio();
  }

  // --- NOVO: Função que ensina o Dart a ler frações em texto ---
  double _parsePecas(String texto) {
    if (texto.isEmpty) return 0.0;
    texto = texto.toLowerCase().replaceAll(',', '.').trim();

    // 1. Tenta conversão direta primeiro (ex: "2" ou "2.5")
    double? valorDireto = double.tryParse(texto);
    if (valorDireto != null) return valorDireto;

    // 2. Processa frações com "e" (ex: "1 e 1/2")
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

    // 3. Processa frações simples (ex: "1/2")
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

  // Função universal para converter decimais de volta em frações visuais (ex: 0.5 -> 1/2)
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

    // CORREÇÃO: Transformados em double para não esmagarem as frações (ex: 0.5)
    double totalPecasReisInteiras = 0.0;
    double totalPecasDianteiro = 0.0;
    double totalPecasTraseiroOuSerrote = 0.0;

    double totalKgCarcacas = 0.0;
    double totalKgMiudos = 0.0;
    double totalGeralKg = 0.0;

    StringBuffer sbDetalhado = StringBuffer();
    String separadorForte = "=" * 40;
    String separadorFraco = "-" * 40;

    // Constrói o Relatório Detalhado (que será anexado no final)
    for (var venda in vendas) {
      String nomeCliente = clientesMap[venda['cliente_id']] ?? 'Desconhecido';
      sbDetalhado.writeln("CLIENTE: $nomeCliente");
      sbDetalhado.writeln("NOTA...: ${venda['numero_nota']}");

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

        // NOVO: Lê a string e extrai a fração com o nosso novo Parser
        String pecasStr = (item['quantidade_pecas'] ?? "").toString();
        double pecasDouble = _parsePecas(pecasStr);

        // Variáveis financeiras e de apresentação
        double precoUnit = (item['preco_unitario'] as num).toDouble();
        double subtotal = (item['subtotal'] as num).toDouble();
        String obs = item['observacao']?.toString().trim() ?? "";
        String obsFormatada = obs.isNotEmpty ? " [Lote: $obs]" : "";

        // Aplica a fração nas peças do detalhado e coloca antes do peso
        String pecasFormatadas = _formatarFracao(pecasDouble);
        String infoPecas = pecasFormatadas.isNotEmpty
            ? "($pecasFormatadas PC) "
            : "";

        sbDetalhado.writeln("- $nomeProduto$obsFormatada");
        sbDetalhado.writeln(
          _formatarLinhaImpressao(
            "  $infoPecas${qtdKg.toStringAsFixed(2)} KG x R\$${precoUnit.toStringAsFixed(2)}",
            "R\$ ${subtotal.toStringAsFixed(2)}",
          ),
        );

        totalGeralKg += qtdKg;

        if (nomeLower.contains('reis') ||
            nomeLower.contains('rês') ||
            nomeLower.contains('res')) {
          mapPesosReis[nomeProduto] =
              (mapPesosReis[nomeProduto] ?? 0.0) + qtdKg;
          totalPecasReisInteiras +=
              pecasDouble; // Agora soma o 0.5 perfeitamente!
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
      sbDetalhado.writeln(separadorFraco);
      sbDetalhado.writeln(
        _formatarLinhaImpressao(
          "TOTAL DA NOTA:",
          "R\$ ${totalDaNota.toStringAsFixed(2)}",
        ),
      );
      sbDetalhado.writeln(""); // Respiro para o próximo cliente
    }

    // CORREÇÃO: Variáveis matemáticas que calculam "pares completos" para formar carcaças
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
    sb.writeln(separadorForte);
    sb.writeln("              BOI DELIVERY");
    sb.writeln("           FECHAMENTO DE ROTA");
    sb.writeln(separadorForte);
    sb.writeln(
      "DATA: ${DateFormat('dd/MM/yyyy').format(widget.dataRelatorio)}",
    );
    sb.writeln("EMISSAO: ${DateFormat('HH:mm').format(DateTime.now())}");
    sb.writeln(separadorFraco);
    sb.writeln("");

    // SECÇÃO 1
    sb.writeln("1. CONVERSAO DE REIS (CASSE)");
    sb.writeln(separadorFraco);
    if (totalReisFinal > 0) {
      sb.writeln(
        _formatarLinhaImpressao("TOTAL VENDIDO:", "$textoReisFracao REIS"),
      );
    } else {
      sb.writeln(_formatarLinhaImpressao("TOTAL VENDIDO:", "NENHUMA RES"));
    }

    if (sobrasDianteiro > 0 || sobrasTraseiro > 0) {
      sb.writeln("");
      sb.writeln("SOBRAS (PECAS SEM PAR):");
      if (sobrasDianteiro > 0) {
        sb.writeln("- ${_formatarFracao(sobrasDianteiro)} DIANTEIRO(S)");
      }
      if (sobrasTraseiro > 0) {
        sb.writeln(
          "- ${_formatarFracao(sobrasTraseiro)} TRASEIRO(S)/SERROTE(S)",
        );
      }
    }
    sb.writeln(separadorFraco);
    sb.writeln("");

    // SECÇÃO 2
    sb.writeln("2. RESUMO DE KG: CARCACAS BOVINAS");
    sb.writeln(separadorFraco);
    if (mapPesosReis.isEmpty) {
      sb.writeln("Nenhuma carcaca movimentada.");
    } else {
      mapPesosReis.forEach((nome, kg) {
        sb.writeln(
          _formatarLinhaImpressao(nome, "${kg.toStringAsFixed(2)} KG"),
        );
      });
      sb.writeln(separadorFraco);
      sb.writeln(
        _formatarLinhaImpressao(
          "SUBTOTAL CARCACAS:",
          "${totalKgCarcacas.toStringAsFixed(2)} KG",
        ),
      );
    }
    sb.writeln(separadorFraco);
    sb.writeln("");

    // SECÇÃO 3
    sb.writeln("3. RESUMO DE KG: CORTES AVULSOS / MIUDOS");
    sb.writeln(separadorFraco);
    if (mapPesosMiudos.isEmpty) {
      sb.writeln("Nenhum corte avulso movimentado.");
    } else {
      mapPesosMiudos.forEach((nome, kg) {
        sb.writeln(
          _formatarLinhaImpressao(nome, "${kg.toStringAsFixed(2)} KG"),
        );
      });
      sb.writeln(separadorFraco);
      sb.writeln(
        _formatarLinhaImpressao(
          "SUBTOTAL MIUDOS:",
          "${totalKgMiudos.toStringAsFixed(2)} KG",
        ),
      );
    }

    // FECHAMENTO DO RESUMO (Total Geral)
    sb.writeln(separadorForte);
    sb.writeln("TOTAL GERAL DE PESO:");
    sb.writeln(
      "                            ${totalGeralKg.toStringAsFixed(2)} KG",
    );
    sb.writeln(separadorForte);
    sb.writeln("");
    sb.writeln("");

    // ================= RELATÓRIO DETALHADO =================
    sb.writeln(separadorForte);
    sb.writeln("       RELATORIO DETALHADO POR CLIENTE");
    sb.writeln(separadorForte);
    sb.writeln("");

    sb.write(sbDetalhado.toString());

    sb.writeln(separadorForte);
    sb.writeln("");
    sb.writeln("");
    sb.writeln("    ________________________________");
    sb.writeln("                ASSINATURA");
    sb.writeln("");

    setState(() {
      reciboTexto = sb.toString();
      isLoading = false;
    });
  }

  String _formatarLinhaImpressao(
    String item,
    String valor, {
    int tamanhoMax = 40,
  }) {
    String itemName = item.length > (tamanhoMax - valor.length - 1)
        ? item.substring(0, (tamanhoMax - valor.length - 1))
        : item;

    int espacos = tamanhoMax - itemName.length - valor.length;
    if (espacos < 1) espacos = 1;

    return "$itemName${" " * espacos}$valor";
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
                  constraints: const BoxConstraints(maxWidth: 400),
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
                  child: Text(
                    reciboTexto,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Aguardando impressora fisica para pareamento."),
            ),
          );
        },
        icon: const Icon(Icons.print),
        label: const Text("TESTAR IMPRESSORA"),
        backgroundColor: Colors.blueGrey[900],
      ),
    );
  }
}
